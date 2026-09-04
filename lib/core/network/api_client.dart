import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_error.dart';
import 'dio_provider.dart';

/// Thin repository-facing wrapper that guarantees every failure surfaces as a
/// normalised [ApiError] rather than a raw [DioException].
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

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) =>
      _guard(() => _dio.post<T>(
            path,
            data: body,
            queryParameters: query,
            cancelToken: cancelToken,
          ));

  Future<T> patch<T>(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) =>
      _guard(() => _dio.patch<T>(path, data: body, cancelToken: cancelToken));

  Future<T> delete<T>(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) =>
      _guard(() => _dio.delete<T>(path, data: body, cancelToken: cancelToken));

  /// Multipart upload with progress, used by photo evidence in Phase 5.
  Future<T> uploadMultipart<T>(
    String path, {
    required FormData form,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) =>
      _guard(() => _dio.post<T>(
            path,
            data: form,
            onSendProgress: onProgress,
            cancelToken: cancelToken,
          ));

  Future<T> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
