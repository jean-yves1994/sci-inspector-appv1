import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic change counters, one per domain.
///
/// Providers that display derived data watch the counter they care about;
/// write sites bump it. Riverpod diffs the integer and rebuilds only the
/// watchers whose counter actually moved.
///
/// Integers rather than booleans because a counter is always distinct from its
/// predecessor — a bool flipped twice within one frame would coalesce and the
/// second rebuild would be missed.
class DataChangeState {
  const DataChangeState({
    this.propertiesVersion = 0,
    this.inspectionsVersion = 0,
    this.photosVersion = 0,
    this.lastChangedInspectionId,
  });

  final int propertiesVersion;
  final int inspectionsVersion;
  final int photosVersion;

  /// Which inspection the last photo change belonged to, so one workspace can
  /// ignore changes made to another.
  final String? lastChangedInspectionId;

  DataChangeState copyWith({
    int? propertiesVersion,
    int? inspectionsVersion,
    int? photosVersion,
    String? lastChangedInspectionId,
  }) =>
      DataChangeState(
        propertiesVersion: propertiesVersion ?? this.propertiesVersion,
        inspectionsVersion: inspectionsVersion ?? this.inspectionsVersion,
        photosVersion: photosVersion ?? this.photosVersion,
        lastChangedInspectionId:
            lastChangedInspectionId ?? this.lastChangedInspectionId,
      );
}

/// Central change notification.
///
/// Replaces scattering `ref.invalidate(...)` across every write site. That
/// worked, but relied on each new screen remembering every affected provider —
/// which is exactly how the photo-progress and dashboard staleness bugs arose.
class DataChanged extends Notifier<DataChangeState> {
  @override
  DataChangeState build() => const DataChangeState();

  void propertyChanged() {
    state = state.copyWith(propertiesVersion: state.propertiesVersion + 1);
  }

  void inspectionChanged() {
    state = state.copyWith(inspectionsVersion: state.inspectionsVersion + 1);
  }

  /// A photo was uploaded or deleted for [inspectionId].
  ///
  /// Bumps inspections too: photo count feeds completeness, which appears on
  /// the inspection list and the dashboard.
  void photosChanged(String inspectionId) {
    state = state.copyWith(
      photosVersion: state.photosVersion + 1,
      inspectionsVersion: state.inspectionsVersion + 1,
      lastChangedInspectionId: inspectionId,
    );
  }
}

final dataChangedProvider =
    NotifierProvider<DataChanged, DataChangeState>(DataChanged.new);

// ---------------------------------------------------------------- selectors

final propertiesVersionProvider = Provider<int>(
  (ref) => ref.watch(dataChangedProvider.select((s) => s.propertiesVersion)),
);

final inspectionsVersionProvider = Provider<int>(
  (ref) => ref.watch(dataChangedProvider.select((s) => s.inspectionsVersion)),
);

/// Photo changes scoped to one inspection, so an upload against inspection A
/// never rebuilds inspection B's workspace.
final photosVersionProvider = Provider.family<int, String>((ref, inspectionId) {
  return ref.watch(
    dataChangedProvider.select(
      (s) => s.lastChangedInspectionId == inspectionId ? s.photosVersion : 0,
    ),
  );
});
