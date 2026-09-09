import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sci_widgets.dart';
import '../application/payment_controller.dart';
import '../domain/payment.dart';

/// Collects the owner's mobile money number and waits for approval.
///
/// Paypack is a USSD push, not a redirect checkout: there is no hosted page.
/// The inspector enters the owner's number, Paypack prompts that handset, and
/// the owner approves with their MoMo PIN. This screen's job is to make that
/// wait comprehensible.
class InspectionPaymentScreen extends ConsumerStatefulWidget {
  const InspectionPaymentScreen({
    required this.inspectionId,
    this.inspectionNumber,
    super.key,
  });

  final String inspectionId;
  final String? inspectionNumber;

  @override
  ConsumerState<InspectionPaymentScreen> createState() =>
      _InspectionPaymentScreenState();
}

class _InspectionPaymentScreenState
    extends ConsumerState<InspectionPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(paymentControllerProvider(widget.inspectionId).notifier)
        .send(_phone.text);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(paymentControllerProvider(widget.inspectionId));

    // Return to the inspection as soon as payment lands, so the inspector
    // does not have to work out what to do next.
    ref.listen(paymentControllerProvider(widget.inspectionId), (prev, next) {
      final wasPaid = prev?.valueOrNull?.unlocksInspection ?? false;
      final isPaid = next.valueOrNull?.unlocksInspection ?? false;

      if (!wasPaid && isPaid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed. You can start the inspection.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Inspection payment')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateView(
          error: error,
          onRetry: () =>
              ref.invalidate(paymentControllerProvider(widget.inspectionId)),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(PaymentState state) {
    final status = state.status;
    final isWaiting = state.isPolling || status.isSettling;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        _FeeCard(
          amountLabel: state.payment?.amountLabel ?? 'RWF 15,000',
          inspectionNumber: widget.inspectionNumber,
        ),
        const SizedBox(height: AppSpacing.md),
        if (status.unlocksInspection)
          const _PaidCard()
        else if (isWaiting)
          _WaitingCard(
            inspectionId: widget.inspectionId,
            payment: state.payment,
          )
        else
          _NumberForm(
            formKey: _formKey,
            controller: _phone,
            state: state,
            onSubmit: _send,
          ),
        if (state.errorMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          MessageBanner(message: state.errorMessage!),
        ],
        if (status == PaymentStatus.failed &&
            state.payment?.failureReason != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          MessageBanner(
            message: state.payment!.failureReason!,
            color: AppColors.warning,
            icon: Icons.info_outline_rounded,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _HowItWorks(),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.amountLabel, this.inspectionNumber});

  final String amountLabel;
  final String? inspectionNumber;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            const Text(
              'Inspection fee',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              amountLabel,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                height: 1.1,
              ),
            ),
            if (inspectionNumber != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                inspectionNumber!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberForm extends StatelessWidget {
  const _NumberForm({
    required this.formKey,
    required this.controller,
    required this.state,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final PaymentState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                "Owner's mobile money number",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                'A payment request is sent to this number. The owner approves '
                'it on their phone.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SciTextField(
                controller: controller,
                label: 'MOBILE MONEY NUMBER',
                hint: '0788123456',
                icon: Icons.smartphone_rounded,
                keyboardType: TextInputType.phone,
                enabled: !state.isSubmitting,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                validator: MomoNumber.validate,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: state.isSubmitting ? null : onSubmit,
                icon: state.isSubmitting
                    ? const ButtonSpinner()
                    : const Icon(Icons.send_to_mobile_rounded, size: 20),
                label: Text(state.isRetry ? 'Send again' : 'Request payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The waiting state — the longest part of the flow, so it explains itself.
class _WaitingCard extends ConsumerWidget {
  const _WaitingCard({required this.inspectionId, this.payment});

  final String inspectionId;
  final InspectionPayment? payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(paymentControllerProvider(inspectionId).notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            const SizedBox(
              height: 42,
              width: 42,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Waiting for approval',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              payment?.phoneNumber == null
                  ? 'A payment request has been sent.'
                  : 'A request was sent to ${payment!.phoneNumber}.\n'
                      'Ask the owner to approve it on their phone.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            if (payment?.paypackRef != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _RefChip(reference: payment!.paypackRef!),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: notifier.stopWaiting,
                    child: const Text('Stop waiting'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: notifier.refresh,
                    child: const Text('Check now'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'This can take up to a minute.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaidCard extends StatelessWidget {
  const _PaidCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            Icon(Icons.verified_rounded, size: 46, color: AppColors.success),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Payment confirmed',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: AppSpacing.xxs),
            Text(
              'You can now start this inspection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copyable Paypack reference — worth having if an owner disputes a charge.
class _RefChip extends StatelessWidget {
  const _RefChip({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final short = reference.length > 8 ? reference.substring(0, 8) : reference;

    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: reference));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reference copied.')),
        );
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.receipt_long_outlined,
                size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              'Ref $short',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.copy_rounded,
                size: 12, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const List<String> _steps = <String>[
    "Enter the property owner's mobile money number.",
    'They receive a prompt on their phone.',
    'They approve it with their mobile money PIN.',
    'The inspection unlocks once payment is confirmed.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'How this works',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final step in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('•  ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Payment badge for the inspection detail screen.
class PaymentStatusBadge extends ConsumerWidget {
  const PaymentStatusBadge({required this.inspectionId, super.key});

  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(paymentControllerProvider(inspectionId)).valueOrNull;
    if (state == null) return const SizedBox.shrink();

    final status = state.status;

    final (Color color, IconData icon) = switch (status) {
      PaymentStatus.successful => (AppColors.success, Icons.verified_rounded),
      PaymentStatus.processing => (
          AppColors.warning,
          Icons.hourglass_top_rounded
        ),
      PaymentStatus.failed => (AppColors.danger, Icons.error_outline_rounded),
      PaymentStatus.cancelled => (AppColors.offline, Icons.cancel_outlined),
      _ => (AppColors.offline, Icons.payments_outlined),
    };

    return StatusBadge(label: status.label, color: color, icon: icon);
  }
}
