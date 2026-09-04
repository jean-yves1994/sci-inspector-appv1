import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Debug-only tracer for the optimistic-concurrency lifecycle.
///
/// Prints one line per inspection mutation showing the `baseVersion` sent and
/// the `version` returned, so a regression or a duplicated baseVersion is
/// visible in the browser console without a debugger.
///
/// Wire it into `dioProvider` AFTER RetryInterceptor:
///
///   if (kDebugMode) VersionTraceInterceptor(),
///   if (kDebugMode) RedactingLogInterceptor(),
///
/// Typical healthy output:
///
///   [ver] PATCH /inspections/218aa6d8/values   sent=4  ->  got=5   OK
///   [ver] PATCH /inspections/218aa6d8/owner    sent=5  ->  got=6   OK
///
/// Two symptoms it makes obvious:
///
///   sent=0                     the local version regressed (start() response
///                              omitted `version`, parsed as 0)
///
///   sent=4 twice in a row      two mutations read the same baseVersion, i.e.
///                              writes are not serialised
class VersionTraceInterceptor extends Interceptor {
  /// Last baseVersion sent per inspection id, to spot duplicates.
  final Map<String, int> _lastSent = <String, int>{};

  static final RegExp _inspectionPath =
      RegExp(r'/inspections/([0-9a-fA-F-]{8,})');

  String? _inspectionId(String path) =>
      _inspectionPath.firstMatch(path)?.group(1);

  bool _isMutation(RequestOptions o) {
    final m = o.method.toUpperCase();
    return (m == 'PATCH' || m == 'POST') && o.path.contains('/inspections/');
  }

  int? _baseVersionOf(Object? data) {
    if (data is Map && data['baseVersion'] is num) {
      return (data['baseVersion'] as num).toInt();
    }
    return null;
  }

  int? _versionOf(Object? data) {
    if (data is! Map) return null;
    if (data['version'] is num) return (data['version'] as num).toInt();
    final nested = data['data'];
    if (nested is Map && nested['version'] is num) {
      return (nested['version'] as num).toInt();
    }
    return null;
  }

  String _short(String path) {
    final id = _inspectionId(path);
    if (id == null) return path;
    return path.replaceFirst(id, id.substring(0, 8));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isMutation(options)) {
      final id = _inspectionId(options.path);
      final sent = _baseVersionOf(options.data);

      if (id != null && sent != null) {
        final previous = _lastSent[id];
        if (previous != null && previous == sent) {
          developer.log(
            '[ver] WARNING duplicate baseVersion=$sent on ${_short(options.path)} '
            '— two writes are sharing a version, expect a 409',
            name: 'SCI',
          );
        }
        _lastSent[id] = sent;
      }

      if (sent == 0) {
        developer.log(
          '[ver] WARNING baseVersion=0 on ${_short(options.path)} '
          '— the local version regressed, expect a 409',
          name: 'SCI',
        );
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    if (_isMutation(options)) {
      final sent = _baseVersionOf(options.data);
      final got = _versionOf(response.data);

      final id = _inspectionId(options.path);
      if (id != null && got != null) _lastSent[id] = got;

      developer.log(
        '[ver] ${options.method} ${_short(options.path)}  '
        'sent=${sent ?? '-'}  ->  got=${got ?? 'ABSENT'}'
        '${got == null ? '   <-- response has no version field' : '   OK'}',
        name: 'SCI',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    if (_isMutation(options) && err.response?.statusCode == 409) {
      final sent = _baseVersionOf(options.data);
      final body = err.response?.data;

      int? serverVersion;
      if (body is Map) {
        final error = body['error'];
        final details = error is Map ? error['details'] : body['details'];
        if (details is Map && details['serverVersion'] is num) {
          serverVersion = (details['serverVersion'] as num).toInt();
        }
      }

      developer.log(
        '[ver] CONFLICT ${_short(options.path)}  '
        'sent=${sent ?? '-'}  server=${serverVersion ?? '?'}',
        name: 'SCI',
      );
    }
    handler.next(err);
  }
}
