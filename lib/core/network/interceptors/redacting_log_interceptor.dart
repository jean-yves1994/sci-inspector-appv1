import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Debug-only logger that redacts every security-sensitive value.
///
/// Never logs: passwords, access tokens, refresh tokens, national IDs
/// (spec sections 78 and 93).
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

  static const Set<String> _redactedHeaders = <String>{
    'authorization',
    'cookie',
    'set-cookie',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log(
      '--> ${options.method} ${options.uri.path}\n'
      'headers: ${_scrubHeaders(options.headers)}\n'
      'body: ${_scrub(options.data)}',
      name: 'SCI.api',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler h) {
    developer.log(
      '<-- ${response.statusCode} ${response.requestOptions.uri.path}\n'
      'body: ${_scrub(response.data)}',
      name: 'SCI.api',
    );
    h.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '<-- ERROR ${err.response?.statusCode} '
      '${err.requestOptions.uri.path}\n'
      'type: ${err.type}\n'
      'body: ${_scrub(err.response?.data)}',
      name: 'SCI.api',
    );
    handler.next(err);
  }

  Map<String, dynamic> _scrubHeaders(Map<String, dynamic> headers) {
    return headers.map((key, dynamic value) {
      if (_redactedHeaders.contains(key.toLowerCase())) {
        return MapEntry(key, '<redacted>');
      }
      return MapEntry(key, value);
    });
  }

  Object? _scrub(Object? data) {
    if (data is FormData) {
      // Never log raw binary evidence.
      return '<multipart: ${data.files.length} file(s), '
          '${data.fields.length} field(s)>';
    }
    if (data is Map) {
      return data.map<String, dynamic>((dynamic key, dynamic value) {
        final k = key.toString();
        if (_redactedKeys.contains(k)) return MapEntry(k, '<redacted>');
        return MapEntry(k, _scrub(value as Object?));
      });
    }
    if (data is List) {
      return data.map<Object?>((dynamic e) => _scrub(e as Object?)).toList();
    }
    return data;
  }
}
