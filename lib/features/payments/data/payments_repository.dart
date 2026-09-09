import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/paginated.dart';
import '../domain/payment.dart';

class PaymentsRepository {
  const PaymentsRepository(this._api);

  final ApiClient _api;

  /// GET /inspections/:id/payment
  ///
  /// Returns null when no fee has been requested. A 404 here is a normal
  /// state — "not paid yet" — not an error worth surfacing.
  Future<InspectionPayment?> byInspection(String inspectionId) async {
    try {
      final d = await _api
          .get<Map<String, dynamic>>('/inspections/$inspectionId/payment');
      return InspectionPayment.fromJson(unwrap(d));
    } on ApiError catch (e) {
      if (e.status == 404 || e.code == ApiErrorCode.notFound) return null;
      rethrow;
    }
  }

  /// POST /inspections/:id/payment
  ///
  /// Triggers a Paypack cashin, which pushes a USSD prompt to [phoneNumber].
  /// Returns with PROCESSING — Paypack's own response is always `pending`,
  /// and the real outcome arrives at the backend by webhook.
  ///
  /// The idempotency key is generated SERVER-SIDE, not here. `RequestFeeDto`
  /// declares only `phoneNumber`, and the API runs
  /// `forbidNonWhitelisted: true`, so any extra property is rejected outright
  /// with "property idempotencyKey should not exist".
  Future<InspectionPayment> initiate({
    required String inspectionId,
    required String phoneNumber,
  }) async {
    final d = await _api.post<Map<String, dynamic>>(
      '/inspections/$inspectionId/payment',
      body: <String, dynamic>{'phoneNumber': phoneNumber},
    );
    return InspectionPayment.fromJson(unwrap(d));
  }

  /// POST /inspections/:id/payment/retry
  ///
  /// A genuinely new attempt after a failure. The backend issues a fresh
  /// idempotency key for it, so a retry is never mistaken for a replay of the
  /// first request.
  Future<InspectionPayment> retry({
    required String inspectionId,
    required String phoneNumber,
  }) async {
    final d = await _api.post<Map<String, dynamic>>(
      '/inspections/$inspectionId/payment/retry',
      body: <String, dynamic>{'phoneNumber': phoneNumber},
    );
    return InspectionPayment.fromJson(unwrap(d));
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(apiClientProvider)),
);
