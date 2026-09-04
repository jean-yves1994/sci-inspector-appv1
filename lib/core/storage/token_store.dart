import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted authentication material.
///
/// [refreshToken] is nullable because the backend omits it when
/// `platform == 'web'` (it sets an HttpOnly cookie instead). SCI ships to
/// Android/iOS, where the token always arrives in the body — but the field
/// stays nullable so a missing value can never crash login again.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Refresh slightly early so we don't race the server's expiry check.
  bool get isNearlyExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  bool get hasRefreshToken =>
      refreshToken != null && refreshToken!.isNotEmpty;
}

abstract class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// Production store for Android and iOS: Keystore / Keychain.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const String _kAccess = 'sci.accessToken';
  static const String _kRefresh = 'sci.refreshToken';
  static const String _kExpiresAt = 'sci.expiresAt';

  @override
  Future<AuthTokens?> read() async {
    final access = await _storage.read(key: _kAccess);
    final expiry = await _storage.read(key: _kExpiresAt);
    if (access == null || expiry == null) return null;

    final expiresAt = DateTime.tryParse(expiry);
    if (expiresAt == null) return null;

    return AuthTokens(
      accessToken: access,
      refreshToken: await _storage.read(key: _kRefresh),
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(
      key: _kExpiresAt,
      value: tokens.expiresAt.toIso8601String(),
    );

    // The backend rotates refresh tokens, so store each new one — but never
    // wipe a valid token just because one response omitted it.
    if (tokens.hasRefreshToken) {
      await _storage.write(key: _kRefresh, value: tokens.refreshToken);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kExpiresAt);
  }
}

/// Development-only store for `flutter run -d chrome`.
///
/// Everything lives in memory: nothing is written to localStorage,
/// sessionStorage or SharedPreferences, and all of it is discarded on page
/// reload. That is weaker than a hardware keystore, which is precisely why
/// the browser build is a testing convenience and never a shipped target.
class InMemoryTokenStore implements TokenStore {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => kIsWeb ? InMemoryTokenStore() : SecureTokenStore(),
);
