import 'dart:async';

import 'package:dio/dio.dart';

import '../../storage/token_store.dart';
import '../api_error.dart';

/// Attaches the bearer token, and performs single-flight refresh on 401.
///
/// Extends [QueuedInterceptor] so that several concurrent 401s cannot trigger
/// parallel refresh calls — critical because the backend ROTATES refresh
/// tokens and invalidates the previous one (spec section 8).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokenStore,
    required this.refreshDio,
    required this.onSessionInvalid,
  });

  final TokenStore tokenStore;

  /// A bare Dio instance WITHOUT this interceptor, used to call /auth/refresh.
  /// Using the main instance would recurse infinitely.
  final Dio refreshDio;

  /// Invoked when the refresh token is genuinely invalid/revoked.
  final Future<void> Function(String reason) onSessionInvalid;

  static const String _retriedFlag = 'sci.retried';
  static const String skipAuthFlag = 'sci.skipAuth';

  Completer<AuthTokens?>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthFlag] == true) {
      return handler.next(options);
    }

    var tokens = await tokenStore.read();

    // Proactively refresh if we already know the access token is stale.
    if (tokens != null && tokens.isNearlyExpired) {
      tokens = await _refresh(tokens.refreshToken);
    }

    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = options.extra[_retriedFlag] == true;
    final skipsAuth = options.extra[skipAuthFlag] == true;

    if (!isUnauthorized || alreadyRetried || skipsAuth) {
      return handler.next(err);
    }

    final current = await tokenStore.read();
    if (current == null) {
      await onSessionInvalid('No stored session.');
      return handler.next(err);
    }

    final refreshed = await _refresh(current.refreshToken);
    if (refreshed == null) {
      return handler.next(err);
    }

    // Retry the original request exactly once.
    options.extra[_retriedFlag] = true;
    options.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';

    try {
      final response = await refreshDio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  /// Single-flight refresh guarded by a [Completer].
  Future<AuthTokens?> _refresh(String refreshToken) {
    final existing = _refreshInFlight;
    if (existing != null) return existing.future;

    final completer = Completer<AuthTokens?>();
    _refreshInFlight = completer;

    _performRefresh(refreshToken).then((tokens) {
      completer.complete(tokens);
    }).catchError((Object error) {
      completer.complete(null);
    }).whenComplete(() {
      _refreshInFlight = null;
    });

    return completer.future;
  }

  Future<AuthTokens?> _performRefresh(String refreshToken) async {
    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
        options: Options(extra: <String, dynamic>{skipAuthFlag: true}),
      );

      final data = response.data;
      if (data == null) {
        await _invalidate('Malformed refresh response.');
        return null;
      }

      final expiresIn = (data['expiresIn'] as num?)?.toInt() ?? 3600;
      final tokens = AuthTokens(
        accessToken: data['accessToken'] as String,
        // The backend rotates the refresh token — always store the new one and
        // never reuse the previous value.
        refreshToken: data['refreshToken'] as String,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );

      await tokenStore.write(tokens);
      return tokens;
    } on DioException catch (e) {
      final error = ApiError.fromDio(e);

      // Only destroy the session for genuine auth failures. A timeout or a
      // 503 must never sign the inspector out mid-inspection.
      if (error.isSessionInvalid || e.response?.statusCode == 401) {
        await _invalidate(error.message);
      }
      return null;
    }
  }

  Future<void> _invalidate(String reason) async {
    await tokenStore.clear();
    await onSessionInvalid(reason);
  }
}
