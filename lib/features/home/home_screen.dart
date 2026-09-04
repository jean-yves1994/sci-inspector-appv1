import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_widgets.dart';
import '../auth/application/session_controller.dart';
import '../inspections/application/inspection_providers.dart';
import '../inspections/domain/inspection_status.dart';
import '../inspections/presentation/inspection_screens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final counts = ref.watch(inspectionCountsProvider);
    final recent = ref.watch(inspectionListProvider);

    // Counters come from real backend totals; never fabricated.
    String countFor(InspectionStatus s) =>
        counts.valueOrNull?[s]?.toString() ?? '—';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(inspectionCountsProvider);
            ref.invalidate(inspectionListProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
            children: <Widget>[
              Row(
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
                          user?.firstName ?? 'Inspector',
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
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('My inspections',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.5,
                children: <Widget>[
                  StatCard(
                    label: 'Assigned',
                    value: countFor(InspectionStatus.assigned),
                    icon: Icons.inbox_rounded,
                    color: AppColors.offline,
                    onTap: () {
                      ref.read(inspectionFilterProvider.notifier).state =
                          InspectionStatus.assigned;
                      context.go(Routes.inspections);
                    },
                  ),
                  StatCard(
                    label: 'In progress',
                    value: countFor(InspectionStatus.inProgress),
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.primary,
                    onTap: () {
                      ref.read(inspectionFilterProvider.notifier).state =
                          InspectionStatus.inProgress;
                      context.go(Routes.inspections);
                    },
                  ),
                  StatCard(
                    label: 'Corrections',
                    value: countFor(InspectionStatus.correctionRequested),
                    icon: Icons.report_problem_rounded,
                    color: AppColors.warning,
                    onTap: () {
                      ref.read(inspectionFilterProvider.notifier).state =
                          InspectionStatus.correctionRequested;
                      context.go(Routes.inspections);
                    },
                  ),
                  StatCard(
                    label: 'Submitted',
                    value: countFor(InspectionStatus.submitted),
                    icon: Icons.send_rounded,
                    color: AppColors.teal,
                    onTap: () {
                      ref.read(inspectionFilterProvider.notifier).state =
                          InspectionStatus.submitted;
                      context.go(Routes.inspections);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(Routes.propertyNew),
                      icon: const Icon(Icons.add_home_work_outlined, size: 18),
                      label: const Text('New property'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Recent inspections',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              recent.when(
                loading: () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => ErrorStateView(
                  error: e,
                  onRetry: () => ref.invalidate(inspectionListProvider),
                ),
                data: (state) => state.items.isEmpty
                    ? const EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No inspections assigned',
                        message:
                            'You currently have no inspections assigned to '
                            'you.',
                      )
                    : Column(
                        children: <Widget>[
                          for (final item in state.items.take(5))
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: InspectionCard(item: item),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
