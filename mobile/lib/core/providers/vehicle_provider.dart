import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/vehicles/domain/vehicle_models.dart';
import 'auth_provider.dart';
import '../api/api_client.dart';

class VehicleService {
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final Dio _uploadDio = Dio(BaseOptions(baseUrl: baseUrl));

  Future<List<Vehicle>> getMyVehicles(String token) async {
    try {
      final response = await _dio.get(
        '/vehicles',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final List<dynamic> data = response.data;
      return data.map((json) => Vehicle.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> uploadRegistration(File file, String token) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });

      final response = await _uploadDio.post(
        '/verification/upload-vehicle-registration',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['url'];
    } catch (e) {
      throw Exception('Belge yuklenemedi: $e');
    }
  }

  Future<String?> uploadRegistrationXFile(XFile file, String token) async {
    try {
      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'registration.jpg';
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });

      final response = await _uploadDio.post(
        '/verification/upload-vehicle-registration',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['url'];
    } catch (e) {
      throw Exception('Belge yuklenemedi: $e');
    }
  }

  Future<bool> updateVehicle(
    String id,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      await _dio.put(
        '/vehicles/$id',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Vehicle> createVehicle(Map<String, dynamic> data, String token) async {
    final response = await _dio.post(
      '/vehicles',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Vehicle.fromJson(response.data);
  }
}

final vehicleServiceProvider = Provider((ref) => VehicleService());

final myVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final service = ref.read(vehicleServiceProvider);
  final token = await ref.read(authTokenProvider.future);
  if (token == null) return [];
  return service.getMyVehicles(token);
});
