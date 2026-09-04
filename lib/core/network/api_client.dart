import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'api_error.dart';
// RetryInterceptor + RedactingLogInterceptor.
import 'interceptors.dart';
// AuthInterceptor moved here when refresh became null-safe. Missing this
// import is what produced "The function 'AuthInterceptor' isn't defined".
import 'interceptors/auth_interceptor.dart';

/// Signals an involuntary sign-out so the router can redirect without the
/// interceptor knowing anything about navigation.
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

BaseOptions _options() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      // Generous: photo evidence can be several megabytes.
      sendTimeout: const Duration(minutes: 2),
      headers: <String, dynamic>{'Accept': 'application/json'},
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    );

/// Bare Dio for /auth/refresh and for replaying a retried request.
/// Deliberately has NO AuthInterceptor — that would recurse infinitely.
final refreshDioProvider = Provider<Dio>((ref) {
  final dio = Dio(_options());
  ref.onDispose(dio.close);
  return dio;
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_options());
  const uuid = Uuid();

  dio.interceptors.addAll(<Interceptor>[
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Client-Request-Id'] = uuid.v4();
        options.headers['X-Client-Platform'] = AppConfig.platform;
        handler.next(options);
      },
    ),
    AuthInterceptor(
      tokenStore: ref.watch(tokenStoreProvider),
      refreshDio: ref.watch(refreshDioProvider),
      // `reason` is typed String because AuthInterceptor now resolves; the
      // second error was just fallout from the missing import.
      onSessionInvalid: (String reason) async =>
          ref.read(sessionInvalidatedProvider.notifier).invalidate(reason),
    ),
    RetryInterceptor(dio: dio),
    if (kDebugMode) RedactingLogInterceptor(),
  ]);

  ref.onDispose(dio.close);
  return dio;
});

/// Repository-facing wrapper. Guarantees every failure is an ApiError.
class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) =>
      _guard(() => _dio.get<T>(
            path,
            queryParameters: query,
            cancelToken: cancelToken,
          ));

  Future<T> post<T>(String path, {Object? body, CancelToken? cancelToken}) =>
      _guard(() => _dio.post<T>(path, data: body, cancelToken: cancelToken));

  Future<T> patch<T>(String path, {Object? body}) =>
      _guard(() => _dio.patch<T>(path, data: body));

  Future<T> delete<T>(String path) => _guard(() => _dio.delete<T>(path));

  Future<T> uploadMultipart<T>(
    String path, {
    required FormData form,
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) =>
      _guard(() => _dio.post<T>(
            path,
            data: form,
            onSendProgress: onProgress,
            cancelToken: cancelToken,
          ));

  Future<T> _guard<T>(Future<Response<T>> Function() run) async {
    try {
      return (await run()).data as T;
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}

final apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));
