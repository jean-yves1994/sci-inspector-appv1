import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
      RequestOptions options, RequestInterceptorHandler handler) async {
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
      DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        o.extra[retriedFlag] == true ||
        o.extra[skipAuthFlag] == true) {
      return handler.next(err);
    }

    final current = await tokenStore.read();
    if (current == null) {
      await onSessionInvalid('No stored session.');
      return handler.next(err);
    }

    final refreshed = await _refresh(current.refreshToken);
    if (refreshed == null) return handler.next(err);

    o.extra[retriedFlag] = true; // retry exactly once
    o.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
    try {
      return handler.resolve(await refreshDio.fetch<dynamic>(o));
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<AuthTokens?> _refresh(String refreshToken) {
    final existing = _inFlight;
    if (existing != null) return existing.future;

    final c = Completer<AuthTokens?>();
    _inFlight = c;
    _perform(refreshToken)
        .then(c.complete)
        .catchError((Object _) => c.complete(null))
        .whenComplete(() => _inFlight = null);
    return c.future;
  }

  Future<AuthTokens?> _perform(String refreshToken) async {
    try {
      final r = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
        options: Options(extra: <String, dynamic>{skipAuthFlag: true}),
      );
      final d = r.data;
      if (d == null) return null;

      final tokens = AuthTokens(
        accessToken: d['accessToken'] as String,
        // Always store the NEW rotated token; never reuse the old one.
        refreshToken: d['refreshToken'] as String,
        expiresAt: DateTime.now()
            .add(Duration(seconds: (d['expiresIn'] as num?)?.toInt() ?? 3600)),
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
  static const String _k = 'sci.retryAttempt';
  final Random _rng = Random();

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    final attempt = (o.extra[_k] as int?) ?? 0;
    const safe = <String>{'GET', 'HEAD'};

    if (!_retryable(err) ||
        !safe.contains(o.method.toUpperCase()) ||
        attempt >= maxRetries) {
      return handler.next(err);
    }

    o.extra[_k] = attempt + 1;
    await Future<void>.delayed(Duration(
        milliseconds: 400 * pow(2, attempt).toInt() + _rng.nextInt(200)));
    try {
      return handler.resolve(await dio.fetch<dynamic>(o));
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _retryable(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.connectionError =>
          true,
        DioExceptionType.badResponse =>
          <int>{502, 503, 504}.contains(e.response?.statusCode ?? 0),
        _ => false,
      };
}

/// Debug-only logger. Redacts every security-sensitive value.
class RedactingLogInterceptor extends Interceptor {
  static const Set<String> _keys = <String>{
    'password', 'currentPassword', 'newPassword', 'accessToken',
    'refreshToken', 'token', 'nationalId',
  };

  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    developer.log('--> ${o.method} ${o.uri.path} ${_scrub(o.data)}',
        name: 'SCI');
    h.next(o);
  }

  @override
  void onError(DioException e, ErrorInterceptorHandler h) {
    developer.log(
        '<-- ERR ${e.response?.statusCode} ${e.requestOptions.uri.path} '
        '${_scrub(e.response?.data)}',
        name: 'SCI');
    h.next(e);
  }

  Object? _scrub(Object? d) {
    if (d is FormData) return '<multipart ${d.files.length} file(s)>';
    if (d is Map) {
      return d.map<String, dynamic>((dynamic k, dynamic v) =>
          MapEntry(k.toString(),
              _keys.contains(k.toString()) ? '<redacted>' : _scrub(v)));
    }
    if (d is List) return d.map<Object?>((dynamic e) => _scrub(e)).toList();
    return d;
  }
}
