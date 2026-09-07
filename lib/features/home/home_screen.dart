import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/account_avatar.dart';
import '../../core/widgets/sci_widgets.dart';
import '../auth/application/session_controller.dart';
import '../inspections/application/dashboard_provider.dart';
import '../inspections/application/inspection_providers.dart';
import '../inspections/domain/inspection_status.dart';
import '../inspections/presentation/inspection_screens.dart';

/// Inspector dashboard.
///
/// The previous version used a Material `AppBar`, which sat flush against the
/// status bar and produced the cramped header in the screenshot. This uses a
/// rounded header card inside a `SafeArea` instead — the same shape as the
/// reference design, with the notch/status bar properly cleared.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      // No AppBar. The header is part of the scroll view, so it can carry its
      // own padding, radius and elevation rather than being clipped to the
      // system bar.
      body: SafeArea(
        // The bottom edge is handled by the list padding, since the notched
        // navigation bar overlaps the body.
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const _HeaderCard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  // Clears the notched bar and the docked FAB.
                  110,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SectionHeading('My inspections'),
                    const SizedBox(height: AppSpacing.sm),

                    dashboard.when(
                      loading: () => const _CountersSkeleton(),
                      error: (error, _) => _CountersError(
                        error: error,
                        onRetry: () => ref.invalidate(dashboardProvider),
                      ),
                      data: (data) => _Counters(data: data),
                    ),

                    // Was AppSpacing.xl plus a stray SizedBox, which produced
                    // the empty band in the screenshot.
                    const SizedBox(height: AppSpacing.xxs),
                    const _SectionHeading('Quick actions'),
                    const SizedBox(height: AppSpacing.sm),
                    const _QuickActions(),

                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: _SectionHeading('Recent inspections'),
                        ),
                        TextButton(
                          onPressed: () => context.go(Routes.inspections),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    dashboard.when(
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (data) => data.recent.isEmpty
                          ? const Card(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.xl),
                                child: EmptyState(
                                  icon: Icons.assignment_outlined,
                                  title: 'No inspections assigned',
                                  message: 'Inspections assigned to you will '
                                      'appear here.',
                                ),
                              ),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded header card, following the reference design.
///
/// Sits inside the SafeArea with its own vertical padding, so there is real
/// space between the status bar and the greeting — the gap that was missing
/// before.
class _HeaderCard extends ConsumerWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // Avatar leads, as in the reference. It is also the account menu.
          const AccountAvatar(radius: 24, showTrailingPadding: false),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${_greeting()} ${user?.firstName ?? 'Inspector'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.badge_outlined,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        user?.isInspector ?? false
                            ? 'Field inspector'
                            : (user?.email ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.go(Routes.inspections),
            icon: const Icon(Icons.search_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Search inspections',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionCard(
            icon: Icons.add_home_work_outlined,
            label: 'New property',
            caption: 'Register from the field',
            onTap: () => context.push(Routes.propertyNew),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionCard(
            icon: Icons.apartment_outlined,
            label: 'Properties',
            caption: 'Search and open',
            onTap: () => context.go(Routes.properties),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
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
          // Raised from 1.5: the tiles were taller than their content needed,
          // which is what created the empty band beneath the grid.
          childAspectRatio: 1.75,
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
      childAspectRatio: 1.75,
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
