import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_inspector/core/network/api_error.dart';
import 'package:sci_inspector/core/network/paginated.dart';
import 'package:sci_inspector/core/storage/token_store.dart';
import 'package:sci_inspector/core/utils/validators.dart';
import 'package:sci_inspector/features/auth/domain/user.dart';
import 'package:sci_inspector/features/inspections/domain/inspection.dart';
import 'package:sci_inspector/features/inspections/domain/inspection_status.dart';
import 'package:sci_inspector/features/photos/domain/photo.dart';
import 'package:sci_inspector/features/properties/domain/property.dart';
import 'package:sci_inspector/features/templates/domain/template.dart';

void main() {
  RequestOptions opts() => RequestOptions(path: '/x');

  group('ApiError', () {
    test('network failures never invalidate the session', () {
      for (final t in <DioExceptionType>[
        DioExceptionType.connectionError,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionTimeout,
      ]) {
        final e = ApiError.fromDio(
            DioException(requestOptions: opts(), type: t));
        expect(e.isOffline, isTrue);
        expect(e.isSessionInvalid, isFalse,
            reason: '$t must not sign the inspector out');
      }
    });

    test('401 is treated as an invalid session', () {
      final e = ApiError.fromDio(DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
            requestOptions: opts(), statusCode: 401),
      ));
      expect(e.isSessionInvalid, isTrue);
    });

    test('preserves backend domain codes', () {
      final e = ApiError.fromDio(DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: opts(),
          statusCode: 409,
          data: <String, dynamic>{
            'code': ApiErrorCode.inspectionStaleVersion,
            'message': 'Version conflict',
          },
        ),
      ));
      expect(e.isStaleVersion, isTrue);
      expect(e.message, 'Version conflict');
    });

    test('joins NestJS class-validator message arrays', () {
      final e = ApiError.fromDio(DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: opts(),
          statusCode: 400,
          data: <String, dynamic>{
            'message': <String>['email must be an email', 'too short'],
          },
        ),
      ));
      expect(e.message, contains('email must be an email'));
      expect(e.message, contains('too short'));
    });
  });

  group('Permissions', () {
    final user = User.fromJson(<String, dynamic>{
      'id': 'u1',
      'email': 'inspector@sci.rw',
      'firstName': 'Jean',
      'lastName': 'Habimana',
      'organizationId': 'o1',
      'roles': <String>['INSPECTOR'],
      'permissions': <String>[
        Permissions.propertiesWrite,
        Permissions.inspectionsCreate,
      ],
    });

    test('parses the contract', () {
      expect(user.fullName, 'Jean Habimana');
      expect(user.initials, 'JH');
      expect(user.isInspector, isTrue);
    });

    test('never holds reviewer/admin permissions', () {
      for (final p in Permissions.reviewerOnly) {
        expect(user.can(p), isFalse, reason: 'must not hold $p');
      }
    });
  });

  group('InspectionStatus', () {
    test('is editable only in IN_PROGRESS and CORRECTION_REQUESTED', () {
      for (final s in InspectionStatus.values) {
        final editable = s == InspectionStatus.inProgress ||
            s == InspectionStatus.correctionRequested;
        expect(s.isEditable, editable, reason: s.wire);
      }
    });

    test('never renders a raw enum value', () {
      for (final s in InspectionStatus.values) {
        expect(s.label, isNot(contains('_')));
        expect(s.label, isNot(equals(s.wire)));
      }
    });

    test('parses unknown values without throwing', () {
      expect(InspectionStatusX.parse('NOT_A_STATUS'),
          InspectionStatus.unknown);
      expect(InspectionStatusX.parse(null), InspectionStatus.unknown);
    });
  });

  group('CreatePropertyRequest', () {
    CreatePropertyRequest build({String? ref, String? village}) =>
        CreatePropertyRequest(
          reference: ref,
          name: 'Kigali Commercial Building',
          propertyType: PropertyType.commercial,
          ownerClientName: 'John Doe',
          province: 'Kigali',
          district: 'Gasabo',
          sector: 'Kimironko',
          cell: 'Nyagatovu',
          villageStreet: village,
        );

    test('omits blank optionals (forbidNonWhitelisted safety)', () {
      final j = build(ref: '   ', village: '').toJson();
      expect(j.containsKey('reference'), isFalse);
      expect(j.containsKey('villageStreet'), isFalse);
    });

    test('sends exactly the documented required keys', () {
      expect(build().toJson().keys.toSet(), <String>{
        'name', 'propertyType', 'ownerClientName',
        'province', 'district', 'sector', 'cell',
      });
    });

    test('never sends legacy fields', () {
      final j = build(ref: 'PROP-2026-0001').toJson();
      for (final f in <String>[
        'plotNumber', 'titleNumber', 'latitude', 'longitude', 'addressLine',
      ]) {
        expect(j.containsKey(f), isFalse, reason: '$f must not be sent');
      }
    });
  });

  group('InspectionValue', () {
    TemplateField field(FieldType t) => TemplateField(
          id: 'f1',
          code: 'C',
          label: 'L',
          type: t,
          required: false,
          sortOrder: 0,
        );

    test('serialises exactly one typed key per field type', () {
      expect(
        InspectionValue.forField(field(FieldType.number), '450.5').toJson(),
        <String, dynamic>{'fieldId': 'f1', 'valueNumber': 450.5},
      );
      expect(
        InspectionValue.forField(field(FieldType.boolean), true).toJson(),
        <String, dynamic>{'fieldId': 'f1', 'valueBool': true},
      );
      expect(
        InspectionValue.forField(
                field(FieldType.multiSelect), <String>['A', 'B'])
            .toJson(),
        <String, dynamic>{
          'fieldId': 'f1',
          'valueJson': <String>['A', 'B'],
        },
      );
      expect(
        InspectionValue.forField(field(FieldType.select), 'Commercial')
            .toJson(),
        <String, dynamic>{'fieldId': 'f1', 'valueText': 'Commercial'},
      );
    });

    test('currency maps to valueNumber, not valueText', () {
      final j =
          InspectionValue.forField(field(FieldType.currency), '150000').toJson();
      expect(j['valueNumber'], 150000);
      expect(j.containsKey('valueText'), isFalse);
    });
  });

  group('Valuation', () {
    test('defaults to RWF, never RF', () {
      expect(const InspectionValuation().toJson()['currency'], 'RWF');
    });
  });

  group('FieldType / PhotoCategory forward compatibility', () {
    test('unknown field type degrades instead of throwing', () {
      expect(FieldType.parse('SOME_NEW_TYPE'), FieldType.unknown);
    });
    test('unknown photo category falls back to OTHER', () {
      expect(PhotoCategory.parse('NEW_ANGLE'), PhotoCategory.other);
    });
  });

  group('Paginated', () {
    test('reads items/data/results envelopes', () {
      for (final key in <String>['items', 'data', 'results']) {
        final p = Paginated.fromJson<Property>(
          <String, dynamic>{
            key: <dynamic>[
              <String, dynamic>{'id': '1', 'name': 'A'},
            ],
            'page': 1,
            'limit': 1,
            'total': 3,
          },
          Property.fromJson,
        );
        expect(p.items, hasLength(1), reason: key);
        expect(p.hasMore, isTrue, reason: key);
      }
    });

    test('supports nested meta and degrades on unknown shapes', () {
      final nested = Paginated.fromJson<Property>(
        <String, dynamic>{
          'data': <dynamic>[],
          'meta': <String, dynamic>{'page': 2, 'limit': 20, 'total': 40},
        },
        Property.fromJson,
      );
      expect(nested.page, 2);

      final unknown = Paginated.fromJson<Property>(
          <String, dynamic>{'weird': 1}, Property.fromJson);
      expect(unknown.items, isEmpty);
      expect(unknown.hasMore, isFalse);
    });
  });

  group('Security helpers', () {
    test('masks all but the last four digits of a national ID', () {
      expect(maskNationalId('1199812345678901'), endsWith('8901'));
      expect(maskNationalId('1199812345678901'), startsWith('•'));
      expect(maskNationalId(null), '—');
    });
  });

  group('Tokens', () {
    test('detects expiry and near-expiry', () {
      final almost = AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().add(const Duration(seconds: 10)),
      );
      expect(almost.isExpired, isFalse);
      expect(almost.isNearlyExpired, isTrue);
    });

    test('in-memory store round-trips and clears', () async {
      final s = InMemoryTokenStore();
      await s.write(AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      expect((await s.read())?.accessToken, 'a');
      await s.clear();
      expect(await s.read(), isNull);
    });
  });

  group('Evidence file', () {
    test('flags files against the 15 MB server limit', () {
      final small = EvidenceFile(
        bytes: Uint8List(1024),
        filename: 'a.jpg',
        mimeType: 'image/jpeg',
      );
      expect(small.exceedsLimit, isFalse);

      final tooBig = EvidenceFile(
        bytes: Uint8List(EvidenceFile.maxBytes + 1),
        filename: 'b.jpg',
        mimeType: 'image/jpeg',
      );
      expect(tooBig.exceedsLimit, isTrue);
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email('a@b.rw'), isNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });
    test('password minimum length', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough1'), isNull);
    });
  });
}
