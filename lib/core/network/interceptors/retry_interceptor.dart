import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Retries transient failures for SAFE requests only.
///
/// Mutations are never blindly retried here — they go through the offline
/// mutation queue with idempotency keys instead (spec section 91).
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryableMethods = const <String>{'GET', 'HEAD'},
  });

  final Dio dio;
  final int maxRetries;
  final Set<String> retryableMethods;

  static const String _attemptKey = 'sci.retryAttempt';
  final Random _random = Random();

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (!_shouldRetry(err) ||
        !retryableMethods.contains(options.method.toUpperCase()) ||
        attempt >= maxRetries) {
      return handler.next(err);
    }

    final nextAttempt = attempt + 1;
    options.extra[_attemptKey] = nextAttempt;

    // Exponential backoff with jitter: ~400ms, 800ms, 1600ms (+/- 200ms).
    final base = 400 * pow(2, attempt).toInt();
    final jitter = _random.nextInt(200);
    await Future<void>.delayed(Duration(milliseconds: base + jitter));

    try {
      final response = await dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status == 502 || status == 503 || status == 504;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return false;
    }
  }
}
