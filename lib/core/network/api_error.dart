import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiErrorCode {
  const ApiErrorCode._();

  static const String authInvalidCredentials = 'AUTH_INVALID_CREDENTIALS';
  static const String authTokenInvalid = 'AUTH_TOKEN_INVALID';
  static const String authSessionRevoked = 'AUTH_SESSION_REVOKED';
  static const String authForbidden = 'AUTH_FORBIDDEN';
  static const String inspectionNotFound = 'INSPECTION_NOT_FOUND';
  static const String inspectionInvalidTransition =
      'INSPECTION_INVALID_TRANSITION';
  static const String inspectionIncomplete = 'INSPECTION_INCOMPLETE';
  static const String inspectionStaleVersion = 'INSPECTION_STALE_VERSION';
  static const String validation = 'VALIDATION_ERROR';
  static const String photoTooLarge = 'PHOTO_TOO_LARGE';
  static const String photoInvalidType = 'PHOTO_INVALID_TYPE';
  static const String conflict = 'CONFLICT';
  static const String notFound = 'NOT_FOUND';
  static const String badRequest = 'BAD_REQUEST';
  static const String network = 'NETWORK_UNAVAILABLE';
  static const String timeout = 'NETWORK_TIMEOUT';
  static const String server = 'SERVER_ERROR';
  static const String cancelled = 'REQUEST_CANCELLED';
  static const String parse = 'CLIENT_PARSE_ERROR';
  static const String unknown = 'UNKNOWN_ERROR';
}

/// Normalised client-facing error.
///
/// This is the last line of defence when a request has already failed, so it
/// must never throw. Every read is type-checked rather than cast.
class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.details,
    this.status,
    this.requestId,
    this.debugDetail,
  });

  final String code;
  final String message;

  /// Structured payload, e.g. `{"serverVersion": 4}`. Always a map, never a
  /// String — an earlier version cast this and crashed on the 409 body.
  final Map<String, dynamic>? details;

  final int? status;

  /// Server correlation id, useful when reporting a bug.
  final String? requestId;

  /// Developer-facing cause. Surfaced only in debug builds.
  final String? debugDetail;

  bool get isSessionInvalid =>
      code == ApiErrorCode.authTokenInvalid ||
      code == ApiErrorCode.authSessionRevoked;

  bool get isOffline =>
      code == ApiErrorCode.network || code == ApiErrorCode.timeout;

  bool get isStaleVersion => code == ApiErrorCode.inspectionStaleVersion;
  bool get isIncomplete => code == ApiErrorCode.inspectionIncomplete;
  bool get isValidation => code == ApiErrorCode.validation;

  /// Server version reported alongside a stale-version conflict.
  /// Read for display only — never assigned to local state.
  int? get serverVersion {
    final raw = details?['serverVersion'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Wraps any non-Dio exception so nothing reaches the UI as a bare object.
  factory ApiError.fromException(Object error, [StackTrace? stack]) {
    if (error is ApiError) return error;

    return ApiError(
      code: ApiErrorCode.parse,
      message: kDebugMode
          ? '${error.runtimeType}: $error'
          : 'The app could not read the server response.',
      debugDetail: '$error\n$stack',
    );
  }

  factory ApiError.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiError(
          code: ApiErrorCode.timeout,
          message: 'The connection timed out. Check your signal and retry.',
        );

      case DioExceptionType.connectionError:
        return const ApiError(
          code: ApiErrorCode.network,
          message: 'No connection to the SCI server.',
        );

      case DioExceptionType.cancel:
        return const ApiError(
          code: ApiErrorCode.cancelled,
          message: 'Request cancelled.',
        );

      case DioExceptionType.badCertificate:
        return const ApiError(
          code: ApiErrorCode.network,
          message: 'The server certificate could not be verified.',
        );

      case DioExceptionType.badResponse:
      default:
        // `unknown` covers client-side errors thrown inside an interceptor or
        // a response transformer — including parse failures, which previously
        // surfaced as a bare "Something went wrong".
        if (e.type == DioExceptionType.unknown && e.response == null) {
          return ApiError(
            code: ApiErrorCode.parse,
            message: kDebugMode
                ? '${e.error.runtimeType}: ${e.error}'
                : 'The app could not read the server response.',
            debugDetail: '${e.error}\n${e.stackTrace}',
          );
        }
        return ApiError._fromResponse(e);
    }
  }

  /// Understands three envelopes:
  ///
  ///   SCI domain    : { "error": { code, message, details, requestId } }
  ///   Flat          : { code, message, details }
  ///   NestJS default: { statusCode, message: string | string[], error }
  factory ApiError._fromResponse(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;

    if (body is! Map) {
      return ApiError(
        code: _codeForStatus(status),
        message: _messageForStatus(status),
        status: status,
      );
    }

    final root = Map<String, dynamic>.from(body);

    // Unwrap { "error": {...} } ONLY when it is an object. NestJS also uses a
    // top-level `error` STRING ("Bad Request"); conflating the two is what
    // produced the `_JsonMap is not a subtype of String?` crash.
    final nested = root['error'];
    final scope = nested is Map ? Map<String, dynamic>.from(nested) : root;

    return ApiError(
      code: _readString(scope['code']) ??
          _readString(root['error']) ??
          _codeForStatus(status),
      message: _readMessage(scope, root, status),
      details: _readDetails(scope),
      status: status,
      requestId:
          _readString(scope['requestId']) ?? _readString(root['requestId']),
    );
  }

  static String? _readString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static String _readMessage(
    Map<String, dynamic> scope,
    Map<String, dynamic> root,
    int? status,
  ) {
    for (final candidate in <Object?>[scope['message'], root['message']]) {
      if (candidate is String && candidate.isNotEmpty) return candidate;
      if (candidate is List && candidate.isNotEmpty) {
        return candidate.map((dynamic m) => m.toString()).join('\n');
      }
    }
    return _messageForStatus(status);
  }

  static Map<String, dynamic>? _readDetails(Map<String, dynamic> scope) {
    final raw = scope['details'];
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List) {
      return <String, dynamic>{
        'items': raw.map((dynamic e) => e.toString()).toList(),
      };
    }
    return <String, dynamic>{'value': raw.toString()};
  }

  static String _codeForStatus(int? s) {
    switch (s) {
      case 400:
        return ApiErrorCode.badRequest;
      case 401:
        return ApiErrorCode.authTokenInvalid;
      case 403:
        return ApiErrorCode.authForbidden;
      case 404:
        return ApiErrorCode.notFound;
      case 409:
        return ApiErrorCode.conflict;
      case 413:
        return ApiErrorCode.photoTooLarge;
      case 500:
      case 502:
      case 503:
      case 504:
        return ApiErrorCode.server;
      default:
        return ApiErrorCode.unknown;
    }
  }

  static String _messageForStatus(int? s) {
    switch (s) {
      case 400:
        return 'The information sent was not accepted by the server.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested item could not be found.';
      case 409:
        return 'This item was changed elsewhere. Refresh and try again.';
      case 413:
        return 'That file is too large to upload.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'The SCI server is temporarily unavailable.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => 'ApiError($code, $status): $message'
      '${details == null ? '' : ' details=$details'}';
}
