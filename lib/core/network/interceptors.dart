import 'dart:developer' as developer;
import 'dart:math';

import 'package:dio/dio.dart';

/// Shared interceptors.
///
/// NOTE: `AuthInterceptor` deliberately does NOT live here any more. It moved
/// to `interceptors/auth_interceptor.dart` when refresh became null-safe, and
/// the old copy in this file is what produced:
///
///   The argument type 'String?' can't be assigned to the parameter type
///   'String'  — interceptors.dart:41 / :67
///
/// Keeping two definitions would also shadow the new one, so only the two
/// classes below belong in this file.

/// Retries transient failures for SAFE methods only.
///
/// Mutations are never blindly retried: they use idempotency keys or the
/// offline queue instead, so a retry cannot duplicate an inspection or a
/// photo upload.
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

    // Exponential backoff with jitter: ~400ms, 800ms, 1600ms (+/- 200ms).
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
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    developer.log(
      '<-- ${response.statusCode} ${response.requestOptions.uri.path}',
      name: 'SCI',
    );
    handler.next(response);
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
