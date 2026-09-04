import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/token_store.dart';
import '../domain/user.dart';

class AuthResult {
  const AuthResult({required this.user, required this.tokens});
  final User user;
  final AuthTokens tokens;
}

class AuthRepository {
  const AuthRepository(this._api, this._store);
  final ApiClient _api;
  final TokenStore _store;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final d = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'platform': AppConfig.platform,
      },
    );

    final user = User.fromJson(d['user'] as Map<String, dynamic>);
    // expiresIn always comes from the server, never hard-coded.
    final tokens = AuthTokens(
      accessToken: d['accessToken'] as String,
      refreshToken: d['refreshToken'] as String,
      expiresAt: DateTime.now()
          .add(Duration(seconds: (d['expiresIn'] as num?)?.toInt() ?? 3600)),
    );
    await _store.write(tokens);
    return AuthResult(user: user, tokens: tokens);
  }

  /// Authoritative current user. Never trust cached user data.
  Future<User> me() async {
    final d = await _api.get<Map<String, dynamic>>('/auth/me');
    final payload =
        d['user'] is Map<String, dynamic> ? d['user'] as Map<String, dynamic> : unwrap(d);
    return User.fromJson(payload);
  }

  Future<void> logout() async {
    try {
      await _api.post<dynamic>('/auth/logout');
    } finally {
      // Local sign-out must succeed even if the server is unreachable.
      await _store.clear();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _api.post<dynamic>('/auth/change-password', body: <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  Future<void> forgotPassword(String email) => _api.post<dynamic>(
      '/auth/forgot-password',
      body: <String, dynamic>{'email': email.trim()});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _api.post<dynamic>('/auth/reset-password',
          body: <String, dynamic>{'token': token, 'newPassword': newPassword});
}

final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)));
