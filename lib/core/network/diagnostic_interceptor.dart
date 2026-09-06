import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Temporary diagnostic tracer.
///
/// "Something went wrong. Please try again." is the generic fallback in
/// `ApiError._messageForStatus`, returned when the status code is not one of
/// the handled cases. It hides which request failed and why.
///
/// This prints every request and response involved in loading and saving an
/// inspection, including the full error body, so the failure is identifiable
/// without a debugger.
///
/// Wire it into `dioProvider` LAST, so it observes what every other
/// interceptor has already done:
///
///   RetryInterceptor(dio: dio),
///   if (kDebugMode) DiagnosticInterceptor(),
///
/// Remove it once the cause is found — it logs response bodies, which is
/// acceptable in debug only.
class DiagnosticInterceptor extends Interceptor {
  /// Last baseVersion sent per inspection, to expose duplicates.
  final Map<String, int> _lastSent = <String, int>{};

  static final RegExp _idPattern = RegExp(r'/inspections/([0-9a-fA-F-]{8,})');

  String? _inspectionId(String path) => _idPattern.firstMatch(path)?.group(1);

  String _short(String path) {
    final id = _inspectionId(path);
    if (id == null) return path;
    return path.replaceFirst(id, id.substring(0, 8));
  }

  int? _baseVersion(Object? data) =>
      data is Map && data['baseVersion'] is num
          ? (data['baseVersion'] as num).toInt()
          : null;

  int? _version(Object? data) {
    if (data is! Map) return null;
    if (data['version'] is num) return (data['version'] as num).toInt();
    final nested = data['data'];
    if (nested is Map && nested['version'] is num) {
      return (nested['version'] as num).toInt();
    }
    return null;
  }

  String _keys(Object? data) {
    if (data is Map) return data.keys.join(', ');
    if (data is List) return '[list of ${data.length}]';
    return data.runtimeType.toString();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.path.contains('/inspections')) return handler.next(options);

    final sent = _baseVersion(options.data);
    final id = _inspectionId(options.path);

    if (id != null && sent != null) {
      final previous = _lastSent[id];
      if (previous != null && previous == sent) {
        developer.log(
          '[diag] !! duplicate baseVersion=$sent — two writes share a version',
          name: 'SCI',
        );
      }
      _lastSent[id] = sent;
    }

    developer.log(
      '[diag] --> ${options.method} ${_short(options.path)}'
      '${sent == null ? '' : '  baseVersion=$sent'}',
      name: 'SCI',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    if (!options.path.contains('/inspections')) return handler.next(response);

    final got = _version(response.data);
    final id = _inspectionId(options.path);
    if (id != null && got != null) _lastSent[id] = got;

    developer.log(
      '[diag] <-- ${response.statusCode} ${_short(options.path)}  '
      'version=${got ?? 'ABSENT'}  keys={${_keys(response.data)}}',
      name: 'SCI',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;

    // Log EVERY failure, not just inspection ones: the screen that fails may
    // be blocked by a template or completeness call.
    var body = '';
    try {
      body = err.response?.data == null
          ? '(no body)'
          : const JsonEncoder.withIndent('  ').convert(err.response?.data);
    } catch (_) {
      body = err.response?.data.toString() ?? '(unreadable)';
    }

    developer.log(
      '[diag] XX ${err.response?.statusCode ?? err.type} '
      '${options.method} ${_short(options.path)}\n'
      '$body',
      name: 'SCI',
    );
    handler.next(err);
  }
}
