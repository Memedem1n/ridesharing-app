import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
const String _envWebBaseUrl = String.fromEnvironment('WEB_API_BASE_URL');

String _resolveBaseUrl() {
  if (_envBaseUrl.trim().isNotEmpty) {
    return _envBaseUrl.trim();
  }
  if (kIsWeb) {
    if (_envWebBaseUrl.trim().isNotEmpty) {
      return _envWebBaseUrl.trim();
    }
    final host = Uri.base.host;
    if (host.isNotEmpty) {
      return 'http://$host:3000/v1';
    }
    return 'http://localhost:3000/v1';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android emulator cannot reach host machine through localhost.
    return 'http://10.0.2.2:3000/v1';
  }
  return 'http://localhost:3000/v1';
}

final String baseUrl = _resolveBaseUrl();

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class AuthInterceptor extends Interceptor {
  final Ref ref;

  AuthInterceptor(this.ref);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'access_token');

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired, try refresh
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry original request
        final opts = err.requestOptions;
        final storage = ref.read(secureStorageProvider);
        final newToken = await storage.read(key: 'access_token');
        opts.headers['Authorization'] = 'Bearer $newToken';

        try {
          final response = await ref.read(dioProvider).fetch(opts);
          handler.resolve(response);
          return;
        } catch (e) {
          handler.next(err);
          return;
        }
      }
    }
    handler.next(err);
  }

  Future<bool> _refreshToken() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final refreshToken = await storage.read(key: 'refresh_token');

      if (refreshToken == null) return false;

      final response = await Dio().post(
        '$baseUrl/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        await storage.write(
            key: 'access_token', value: response.data['accessToken']);
        await storage.write(
            key: 'refresh_token', value: response.data['refreshToken']);
        return true;
      }
    } catch (e) {
      // Refresh failed, logout user
      final storage = ref.read(secureStorageProvider);
      await storage.deleteAll();
    }
    return false;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic errors;

  ApiException({required this.message, this.statusCode, this.errors});

  factory ApiException.fromDioError(DioException e) {
    String message = 'Bir hata oluştu';
    int? statusCode = e.response?.statusCode;
    dynamic errors;

    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        message = data['message'] ?? message;
        errors = data['errors'];
      }
    } else {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Bağlantı zaman aşımı';
          break;
        case DioExceptionType.connectionError:
          message = 'İnternet bağlantısı yok';
          break;
        default:
          message = 'Sunucu hatası';
      }
    }

    return ApiException(
        message: message, statusCode: statusCode, errors: errors);
  }

  @override
  String toString() => message;
}
