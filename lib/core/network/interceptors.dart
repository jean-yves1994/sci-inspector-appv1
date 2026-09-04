import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_error.dart';

/// Attaches the bearer token and performs SINGLE-FLIGHT refresh on 401.
///
/// QueuedInterceptor + a Completer guarantee that N concurrent 401s trigger
/// exactly one refresh. This is essential because the backend ROTATES the
/// refresh token and revokes the previous one; parallel refreshes would
/// invalidate each other and sign the inspector out mid-inspection.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokenStore,
    required this.refreshDio,
    required this.onSessionInvalid,
  });

  final TokenStore tokenStore;
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
    if (err.response?.statusCode != 401 ||
        options.extra[retriedFlag] == true ||
        options.extra[skipAuthFlag] == true) {
      return handler.next(err);
    }

    final current = await tokenStore.read();
    if (current == null) {
      await onSessionInvalid('No stored session.');
      return handler.next(err);
    }

    final refreshed = await _refresh(current.refreshToken);
    if (refreshed == null) return handler.next(err);

    options.extra[retriedFlag] = true; // retry exactly once
    options.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
    try {
      return handler.resolve(await refreshDio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  Future<AuthTokens?> _refresh(String refreshToken) {
    final existing = _inFlight;
    if (existing != null) return existing.future;

    final completer = Completer<AuthTokens?>();
    _inFlight = completer;
    _perform(refreshToken)
        .then(completer.complete)
        .catchError((Object _) => completer.complete(null))
        .whenComplete(() => _inFlight = null);
    return completer.future;
  }

  Future<AuthTokens?> _perform(String refreshToken) async {
    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
        options: Options(extra: <String, dynamic>{skipAuthFlag: true}),
      );
      final data = response.data;
      if (data == null) return null;

      final tokens = AuthTokens(
        accessToken: data['accessToken'] as String,
        // Always store the NEW rotated token; never reuse the old one.
        refreshToken: data['refreshToken'] as String,
        expiresAt: DateTime.now().add(
          Duration(seconds: (data['expiresIn'] as num?)?.toInt() ?? 3600),
        ),
      );
      await tokenStore.write(tokens);
      return tokens;
    } on DioException catch (e) {
      final error = ApiError.fromDio(e);
      // Only destroy the session on real auth failure, never on 5xx/timeout.
      if (error.isSessionInvalid || e.response?.statusCode == 401) {
        await tokenStore.clear();
        await onSessionInvalid(error.message);
      }
      return null;
    }
  }
}

/// Retries transient failures for SAFE methods only.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({required this.dio, this.maxRetries = 3});

  final Dio dio;
  final int maxRetries;

  static const String _attemptKey = 'sci.retryAttempt';
  final Random _rng = Random();

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    const safe = <String>{'GET', 'HEAD'};

    if (!_retryable(err) ||
        !safe.contains(options.method.toUpperCase()) ||
        attempt >= maxRetries) {
      return handler.next(err);
    }

    options.extra[_attemptKey] = attempt + 1;
    await Future<void>.delayed(
      Duration(
        milliseconds: 400 * pow(2, attempt).toInt() + _rng.nextInt(200),
      ),
    );
    try {
      return handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  bool _retryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        return <int>{502, 503, 504}.contains(e.response?.statusCode ?? 0);
      default:
        return false;
    }
  }
}

/// Debug-only logger. Redacts every security-sensitive value.
class RedactingLogInterceptor extends Interceptor {
  static const Set<String> _redactedKeys = <String>{
    'password',
    'currentPassword',
    'newPassword',
    'accessToken',
    'refreshToken',
    'token',
    'nationalId',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log(
      '--> ${options.method} ${options.uri.path} ${_scrub(options.data)}',
      name: 'SCI',
    );
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '<-- ERR ${err.response?.statusCode} ${err.requestOptions.uri.path} '
      '${_scrub(err.response?.data)}',
      name: 'SCI',
    );
    handler.next(err);
  }

  Object? _scrub(Object? data) {
    if (data is FormData) {
      // Never log raw binary evidence.
      return '<multipart ${data.files.length} file(s)>';
    }
    if (data is Map) {
      return data.map<String, dynamic>(
        (dynamic k, dynamic v) => MapEntry(
          k.toString(),
          _redactedKeys.contains(k.toString()) ? '<redacted>' : _scrub(v),
        ),
      );
    }
    if (data is List) {
      return data.map<Object?>((dynamic e) => _scrub(e)).toList();
    }
    return data;
  }
}
