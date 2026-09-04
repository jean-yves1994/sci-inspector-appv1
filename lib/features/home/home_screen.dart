import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_widgets.dart';
import '../auth/application/session_controller.dart';
import '../inspections/application/dashboard_provider.dart';
import '../inspections/application/inspection_providers.dart';
import '../inspections/domain/inspection_status.dart';
import '../inspections/presentation/inspection_screens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              120,
            ),
            children: <Widget>[
              _Greeting(
                name: user?.firstName ?? 'Inspector',
                initials: user?.initials ?? '?',
              ),
              const SizedBox(height: AppSpacing.lg),

              const Text(
                'My inspections',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),

              dashboard.when(
                loading: () => const _CountersSkeleton(),

                // A failed dashboard must not blank the screen. Show what the
                // server actually said, so the cause is visible rather than
                // buried in the browser console.
                error: (error, _) => _CountersError(
                  error: error,
                  onRetry: () => ref.invalidate(dashboardProvider),
                ),

                data: (data) => _Counters(data: data),
              ),

              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => context.push(Routes.propertyNew),
                icon: const Icon(Icons.add_home_work_outlined, size: 18),
                label: const Text('New property'),
              ),

              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Recent inspections',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),

              dashboard.when(
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) => data.recent.isEmpty
                    ? const EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No inspections assigned',
                        message:
                            'You currently have no inspections assigned to '
                            'you.',
                      )
                    : Column(
                        children: <Widget>[
                          for (final item in data.recent)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
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

class _Counters extends ConsumerWidget {
  const _Counters({required this.data});

  final DashboardData data;

  void _openFiltered(
    BuildContext context,
    WidgetRef ref,
    InspectionStatus status,
  ) {
    ref.read(inspectionFilterProvider.notifier).state = status;
    context.go(Routes.inspections);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When the sample is smaller than the server total, the figures are a
    // floor. Show "12+" rather than a number that might be wrong.
    String label(InspectionStatus s) {
      final n = data.of(s);
      return data.isPartial && n > 0 ? '$n+' : '$n';
    }

    return Column(
      children: <Widget>[
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
              value: label(InspectionStatus.assigned),
              icon: Icons.inbox_rounded,
              color: AppColors.offline,
              onTap: () =>
                  _openFiltered(context, ref, InspectionStatus.assigned),
            ),
            StatCard(
              label: 'In progress',
              value: label(InspectionStatus.inProgress),
              icon: Icons.pending_actions_rounded,
              color: AppColors.primary,
              onTap: () =>
                  _openFiltered(context, ref, InspectionStatus.inProgress),
            ),
            StatCard(
              label: 'Corrections',
              value: label(InspectionStatus.correctionRequested),
              icon: Icons.report_problem_rounded,
              color: AppColors.warning,
              onTap: () => _openFiltered(
                context,
                ref,
                InspectionStatus.correctionRequested,
              ),
            ),
            StatCard(
              label: 'Submitted',
              value: label(InspectionStatus.submitted),
              icon: Icons.send_rounded,
              color: AppColors.teal,
              onTap: () =>
                  _openFiltered(context, ref, InspectionStatus.submitted),
            ),
          ],
        ),
        if (data.isPartial)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Showing the most recent ${data.countedItems} of '
              '${data.serverTotal} inspections.',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _CountersSkeleton extends StatelessWidget {
  const _CountersSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.06);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.5,
      children: <Widget>[
        for (var i = 0; i < 4; i++)
          Container(
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
      ],
    );
  }
}

/// Surfaces the server's own validation message, which is what makes a 400
/// diagnosable without opening the browser console.
class _CountersError extends StatelessWidget {
  const _CountersError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiError ? error as ApiError : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  (api?.isOffline ?? false)
                      ? Icons.wifi_off_rounded
                      : Icons.error_outline_rounded,
                  size: 20,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppSpacing.xs),
                const Expanded(
                  child: Text(
                    'Could not load your inspection summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              api?.message ?? 'Please try again.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (api?.status != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  'HTTP ${api!.status}'
                  '${api.code.isEmpty ? '' : ' · ${api.code}'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
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
