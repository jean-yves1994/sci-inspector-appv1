import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
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

  /// POST /auth/login
  ///
  /// The backend returns `refreshToken` for android/ios and omits it for web
  /// (where it sets an HttpOnly cookie instead). Reading it as `String?` is
  /// what fixes the original crash:
  ///
  ///   type 'Null' is not a subtype of type 'String'
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'platform': AppConfig.platform,
      },
    );

    final accessToken = json['accessToken'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw ApiError(
        code: ApiErrorCode.unknown,
        message: 'Sign-in succeeded but the server returned no access token. '
            'Fields received: ${json.keys.join(', ')}',
      );
    }

    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw ApiError(
        code: ApiErrorCode.unknown,
        message: 'Sign-in succeeded but the server returned no user object. '
            'Fields received: ${json.keys.join(', ')}',
      );
    }

    // Nullable by design — see the doc comment above.
    final refreshToken = json['refreshToken'] as String?;

    if (kDebugMode && (refreshToken == null || refreshToken.isEmpty)) {
      debugPrint(
        'SCI: no refreshToken in the login response (platform sent: '
        '"${AppConfig.platform}"). The session will end when the access '
        'token expires. On the browser build, pass '
        '--dart-define=SCI_PLATFORM=android to exercise the real mobile '
        'refresh flow.',
      );
    }

    final tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(
        Duration(seconds: (json['expiresIn'] as num?)?.toInt() ?? 900),
      ),
    );

    await _store.write(tokens);
    return AuthResult(user: User.fromJson(userJson), tokens: tokens);
  }

  /// Authoritative current user. Never trust cached user data.
  Future<User> me() async {
    final json = await _api.get<Map<String, dynamic>>('/auth/me');
    final payload = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    return User.fromJson(payload);
  }

  Future<void> logout() async {
    try {
      await _api.post<dynamic>('/auth/logout');
    } on ApiError {
      // Signing out locally must succeed even if the server is unreachable.
    } finally {
      await _store.clear();
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
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);
