import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'api_error.dart';
import 'interceptors.dart';

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
        SessionInvalidatedSignal.new);

BaseOptions _options() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 2), // photo evidence
      headers: <String, dynamic>{'Accept': 'application/json'},
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    );

/// Bare Dio for /auth/refresh and retry replay. No AuthInterceptor: recursion.
final _refreshDioProvider = Provider<Dio>((ref) => Dio(_options()));

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_options());
  const uuid = Uuid();

  dio.interceptors.addAll(<Interceptor>[
    InterceptorsWrapper(onRequest: (o, h) {
      o.headers['X-Client-Request-Id'] = uuid.v4();
      o.headers['X-Client-Platform'] = AppConfig.platform;
      h.next(o);
    }),
    AuthInterceptor(
      tokenStore: ref.watch(tokenStoreProvider),
      refreshDio: ref.watch(_refreshDioProvider),
      onSessionInvalid: (reason) async =>
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

  Future<T> get<T>(String path,
          {Map<String, dynamic>? query, CancelToken? cancelToken}) =>
      _guard(() => _dio.get<T>(path,
          queryParameters: query, cancelToken: cancelToken));

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
      _guard(() => _dio.post<T>(path,
          data: form, onSendProgress: onProgress, cancelToken: cancelToken));

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
