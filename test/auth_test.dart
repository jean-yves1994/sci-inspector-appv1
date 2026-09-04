import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_inspector/core/network/api_error.dart';
import 'package:sci_inspector/core/storage/token_store.dart';
import 'package:sci_inspector/features/auth/domain/user.dart';

void main() {
  group('ApiError mapping', () {
    RequestOptions options() => RequestOptions(path: '/auth/login');

    test('maps connection errors to an offline-safe error', () {
      final error = ApiError.fromDio(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(error.code, ApiErrorCode.network);
      expect(error.isOffline, isTrue);
      // A network failure must never be treated as an invalid session.
      expect(error.isSessionInvalid, isFalse);
    });

    test('maps timeouts without invalidating the session', () {
      final error = ApiError.fromDio(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(error.code, ApiErrorCode.timeout);
      expect(error.isSessionInvalid, isFalse);
    });

    test('preserves backend domain error codes', () {
      final error = ApiError.fromDio(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options(),
            statusCode: 409,
            data: <String, dynamic>{
              'code': ApiErrorCode.inspectionStaleVersion,
              'message': 'Version conflict',
            },
          ),
        ),
      );

      expect(error.code, ApiErrorCode.inspectionStaleVersion);
      expect(error.isStaleVersion, isTrue);
      expect(error.message, 'Version conflict');
    });

    test('joins NestJS class-validator message arrays', () {
      final error = ApiError.fromDio(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options(),
            statusCode: 400,
            data: <String, dynamic>{
              'message': <String>['email must be an email', 'password too short'],
            },
          ),
        ),
      );

      expect(error.code, ApiErrorCode.badRequest);
      expect(error.message, contains('email must be an email'));
      expect(error.message, contains('password too short'));
    });

    test('401 maps to an invalid-session error', () {
      final error = ApiError.fromDio(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options(),
            statusCode: 401,
          ),
        ),
      );

      expect(error.isSessionInvalid, isTrue);
    });
  });

  group('AuthTokens', () {
    test('detects expiry and near-expiry', () {
      final expired = AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(expired.isExpired, isTrue);

      final almost = AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().add(const Duration(seconds: 10)),
      );
      expect(almost.isExpired, isFalse);
      expect(almost.isNearlyExpired, isTrue);
    });
  });

  group('User / permissions', () {
    final user = User.fromJson(<String, dynamic>{
      'id': 'u1',
      'email': 'inspector@sci.rw',
      'firstName': 'Jean',
      'lastName': 'Habimana',
      'organizationId': 'org1',
      'branchId': 'b1',
      'mustChangePassword': false,
      'roles': <String>['INSPECTOR'],
      'permissions': <String>[
        Permissions.propertiesWrite,
        Permissions.inspectionsCreate,
        Permissions.templatesRead,
      ],
    });

    test('parses the backend contract', () {
      expect(user.fullName, 'Jean Habimana');
      expect(user.initials, 'JH');
      expect(user.isInspector, isTrue);
    });

    test('grants inspector permissions', () {
      expect(user.can(Permissions.propertiesWrite), isTrue);
      expect(user.can(Permissions.inspectionsCreate), isTrue);
    });

    test('never grants reviewer/admin permissions', () {
      for (final permission in Permissions.reviewerOnly) {
        expect(
          user.can(permission),
          isFalse,
          reason: 'Inspector must not hold $permission',
        );
      }
    });
  });

  group('InMemoryTokenStore', () {
    test('writes, reads and clears', () async {
      final store = InMemoryTokenStore();
      expect(await store.read(), isNull);

      await store.write(
        AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      expect((await store.read())?.accessToken, 'a');

      await store.clear();
      expect(await store.read(), isNull);
    });
  });
}
