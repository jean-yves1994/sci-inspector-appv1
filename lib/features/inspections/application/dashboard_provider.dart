import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inspections_repository.dart';
import '../domain/inspection.dart';
import '../domain/inspection_status.dart';

/// Dashboard data derived from ONE request.
///
/// Replaces the previous fan-out of five `?limit=1&status=X` calls that read
/// only `total` from each. That design was wasteful (5 round-trips per
/// dashboard load) and fragile: a validation rule on any single parameter
/// broke every counter at once, which is what produced the 400s.
///
/// One unfiltered page now serves both the counters and the "recent
/// inspections" list.
class DashboardData {
  const DashboardData({
    required this.counts,
    required this.recent,
    required this.countedItems,
    required this.serverTotal,
  });

  final Map<InspectionStatus, int> counts;
  final List<InspectionListItem> recent;

  /// How many inspections the counts were actually derived from.
  final int countedItems;

  /// What the server reports as the overall total, when it supplies one.
  final int serverTotal;

  /// True when the server holds more inspections than we fetched, so the
  /// counters are a floor rather than an exact figure. The UI marks them with
  /// a "+" rather than showing a number it cannot stand behind.
  bool get isPartial => serverTotal > countedItems;

  int of(InspectionStatus status) => counts[status] ?? 0;
}

/// Page size for the dashboard sample.
///
/// Note: with `PaginationParams.pageSizeParam` still null, no page-size
/// parameter is sent and the server's default applies. This value becomes
/// effective once that name is confirmed.
const int _dashboardSampleSize = 50;

final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final page = await ref.watch(inspectionsRepositoryProvider).list(
        limit: _dashboardSampleSize,
        // No status filter: one request covers every bucket.
      );

  final counts = <InspectionStatus, int>{};
  for (final item in page.items) {
    counts[item.status] = (counts[item.status] ?? 0) + 1;
  }

  return DashboardData(
    counts: counts,
    recent: page.items.take(5).toList(),
    countedItems: page.items.length,
    serverTotal: page.total,
  );
});
