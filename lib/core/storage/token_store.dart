import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isNearlyExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
}

abstract class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _s;
  static const _kA = 'sci.accessToken';
  static const _kR = 'sci.refreshToken';
  static const _kE = 'sci.expiresAt';

  @override
  Future<AuthTokens?> read() async {
    final a = await _s.read(key: _kA);
    final r = await _s.read(key: _kR);
    final e = await _s.read(key: _kE);
    if (a == null || r == null || e == null) return null;
    final exp = DateTime.tryParse(e);
    if (exp == null) return null;
    return AuthTokens(accessToken: a, refreshToken: r, expiresAt: exp);
  }

  @override
  Future<void> write(AuthTokens t) async {
    await _s.write(key: _kA, value: t.accessToken);
    await _s.write(key: _kR, value: t.refreshToken);
    await _s.write(key: _kE, value: t.expiresAt.toIso8601String());
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: _kA);
    await _s.delete(key: _kR);
    await _s.delete(key: _kE);
  }
}

/// Web/QA store. Browser storage is not a hardware keystore, so tokens live
/// in memory only and are intentionally lost on reload.
class InMemoryTokenStore implements TokenStore {
  AuthTokens? _t;
  @override
  Future<AuthTokens?> read() async => _t;
  @override
  Future<void> write(AuthTokens t) async => _t = t;
  @override
  Future<void> clear() async => _t = null;
}

final tokenStoreProvider = Provider<TokenStore>(
    (ref) => kIsWeb ? InMemoryTokenStore() : SecureTokenStore());
