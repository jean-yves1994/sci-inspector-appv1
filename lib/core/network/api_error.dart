import 'package:dio/dio.dart';

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
  static const String photoTooLarge = 'PHOTO_TOO_LARGE';
  static const String photoInvalidType = 'PHOTO_INVALID_TYPE';
  static const String conflict = 'CONFLICT';
  static const String notFound = 'NOT_FOUND';
  static const String badRequest = 'BAD_REQUEST';
  static const String network = 'NETWORK_UNAVAILABLE';
  static const String timeout = 'NETWORK_TIMEOUT';
  static const String server = 'SERVER_ERROR';
  static const String cancelled = 'REQUEST_CANCELLED';
  static const String unknown = 'UNKNOWN_ERROR';
}

class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.details,
    this.status,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final int? status;

  /// Only these mean the session is genuinely dead. A timeout never is.
  bool get isSessionInvalid =>
      code == ApiErrorCode.authTokenInvalid ||
      code == ApiErrorCode.authSessionRevoked;

  bool get isOffline =>
      code == ApiErrorCode.network || code == ApiErrorCode.timeout;

  bool get isStaleVersion => code == ApiErrorCode.inspectionStaleVersion;
  bool get isIncomplete => code == ApiErrorCode.inspectionIncomplete;

  factory ApiError.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiError(
          code: ApiErrorCode.timeout,
          message: 'The connection timed out. Your work is saved on this '
              'device and will sync when the network returns.',
        );
      case DioExceptionType.connectionError:
        return const ApiError(
          code: ApiErrorCode.network,
          message: 'No connection to the SCI server. You can keep working.',
        );
      case DioExceptionType.cancel:
        return const ApiError(
            code: ApiErrorCode.cancelled, message: 'Request cancelled.');
      case DioExceptionType.badCertificate:
        return const ApiError(
            code: ApiErrorCode.network,
            message: 'The server certificate could not be verified.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return ApiError._fromResponse(e);
    }
  }

  factory ApiError._fromResponse(DioException e) {
    final response = e.response;
    final status = response?.statusCode;
    final data = response?.data;
    String? code;
    String? message;
    Map<String, dynamic>? details;

    if (data is Map<String, dynamic>) {
      code = data['code'] as String? ?? data['error'] as String?;
      final raw = data['message'];
      if (raw is String) {
        message = raw;
      } else if (raw is List && raw.isNotEmpty) {
        // NestJS class-validator returns string[].
        message = raw.map((dynamic m) => m.toString()).join('\n');
      }
      if (data['details'] is Map<String, dynamic>) {
        details = data['details'] as Map<String, dynamic>;
      }
    }

    return ApiError(
      code: code ?? _codeForStatus(status),
      message: message ?? _messageForStatus(status),
      details: details,
      status: status,
    );
  }

  static String _codeForStatus(int? s) => switch (s) {
        400 => ApiErrorCode.badRequest,
        401 => ApiErrorCode.authTokenInvalid,
        403 => ApiErrorCode.authForbidden,
        404 => ApiErrorCode.notFound,
        409 => ApiErrorCode.conflict,
        413 => ApiErrorCode.photoTooLarge,
        500 || 502 || 503 || 504 => ApiErrorCode.server,
        _ => ApiErrorCode.unknown,
      };

  static String _messageForStatus(int? s) => switch (s) {
        400 => 'The information sent was not accepted by the server.',
        401 => 'Your session has expired. Please sign in again.',
        403 => 'You do not have permission to perform this action.',
        404 => 'The requested item could not be found.',
        409 => 'This item was changed elsewhere. Refresh and try again.',
        413 => 'That file is too large to upload.',
        500 || 502 || 503 || 504 =>
          'The SCI server is temporarily unavailable. Please try again.',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'ApiError($code, $status): $message';
}
