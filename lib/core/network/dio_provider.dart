import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/redacting_log_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Emitted when the session becomes genuinely invalid, so the router can
/// redirect to /login without the interceptor knowing about navigation.
class SessionInvalidatedSignal extends Notifier<String?> {
  @override
  String? build() => null;

  void invalidate(String reason) => state = reason;
  void reset() => state = null;
}

final sessionInvalidatedProvider =
    NotifierProvider<SessionInvalidatedSignal, String?>(
  SessionInvalidatedSignal.new,
);

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      // Generous send timeout: photo evidence can be several megabytes.
      sendTimeout: const Duration(minutes: 2),
      headers: <String, dynamic>{'Accept': 'application/json'},
      // We normalise errors ourselves, so let Dio throw on non-2xx.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    );

/// Bare Dio used ONLY for token refresh and for replaying retried requests.
/// It deliberately has no [AuthInterceptor] to avoid infinite recursion.
final _refreshDioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  if (kDebugMode) dio.interceptors.add(RedactingLogInterceptor());
  return dio;
});

/// The application Dio instance. Every repository must use this.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  final refreshDio = ref.watch(_refreshDioProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  const uuid = Uuid();

  dio.interceptors.addAll(<Interceptor>[
    // Correlates client logs with backend audit events.
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Client-Request-Id'] = uuid.v4();
        options.headers['X-Client-Platform'] = AppConfig.platform;
        handler.next(options);
      },
    ),
    AuthInterceptor(
      tokenStore: tokenStore,
      refreshDio: refreshDio,
      onSessionInvalid: (reason) async {
        ref.read(sessionInvalidatedProvider.notifier).invalidate(reason);
      },
    ),
    RetryInterceptor(dio: dio),
    if (kDebugMode) RedactingLogInterceptor(),
  ]);

  ref.onDispose(dio.close);
  return dio;
});
