import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/progress_gauge.dart';
import '../../../core/widgets/sci_widgets.dart';
import '../../auth/application/session_controller.dart';

/// Inspector dashboard shell.
///
/// Phase 1 renders the authenticated chrome and the design system. The
/// counters and recent list are wired to real backend data in Phase 3 —
/// statistics are never fabricated (spec section 55).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            120, // clears the floating bottom navigation
          ),
          children: <Widget>[
            _Greeting(name: user?.firstName ?? 'Inspector',
                initials: user?.initials ?? '?'),
            const SizedBox(height: AppSpacing.lg),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: <Widget>[
                    const ProgressGauge(
                      percentage: 0,
                      label: 'Active inspection',
                      caption: 'No inspection open',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Completion is calculated by the SCI server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            const Text(
              'My inspections',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Counters render em-dash until Phase 3 supplies real backend data.
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.55,
              children: const <Widget>[
                StatCard(
                  label: 'Assigned',
                  value: '—',
                  icon: Icons.inbox_rounded,
                  color: AppColors.statusAssigned,
                ),
                StatCard(
                  label: 'In progress',
                  value: '—',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.statusInProgress,
                ),
                StatCard(
                  label: 'Corrections',
                  value: '—',
                  icon: Icons.report_problem_rounded,
                  color: AppColors.statusCorrection,
                ),
                StatCard(
                  label: 'Submitted',
                  value: '—',
                  icon: Icons.send_rounded,
                  color: AppColors.statusSubmitted,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Recent activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            const AlertTile(
              title: 'Connect the inspections API',
              subtitle: 'Recent inspections appear here in Phase 3.',
              icon: Icons.link_rounded,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.initials});

  final String name;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
