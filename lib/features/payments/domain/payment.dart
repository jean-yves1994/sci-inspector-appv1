import '../../../core/utils/json_read.dart';

/// Lifecycle of an inspection payment.
///
/// Mirrors the backend enum. The client never advances this itself — only the
/// server does, and only on webhook confirmation or a `find` reconciliation.
enum PaymentStatus {
  /// A record exists but no Paypack request has been sent.
  pending('PENDING', 'Not paid'),

  /// Cashin sent; the owner's handset is showing a USSD prompt.
  processing('PROCESSING', 'Awaiting approval'),

  /// Paypack confirmed the funds moved. Only this unlocks Start.
  successful('SUCCESSFUL', 'Paid'),

  /// Declined, insufficient funds, wrong PIN, or expired.
  failed('FAILED', 'Payment failed'),

  /// The owner dismissed the prompt.
  cancelled('CANCELLED', 'Cancelled'),

  /// Defensive: an unrecognised value must not crash the screen, and must
  /// not unlock anything.
  unknown('UNKNOWN', 'Unknown');

  const PaymentStatus(this.wire, this.label);

  final String wire;
  final String label;

  /// The single gate. Everything in the UI derives from this.
  bool get unlocksInspection => this == PaymentStatus.successful;

  /// True while the poller should keep running.
  bool get isSettling => this == PaymentStatus.processing;

  /// True when the inspector can send a fresh request.
  bool get canRetry =>
      this == PaymentStatus.failed ||
      this == PaymentStatus.cancelled ||
      this == PaymentStatus.pending;

  static PaymentStatus parse(String? v) {
    if (v == null) return PaymentStatus.unknown;
    for (final s in PaymentStatus.values) {
      if (s.wire == v.toUpperCase()) return s;
    }
    return PaymentStatus.unknown;
  }
}

/// A payment attached to one inspection.
///
/// One payment per inspection: re-inspecting the same property later creates
/// a new inspection, which needs its own payment.
class InspectionPayment {
  const InspectionPayment({
    required this.id,
    required this.inspectionId,
    required this.status,
    required this.amount,
    this.currency = 'RWF',
    this.phoneNumber,
    this.paypackRef,
    this.failureReason,
    this.attempts = 0,
    this.confirmedAt,
    this.createdAt,
  });

  final String id;
  final String inspectionId;
  final PaymentStatus status;

  /// Prisma Decimal — arrives as a JSON string ("15000"), so it is read
  /// through [J.asDouble] rather than cast.
  final double amount;
  final String currency;

  /// The mobile money number the request was pushed to.
  final String? phoneNumber;

  /// Paypack's transaction reference, for support enquiries.
  final String? paypackRef;

  final String? failureReason;
  final int attempts;
  final DateTime? confirmedAt;
  final DateTime? createdAt;

  bool get unlocksInspection => status.unlocksInspection;

  /// "RWF 15,000"
  String get amountLabel {
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '$currency $buffer';
  }

  factory InspectionPayment.fromJson(Map<String, dynamic> j) =>
      InspectionPayment(
        id: J.asString(j['id']) ?? '',
        inspectionId: J.asString(j['inspectionId']) ?? '',
        status: PaymentStatus.parse(J.asString(j['status'])),
        amount: J.asDouble(j['amount']) ?? 0,
        currency: J.asString(j['currency']) ?? 'RWF',
        phoneNumber: J.asString(j['phoneNumber']),
        paypackRef: J.asString(j['paypackRef']),
        failureReason: J.asString(j['failureReason']),
        attempts: J.asInt(j['attempts']) ?? 0,
        confirmedAt: J.asDate(j['confirmedAt']),
        createdAt: J.asDate(j['createdAt']),
      );
}

/// Rwandan mobile money number handling.
///
/// Accepts 07XXXXXXXX and +2507XXXXXXXX, normalising to the local form
/// Paypack expects. Deliberately tolerant of spaces and dashes — inspectors
/// type these from memory while standing at a property.
class MomoNumber {
  const MomoNumber._(this.normalised);

  final String normalised;

  /// 072/073 Airtel, 078/079 MTN.
  static final RegExp _local = RegExp(r'^07[2389]\d{7}$');

  static MomoNumber? tryParse(String? raw) {
    var s = (raw ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.isEmpty) return null;

    if (s.startsWith('+250')) s = '0${s.substring(4)}';
    if (s.startsWith('250')) s = '0${s.substring(3)}';

    return _local.hasMatch(s) ? MomoNumber._(s) : null;
  }

  /// Validator message, or null when valid.
  static String? validate(String? raw) {
    if ((raw ?? '').trim().isEmpty) return 'Mobile money number is required';
    return tryParse(raw) == null
        ? 'Enter a valid number, e.g. 0788123456'
        : null;
  }

  @override
  String toString() => normalised;
}
