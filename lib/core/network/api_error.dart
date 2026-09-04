import 'package:dio/dio.dart';

/// Backend domain error codes (spec section 63).
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

  // Client-side codes.
  static const String network = 'NETWORK_UNAVAILABLE';
  static const String timeout = 'NETWORK_TIMEOUT';
  static const String server = 'SERVER_ERROR';
  static const String cancelled = 'REQUEST_CANCELLED';
  static const String unknown = 'UNKNOWN_ERROR';
}

/// Normalised client-facing error. Raw stack traces are never surfaced.
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

  /// True when the session is genuinely invalid and we must sign the user out.
  /// An ordinary network failure must NEVER log the user out (spec section 61).
  bool get isSessionInvalid =>
      code == ApiErrorCode.authTokenInvalid ||
      code == ApiErrorCode.authSessionRevoked;

  bool get isOffline =>
      code == ApiErrorCode.network || code == ApiErrorCode.timeout;

  bool get isStaleVersion => code == ApiErrorCode.inspectionStaleVersion;

  /// Maps a [DioException] into a normalised [ApiError].
  factory ApiError.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiError(
          code: ApiErrorCode.timeout,
          message:
              'The connection timed out. Your work is saved locally and will '
              'sync when the network is available.',
        );
      case DioExceptionType.connectionError:
        return const ApiError(
          code: ApiErrorCode.network,
          message:
              'No connection to the SCI server. You can keep working offline.',
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
      final rawMessage = data['message'];
      if (rawMessage is String) {
        message = rawMessage;
      } else if (rawMessage is List && rawMessage.isNotEmpty) {
        // NestJS class-validator returns message as a string array.
        message = rawMessage.map((dynamic m) => m.toString()).join('\n');
      }
      final rawDetails = data['details'];
      if (rawDetails is Map<String, dynamic>) details = rawDetails;
    }

    code ??= _codeForStatus(status);
    message ??= _messageForStatus(status);

    return ApiError(
      code: code,
      message: message,
      details: details,
      status: status,
    );
  }

  static String _codeForStatus(int? status) {
    switch (status) {
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
      case 500:
      case 502:
      case 503:
      case 504:
        return ApiErrorCode.server;
      default:
        return ApiErrorCode.unknown;
    }
  }

  static String _messageForStatus(int? status) {
    switch (status) {
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
      case 500:
      case 502:
      case 503:
      case 504:
        return 'The SCI server is temporarily unavailable. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => 'ApiError($code, $status): $message';
}
