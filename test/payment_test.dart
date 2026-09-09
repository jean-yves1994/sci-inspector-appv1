import 'package:flutter_test/flutter_test.dart';
import 'package:sci_inspector/features/payments/domain/payment.dart';

void main() {
  group('PaymentStatus — the gate', () {
    test('ONLY successful unlocks the inspection', () {
      for (final s in PaymentStatus.values) {
        expect(
          s.unlocksInspection,
          s == PaymentStatus.successful,
          reason: '${s.wire} must not unlock the inspection',
        );
      }
    });

    test('an unrecognised status fails closed', () {
      // If the backend adds a status we do not know, the app must not
      // accidentally treat it as paid.
      expect(PaymentStatus.parse('SOMETHING_NEW'), PaymentStatus.unknown);
      expect(PaymentStatus.parse(null), PaymentStatus.unknown);
      expect(PaymentStatus.unknown.unlocksInspection, isFalse);
    });

    test('only PROCESSING keeps the poller running', () {
      expect(PaymentStatus.processing.isSettling, isTrue);
      for (final s in PaymentStatus.values) {
        if (s != PaymentStatus.processing) {
          expect(s.isSettling, isFalse, reason: s.wire);
        }
      }
    });

    test('failed and cancelled can retry; successful and processing cannot',
        () {
      expect(PaymentStatus.failed.canRetry, isTrue);
      expect(PaymentStatus.cancelled.canRetry, isTrue);
      expect(PaymentStatus.pending.canRetry, isTrue);
      expect(PaymentStatus.successful.canRetry, isFalse);
      expect(PaymentStatus.processing.canRetry, isFalse);
    });

    test('never renders a raw enum value', () {
      for (final s in PaymentStatus.values) {
        expect(s.label, isNot(contains('_')));
        expect(s.label, isNot(equals(s.wire)));
      }
    });
  });

  group('InspectionPayment.fromJson', () {
    test('accepts amount as a STRING, as Prisma Decimal sends it', () {
      final p = InspectionPayment.fromJson(<String, dynamic>{
        'id': 'pay-1',
        'inspectionId': 'insp-1',
        'status': 'SUCCESSFUL',
        'amount': '15000',
      });

      expect(p.amount, 15000);
      expect(p.unlocksInspection, isTrue);
    });

    test('accepts amount as a number too', () {
      final p = InspectionPayment.fromJson(<String, dynamic>{
        'id': 'pay-1',
        'inspectionId': 'insp-1',
        'status': 'PENDING',
        'amount': 15000,
      });
      expect(p.amount, 15000);
    });

    test('formats the amount with thousands separators', () {
      InspectionPayment build(Object amount) =>
          InspectionPayment.fromJson(<String, dynamic>{
            'id': 'p',
            'inspectionId': 'i',
            'status': 'PENDING',
            'amount': amount,
          });

      expect(build('15000').amountLabel, 'RWF 15,000');
      expect(build('500').amountLabel, 'RWF 500');
      expect(build('1250000').amountLabel, 'RWF 1,250,000');
    });

    test('tolerates a minimal payload without throwing', () {
      final p = InspectionPayment.fromJson(<String, dynamic>{'id': 'p'});
      expect(p.status, PaymentStatus.unknown);
      expect(p.unlocksInspection, isFalse);
      expect(p.amount, 0);
    });
  });

  group('MomoNumber', () {
    test('accepts valid numbers across both networks', () {
      for (final n in <String>[
        '0788123456', // MTN
        '0790123456', // MTN
        '0722123456', // Airtel
        '0733123456', // Airtel
      ]) {
        expect(MomoNumber.tryParse(n)?.normalised, n, reason: n);
      }
    });

    test('normalises international formats to the local form', () {
      expect(MomoNumber.tryParse('+250788123456')?.normalised, '0788123456');
      expect(MomoNumber.tryParse('250788123456')?.normalised, '0788123456');
    });

    test('tolerates spaces, dashes and brackets', () {
      // Inspectors type these from memory while standing at a property.
      expect(MomoNumber.tryParse('078 812 3456')?.normalised, '0788123456');
      expect(MomoNumber.tryParse('078-812-3456')?.normalised, '0788123456');
      expect(MomoNumber.tryParse(' 0788123456 ')?.normalised, '0788123456');
    });

    test('rejects malformed numbers', () {
      for (final n in <String>[
        '078812345', // too short
        '07881234567', // too long
        '0688123456', // landline prefix
        '0700123456', // not an allocated mobile prefix
        'abcdefghij',
        '',
      ]) {
        expect(MomoNumber.tryParse(n), isNull, reason: n);
      }
    });

    test('validate returns a message only when invalid', () {
      expect(MomoNumber.validate('0788123456'), isNull);
      expect(MomoNumber.validate(''), contains('required'));
      expect(MomoNumber.validate('123'), contains('valid'));
    });
  });
}
