import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/inspection_providers.dart';

/// Shows a save failure with a retry action.
///
/// Replaces the old stale-version banner, whose only button called `reload()`
/// — an alias for `discardAndReload()`, which cleared every unsaved edit. The
/// inspector was offered one action and it deleted their work.
///
/// Renders nothing when there is no error.
class SaveStatusBar extends ConsumerWidget {
  const SaveStatusBar({required this.inspectionId, super.key});

  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(inspectionWorkspaceProvider(inspectionId)).valueOrNull;

    final message = state?.errorMessage;
    if (state == null || message == null) return const SizedBox.shrink();

    final notifier =
        ref.read(inspectionWorkspaceProvider(inspectionId).notifier);
    final pending = state.pendingEdits;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.sync_problem_rounded,
                  size: 20, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Not saved',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (pending > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          '$pending change(s) still on this device',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => _confirmDiscard(context, notifier, pending),
                child: Text(
                  pending > 0 ? 'Discard my changes' : 'Reload',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton(
                onPressed: notifier.retry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    InspectionWorkspaceNotifier notifier,
    int pending,
  ) async {
    if (pending == 0) {
      await notifier.discardAndReload();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard your changes?'),
        content: Text(
          '$pending unsaved change(s) will be permanently lost and the '
          'inspection reloaded from the server.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await notifier.discardAndReload();
  }
}
