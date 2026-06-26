// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import '../config/api_config.dart';

// État de l'authentification
class AuthState {
  final Map<String, dynamic>? profile;
  final bool   isLoading;
  final String? error;

  const AuthState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    Map<String, dynamic>? profile,
    bool?   isLoading,
    String? error,
  }) {
    return AuthState(
      profile:   profile   ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error:     error     ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> registerVendor({
    required String shopName,
    required String fullName,
    required String whatsapp,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiService.post(ApiConfig.registerVendor, {
        'shop_name': shopName,
        'full_name': fullName,
        'whatsapp':  whatsapp,
        'password':  password,
      });
      state = state.copyWith(isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<bool> login({
    required String whatsapp,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await ApiService.post(ApiConfig.login, {
        'whatsapp': whatsapp,
        'password': password,
      });

      await LocalStorage.saveToken(data['token']);
      await LocalStorage.saveRole(data['profile']['role']);
      await LocalStorage.saveUserId(data['profile']['id']);

      if (data['profile']['shop_name'] != null) {
        await LocalStorage.saveShopName(data['profile']['shop_name']);
      }

      state = state.copyWith(isLoading: false, profile: data['profile']);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<void> logout() async {
    await LocalStorage.clearAll();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);