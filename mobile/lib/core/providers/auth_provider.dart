import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_models.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AuthState());

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final storage = _ref.read(secureStorageProvider);
      final token = await storage.read(key: 'access_token');

      if (token != null) {
        final user = await _repository.getProfile();
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String emailOrPhone, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final tokens = await _repository.login(
        LoginRequest(emailOrPhone: emailOrPhone, password: password),
      );
      await _saveTokens(tokens);
      state =
          state.copyWith(status: AuthStatus.authenticated, user: tokens.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Giris sirasinda beklenmeyen bir hata olustu',
      );
      return false;
    }
  }

  Future<bool> register(
      String name, String email, String phone, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final tokens = await _repository.register(
        RegisterRequest(
            name: name, email: email, phone: phone, password: password),
      );
      await _saveTokens(tokens);
      state =
          state.copyWith(status: AuthStatus.authenticated, user: tokens.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Kayit sirasinda beklenmeyen bir hata olustu',
      );
      return false;
    }
  }

  Future<void> logout() async {
    final storage = _ref.read(secureStorageProvider);
    await storage.deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> updateProfile({
    String? fullName,
    String? bio,
    DriverPreferences? preferences,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null && fullName.trim().isNotEmpty) {
        data['fullName'] = fullName.trim();
      }
      if (bio != null) {
        data['bio'] = bio.trim().isEmpty ? null : bio.trim();
      }
      if (preferences != null) {
        data['preferences'] = preferences.toJson();
      }
      if (data.isEmpty) return false;
      final user = await _repository.updateProfile(data);
      state = state.copyWith(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Profil guncellenirken beklenmeyen bir hata olustu',
      );
      return false;
    }
  }

  Future<bool> uploadProfilePhoto(File file) async {
    try {
      final user = await _repository.uploadProfilePhoto(file);
      state = state.copyWith(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Profil fotografi yuklenirken beklenmeyen bir hata olustu',
      );
      return false;
    }
  }

  Future<void> _saveTokens(AuthTokens tokens) async {
    final storage = _ref.read(secureStorageProvider);
    await storage.write(key: 'access_token', value: tokens.accessToken);
    await storage.write(key: 'refresh_token', value: tokens.refreshToken);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider), ref);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

// Token provider for API calls
final authTokenProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(secureStorageProvider);
  return await storage.read(key: 'access_token');
});
