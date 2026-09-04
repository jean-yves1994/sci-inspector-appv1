import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../domain/user.dart';

/// Result of a successful login.
class AuthResult {
  const AuthResult({required this.user, required this.tokens});
  final User user;
  final AuthTokens tokens;
}

/// All /auth endpoints. Contains no UI logic and no navigation.
class AuthRepository {
  const AuthRepository(this._api, this._tokenStore);

  final ApiClient _api;
  final TokenStore _tokenStore;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'platform': AppConfig.platform,
      },
    );

    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    // expiresIn always comes from the backend — never hard-coded.
    final expiresIn = (data['expiresIn'] as num?)?.toInt() ?? 3600;
    final tokens = AuthTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );

    await _tokenStore.write(tokens);
    return AuthResult(user: user, tokens: tokens);
  }

  /// Authoritative current user. Never trust locally cached user data.
  Future<User> me() async {
    final data = await _api.get<Map<String, dynamic>>('/auth/me');
    // Some backends nest the payload under `user`.
    final payload = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return User.fromJson(payload);
  }

  Future<void> logout() async {
    try {
      await _api.post<dynamic>('/auth/logout');
    } finally {
      // Always clear locally, even if the server call failed.
      await _tokenStore.clear();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _api.post<dynamic>(
        '/auth/change-password',
        body: <String, dynamic>{
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

  Future<void> forgotPassword(String email) => _api.post<dynamic>(
        '/auth/forgot-password',
        body: <String, dynamic>{'email': email.trim()},
      );

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _api.post<dynamic>(
        '/auth/reset-password',
        body: <String, dynamic>{'token': token, 'newPassword': newPassword},
      );

  Future<void> registerDevice({
    required String token,
    required String deviceId,
  }) =>
      _api.post<dynamic>(
        '/auth/devices',
        body: <String, dynamic>{
          'token': token,
          'platform': AppConfig.platform,
          'deviceId': deviceId,
        },
      );
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});
