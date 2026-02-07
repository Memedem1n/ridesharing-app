import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../providers/auth_provider.dart';

class NotificationState {
  final bool initialized;
  final String? token;

  const NotificationState({this.initialized = false, this.token});

  NotificationState copyWith({bool? initialized, String? token}) {
    return NotificationState(
      initialized: initialized ?? this.initialized,
      token: token ?? this.token,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier(this._ref) : super(const NotificationState());

  final Ref _ref;
  bool _initializing = false;

  Future<void> init() async {
    if (state.initialized || _initializing) return;
    _initializing = true;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      _initializing = false;
      state = state.copyWith(initialized: true);
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    messaging.onTokenRefresh.listen((newToken) async {
      await _registerToken(newToken);
    });

    state = state.copyWith(initialized: true, token: token);
    _initializing = false;
  }

  Future<void> reset() async {
    state = const NotificationState();
  }

  Future<void> _registerToken(String token) async {
    final authToken = await _ref.read(authTokenProvider.future);
    if (authToken == null) return;

    final dio = _ref.read(dioProvider);
    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : defaultTargetPlatform == TargetPlatform.android
                ? 'android'
                : 'unknown';

    try {
      await dio.post(
        '/users/me/device-token',
        data: {'deviceToken': token, 'platform': platform},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
    } catch (_) {
      // Ignore registration errors
    }
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});
