import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/payments_repository.dart';
import '../domain/payment.dart';

/// Payment state for one inspection.
///
/// Paypack is asynchronous: `cashin` returns `pending`, the owner approves on
/// their handset, and the outcome reaches our backend by webhook. So this
/// controller polls while a payment is settling and stops the moment the
/// server reports something terminal.
class PaymentState {
  const PaymentState({
    this.payment,
    this.isSubmitting = false,
    this.isPolling = false,
    this.errorMessage,
    this.elapsed = Duration.zero,
  });

  /// Null when no payment has been started for this inspection.
  final InspectionPayment? payment;

  final bool isSubmitting;
  final bool isPolling;
  final String? errorMessage;

  /// How long we have been waiting for the owner to approve.
  final Duration elapsed;

  PaymentStatus get status => payment?.status ?? PaymentStatus.pending;

  bool get unlocksInspection => payment?.unlocksInspection ?? false;

  /// True when a previous attempt exists and can be retried.
  bool get isRetry => payment != null && status.canRetry;

  PaymentState copyWith({
    InspectionPayment? payment,
    bool? isSubmitting,
    bool? isPolling,
    String? errorMessage,
    Duration? elapsed,
    bool clearError = false,
  }) =>
      PaymentState(
        payment: payment ?? this.payment,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isPolling: isPolling ?? this.isPolling,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        elapsed: elapsed ?? this.elapsed,
      );
}

class PaymentController
    extends AutoDisposeFamilyAsyncNotifier<PaymentState, String> {
  Timer? _poll;

  /// How often to ask whether the webhook has landed.
  static const Duration _pollInterval = Duration(seconds: 3);

  /// After this, stop and offer a retry. The USSD prompt itself expires well
  /// before this on most networks, so continuing to poll would just spin.
  static const Duration _pollTimeout = Duration(minutes: 3);

  @override
  Future<PaymentState> build(String inspectionId) async {
    ref.onDispose(_stopPolling);

    final payment =
        await ref.read(paymentsRepositoryProvider).byInspection(inspectionId);

    // Resume polling if we return to a payment that is still settling — for
    // instance the inspector backgrounded the app mid-approval.
    if (payment?.status.isSettling ?? false) {
      Future<void>.microtask(_startPolling);
    }

    return PaymentState(payment: payment);
  }

  PaymentState get _s => state.requireValue;

  // ------------------------------------------------------------ polling

  void _startPolling() {
    _poll?.cancel();
    if (!state.hasValue) return;

    state = AsyncData(_s.copyWith(isPolling: true, elapsed: Duration.zero));

    _poll = Timer.periodic(_pollInterval, (timer) async {
      if (!state.hasValue) {
        timer.cancel();
        return;
      }

      final elapsed = _s.elapsed + _pollInterval;

      if (elapsed >= _pollTimeout) {
        _stopPolling();
        state = AsyncData(_s.copyWith(
          isPolling: false,
          errorMessage: 'The request timed out. Ask the owner to check their '
              'phone, then send it again.',
        ));
        return;
      }

      try {
        final fresh =
            await ref.read(paymentsRepositoryProvider).byInspection(arg);

        if (!state.hasValue) return;
        state = AsyncData(_s.copyWith(payment: fresh, elapsed: elapsed));

        if (fresh != null && !fresh.status.isSettling) {
          _stopPolling();
          state = AsyncData(_s.copyWith(isPolling: false));
        }
      } on ApiError {
        // One failed poll is not fatal — the next tick retries. Only a
        // sustained failure reaches the timeout above.
        if (state.hasValue) {
          state = AsyncData(_s.copyWith(elapsed: elapsed));
        }
      }
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  // ----------------------------------------------------------- actions

  /// Sends the USSD prompt. Uses the retry endpoint when a previous attempt
  /// exists, so the backend can distinguish a replay from a new attempt.
  Future<void> send(String phoneNumber) async {
    if (!state.hasValue) return;

    final number = MomoNumber.tryParse(phoneNumber);
    if (number == null) {
      state = AsyncData(
        _s.copyWith(errorMessage: 'Enter a valid mobile money number.'),
      );
      return;
    }

    final isRetry = _s.isRetry;
    state = AsyncData(_s.copyWith(isSubmitting: true, clearError: true));

    try {
      final repo = ref.read(paymentsRepositoryProvider);
      final payment = isRetry
          ? await repo.retry(
              inspectionId: arg, phoneNumber: number.normalised)
          : await repo.initiate(
              inspectionId: arg, phoneNumber: number.normalised);

      state = AsyncData(_s.copyWith(payment: payment, isSubmitting: false));

      if (payment.status.isSettling) _startPolling();
    } on ApiError catch (e) {
      state = AsyncData(
        _s.copyWith(isSubmitting: false, errorMessage: e.message),
      );
    }
  }

  /// Manual check, for when the inspector believes the owner has approved.
  Future<void> refresh() async {
    if (!state.hasValue) return;

    try {
      final fresh =
          await ref.read(paymentsRepositoryProvider).byInspection(arg);
      state = AsyncData(_s.copyWith(payment: fresh, clearError: true));

      if (fresh != null && !fresh.status.isSettling) {
        _stopPolling();
        state = AsyncData(_s.copyWith(isPolling: false));
      }
    } on ApiError catch (e) {
      state = AsyncData(_s.copyWith(errorMessage: e.message));
    }
  }

  /// Stops waiting locally.
  ///
  /// Deliberately does NOT cancel the Paypack transaction: if the owner
  /// approves a minute later the webhook still lands and the payment
  /// succeeds. Cancelling locally while the charge went through would be the
  /// worst outcome for the owner.
  void stopWaiting() {
    _stopPolling();
    if (state.hasValue) {
      state = AsyncData(_s.copyWith(isPolling: false));
    }
  }
}

final paymentControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PaymentController, PaymentState, String>(PaymentController.new);

/// Whether this inspection may be started.
///
/// The app hiding the Start button is a courtesy; `evaluateTransition`
/// server-side is the actual enforcement. Returns false while loading, so the
/// gate fails closed.
final inspectionIsPaidProvider =
    Provider.autoDispose.family<bool, String>((ref, inspectionId) {
  return ref
          .watch(paymentControllerProvider(inspectionId))
          .valueOrNull
          ?.unlocksInspection ??
      false;
});
