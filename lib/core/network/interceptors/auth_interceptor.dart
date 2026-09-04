import 'dart:async';

import 'package:dio/dio.dart';

import '../../storage/token_store.dart';
import '../api_error.dart';

/// Attaches the access token and performs single-flight refresh on 401.
///
/// Uses the mobile flow: the refresh token travels in the request body. No
/// cookie handling, because SCI ships to Android/iOS and the browser build
/// impersonates a mobile client via `--dart-define=SCI_PLATFORM=android`.
///
/// Extends [QueuedInterceptor] so N concurrent 401s collapse into exactly one
/// refresh. That matters because the backend ROTATES the refresh token and
/// revokes the previous one — parallel refreshes would invalidate each other
/// and sign the inspector out mid-inspection.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokenStore,
    required this.refreshDio,
    required this.onSessionInvalid,
  });

  final TokenStore tokenStore;

  /// A Dio instance WITHOUT this interceptor, to avoid infinite recursion.
  final Dio refreshDio;

  final Future<void> Function(String reason) onSessionInvalid;

  static const String retriedFlag = 'sci.retried';
  static const String skipAuthFlag = 'sci.skipAuth';

  Completer<AuthTokens?>? _inFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthFlag] == true) return handler.next(options);

    var tokens = await tokenStore.read();

    // Refresh proactively when the access token is about to expire.
    if (tokens != null && tokens.isNearlyExpired && tokens.hasRefreshToken) {
      tokens = await _refresh(tokens.refreshToken!) ?? tokens;
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

    if (err.response?.statusCode != 401 ||
        options.extra[retriedFlag] == true ||
        options.extra[skipAuthFlag] == true) {
      return handler.next(err);
    }

    final current = await tokenStore.read();

    // No refresh token means nothing to recover with — e.g. the browser build
    // was run without SCI_PLATFORM, so the server withheld it.
    if (current == null || !current.hasRefreshToken) {
      await onSessionInvalid('Session expired. Please sign in again.');
      return handler.next(err);
    }

    final refreshed = await _refresh(current.refreshToken!);
    if (refreshed == null) return handler.next(err);

    // Retry the original request exactly once.
    options.extra[retriedFlag] = true;
    options.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
    try {
      return handler.resolve(await refreshDio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  /// Single-flight guard: concurrent callers share one refresh.
  Future<AuthTokens?> _refresh(String refreshToken) {
    final existing = _inFlight;
    if (existing != null) return existing.future;

    final completer = Completer<AuthTokens?>();
    _inFlight = completer;

    _performRefresh(refreshToken)
        .then(completer.complete)
        .catchError((Object _) => completer.complete(null))
        .whenComplete(() => _inFlight = null);

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
      final access = data?['accessToken'];
      if (access is! String || access.isEmpty) {
        await _invalidate('Refresh response contained no access token.');
        return null;
      }

      // The backend rotates the token; keep the old one only if a new one was
      // not supplied.
      final rotated = data?['refreshToken'];

      final tokens = AuthTokens(
        accessToken: access,
        refreshToken: rotated is String && rotated.isNotEmpty
            ? rotated
            : refreshToken,
        expiresAt: DateTime.now().add(
          Duration(seconds: (data?['expiresIn'] as num?)?.toInt() ?? 900),
        ),
      );

      await tokenStore.write(tokens);
      return tokens;
    } on DioException catch (e) {
      final error = ApiError.fromDio(e);

      // Only destroy the session on a genuine auth failure. A timeout, a 502
      // or an offline device must never sign an inspector out in the field.
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
