import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sci_widgets.dart';
import '../../payments/application/payment_controller.dart';
import '../application/inspection_providers.dart';
import '../data/inspection_reports_repository.dart';
import '../domain/inspection.dart';
import '../domain/inspection_status.dart';

class InspectionDetailScreenV2 extends ConsumerWidget {
  const InspectionDetailScreenV2({required this.inspectionId, super.key});
  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inspectionWorkspaceProvider(inspectionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Inspection')),
      body: state.when(
        loading: () => const ListSkeleton(itemCount: 4, height: 120),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.invalidate(inspectionWorkspaceProvider(inspectionId)),
        ),
        data: (ws) {
          final i = ws.inspection;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              i.inspectionNumber ?? 'Inspection',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ),
                          StatusBadge(label: i.status.label, color: i.status.color, icon: i.status.icon),
                        ],
                      ),
                      if (i.status.canStart) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        PaymentStatusBadge(inspectionId: inspectionId),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      _kv('Property', i.propertyName),
                      _kv('Property ref', i.propertyReference),
                      _kv('Loan reference', i.loanReference),
                      _kv('Client', i.clientName),
                      _kv('Priority', i.priority.label),
                      if (i.dueDate != null) _kv('Due', DateFormat('d MMM yyyy').format(i.dueDate!)),
                      if (i.submittedAt != null)
                        _kv('Submitted', DateFormat('d MMM yyyy HH:mm').format(i.submittedAt!.toLocal())),
                      if (i.reviewerName != null && i.reviewerName!.isNotEmpty) _kv('Reviewer', i.reviewerName),
                    ],
                  ),
                ),
              ),
              if (i.status.isCorrection) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Corrections requested'),
                for (final c in <InspectionComment>[...i.corrections, ...i.comments])
                  if (c.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AlertTile(
                        title: c.body,
                        subtitle: <String?>[
                          c.author,
                          if (c.createdAt != null) DateFormat('d MMM yyyy').format(c.createdAt!.toLocal()),
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                        icon: Icons.report_problem_outlined,
                        color: AppColors.warning,
                      ),
                    ),
              ],
              const SizedBox(height: 100),
            ],
          );
        },
      ),
      bottomNavigationBar: state.hasValue
          ? _DetailActionsV2(
              inspectionId: inspectionId,
              status: state.requireValue.inspection.status,
            )
          : null,
    );
  }

  Widget _kv(String key, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 120,
              child: Text(key, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(
                value == null || value.trim().isEmpty ? '—' : value,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _DetailActionsV2 extends ConsumerStatefulWidget {
  const _DetailActionsV2({required this.inspectionId, required this.status});
  final String inspectionId;
  final InspectionStatus status;

  @override
  ConsumerState<_DetailActionsV2> createState() => _DetailActionsV2State();
}

class _DetailActionsV2State extends ConsumerState<_DetailActionsV2> {
  bool _busy = false;
  bool _reportBusy = false;

  Future<void> _openPayment() async {
    final paid = await context.push<bool>(Routes.inspectionPayment(widget.inspectionId));
    if ((paid ?? false) && mounted) ref.invalidate(paymentControllerProvider(widget.inspectionId));
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref.read(inspectionWorkspaceProvider(widget.inspectionId).notifier).start();
      if (mounted) context.push(Routes.inspectionWorkspace(widget.inspectionId));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.requiresPayment) {
        await _openPayment();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadFinalReport() async {
    setState(() => _reportBusy = true);
    try {
      final url = await ref.read(inspectionReportsRepositoryProvider).finalReportDownloadUrl(widget.inspectionId);
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the final report.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = ref.watch(inspectionIsPaidProvider(widget.inspectionId));
    final finalReportReady = widget.status == InspectionStatus.approved || widget.status == InspectionStatus.reportGenerated;

    final actions = <Widget>[];
    if (widget.status.canStart && !isPaid) {
      actions.add(FilledButton.icon(
        onPressed: _busy ? null : _openPayment,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Pay RWF 15,000'),
      ));
    } else if (widget.status.canStart) {
      actions.add(FilledButton.icon(
        onPressed: _busy ? null : _start,
        icon: _busy ? const ButtonSpinner() : const Icon(Icons.play_arrow_rounded),
        label: const Text('Start inspection'),
      ));
    } else if (widget.status.isEditable) {
      actions.add(FilledButton.icon(
        onPressed: () => context.push(Routes.inspectionWorkspace(widget.inspectionId)),
        icon: const Icon(Icons.edit_outlined),
        label: Text(widget.status.isCorrection ? 'Open corrections' : 'Continue inspection'),
      ));
    } else {
      actions.add(OutlinedButton.icon(
        onPressed: () => context.push(Routes.inspectionWorkspace(widget.inspectionId)),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('View inspection'),
      ));
    }

    if (finalReportReady) {
      actions.add(
        OutlinedButton.icon(
          onPressed: _reportBusy ? null : _downloadFinalReport,
          icon: _reportBusy ? const ButtonSpinner() : const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Download final report'),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final action in actions) ...<Widget>[action, const SizedBox(height: AppSpacing.xs)],
        ]),
      ),
    );
  }
}
