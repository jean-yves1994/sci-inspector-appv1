import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../templates/data/templates_repository.dart';
import '../../templates/domain/template.dart';
import '../data/inspections_repository.dart';
import '../domain/inspection.dart';
import '../domain/inspection_status.dart';

// ------------------------------------------------------------------ list

final inspectionSearchProvider = StateProvider<String>((ref) => '');
final inspectionFilterProvider =
    StateProvider<InspectionStatus?>((ref) => null);

class InspectionListState {
  const InspectionListState({
    this.items = const <InspectionListItem>[],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<InspectionListItem> items;
  final int page;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  InspectionListState copyWith({
    List<InspectionListItem>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      InspectionListState(
        items: items ?? this.items,
        page: page ?? this.page,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

class InspectionListNotifier extends AsyncNotifier<InspectionListState> {
  static const int _pageSize = 20;

  @override
  Future<InspectionListState> build() async {
    final search = ref.watch(inspectionSearchProvider);
    final status = ref.watch(inspectionFilterProvider);
    final token = CancelToken();
    ref.onDispose(() => token.cancel('disposed'));

    final r = await ref.read(inspectionsRepositoryProvider).list(
          search: search,
          status: status,
          limit: _pageSize,
          cancelToken: token,
        );

    return InspectionListState(
      items: r.items,
      page: r.page,
      total: r.total,
      hasMore: r.hasMore,
    );
  }

  Future<void> refresh() async => state = await AsyncValue.guard(build);

  Future<void> loadMore() async {
    final c = state.valueOrNull;
    if (c == null || !c.hasMore || c.isLoadingMore) return;
    state = AsyncData(c.copyWith(isLoadingMore: true));
    try {
      final r = await ref.read(inspectionsRepositoryProvider).list(
            search: ref.read(inspectionSearchProvider),
            status: ref.read(inspectionFilterProvider),
            page: c.page + 1,
            limit: _pageSize,
          );
      state = AsyncData(c.copyWith(
        items: <InspectionListItem>[...c.items, ...r.items],
        page: r.page,
        total: r.total,
        hasMore: r.hasMore,
        isLoadingMore: false,
      ));
    } on ApiError {
      state = AsyncData(c.copyWith(isLoadingMore: false));
    }
  }
}

final inspectionListProvider =
    AsyncNotifierProvider<InspectionListNotifier, InspectionListState>(
        InspectionListNotifier.new);

/// Dashboard counters, derived from real backend data only.
final inspectionCountsProvider =
    FutureProvider.autoDispose<Map<InspectionStatus, int>>((ref) async {
  final repo = ref.watch(inspectionsRepositoryProvider);
  const tracked = <InspectionStatus>[
    InspectionStatus.assigned,
    InspectionStatus.inProgress,
    InspectionStatus.correctionRequested,
    InspectionStatus.submitted,
    InspectionStatus.approved,
  ];

  final counts = <InspectionStatus, int>{};
  await Future.wait(tracked.map((s) async {
    // limit:1 — we only need the server's total for each status.
    final r = await repo.list(status: s, limit: 1);
    counts[s] = r.total;
  }));
  return counts;
});

// ------------------------------------------------------------- workspace

enum SaveStatus { idle, saving, saved, failed }

class WorkspaceState {
  const WorkspaceState({
    required this.inspection,
    this.template,
    this.saveStatus = SaveStatus.idle,
    this.staleVersion = false,
    this.errorMessage,
  });

  final Inspection inspection;
  final InspectionTemplate? template;
  final SaveStatus saveStatus;

  /// True when the server rejected our baseVersion. We must NOT overwrite.
  final bool staleVersion;
  final String? errorMessage;

  WorkspaceState copyWith({
    Inspection? inspection,
    InspectionTemplate? template,
    SaveStatus? saveStatus,
    bool? staleVersion,
    String? errorMessage,
    bool clearError = false,
  }) =>
      WorkspaceState(
        inspection: inspection ?? this.inspection,
        template: template ?? this.template,
        saveStatus: saveStatus ?? this.saveStatus,
        staleVersion: staleVersion ?? this.staleVersion,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

/// Owns one inspection's editing session: hydration, autosave, concurrency.
class InspectionWorkspaceNotifier
    extends AutoDisposeFamilyAsyncNotifier<WorkspaceState, String> {
  Timer? _debounce;

  /// Field values edited but not yet flushed to the server.
  final Map<String, InspectionValue> _dirty = <String, InspectionValue>{};

  @override
  Future<WorkspaceState> build(String inspectionId) async {
    ref.onDispose(() => _debounce?.cancel());

    final inspection =
        await ref.read(inspectionsRepositoryProvider).byId(inspectionId);

    // The template usually arrives embedded; fall back to fetching it.
    var template = inspection.template;
    if (template == null || template.sections.isEmpty) {
      final repo = ref.read(templatesRepositoryProvider);
      try {
        template = inspection.templateId != null
            ? await repo.byId(inspection.templateId!)
            : await repo.defaultTemplate();
      } on ApiError {
        template = null; // surfaced in the UI rather than crashing
      }
    }

    return WorkspaceState(inspection: inspection, template: template);
  }

  WorkspaceState get _s => state.requireValue;

  Future<void> reload() async {
    _dirty.clear();
    state = const AsyncLoading<WorkspaceState>();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// Current value for a field: pending edit first, then server state.
  InspectionValue? valueFor(String fieldId) {
    if (_dirty.containsKey(fieldId)) return _dirty[fieldId];
    for (final v in _s.inspection.values) {
      if (v.fieldId == fieldId) return v;
    }
    return null;
  }

  /// Records an edit and schedules a debounced save (500-1000 ms).
  void onFieldChanged(InspectionValue value) {
    _dirty[value.fieldId] = value;
    state = AsyncData(_s.copyWith(saveStatus: SaveStatus.idle));

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), flush);
  }

  /// Sends only the changed values, with the current baseVersion.
  Future<void> flush() async {
    if (_dirty.isEmpty || !state.hasValue) return;

    final pending = _dirty.values.toList();
    state = AsyncData(_s.copyWith(
        saveStatus: SaveStatus.saving, clearError: true));

    try {
      final updated = await ref.read(inspectionsRepositoryProvider).saveValues(
            id: arg,
            values: pending,
            baseVersion: _s.inspection.version,
          );
      _dirty.clear();
      state = AsyncData(_s.copyWith(
        inspection: updated,
        saveStatus: SaveStatus.saved,
        staleVersion: false,
      ));
      ref.invalidate(completenessProvider(arg));
    } on ApiError catch (e) {
      // Never silently overwrite server data on a version conflict.
      state = AsyncData(_s.copyWith(
        saveStatus: SaveStatus.failed,
        staleVersion: e.isStaleVersion,
        errorMessage: e.message,
      ));
    }
  }

  Future<void> _mutate(
    Future<Inspection> Function(int baseVersion) run,
  ) async {
    state = AsyncData(_s.copyWith(
        saveStatus: SaveStatus.saving, clearError: true));
    try {
      final updated = await run(_s.inspection.version);
      state = AsyncData(_s.copyWith(
        inspection: updated,
        saveStatus: SaveStatus.saved,
        staleVersion: false,
      ));
      ref.invalidate(completenessProvider(arg));
    } on ApiError catch (e) {
      state = AsyncData(_s.copyWith(
        saveStatus: SaveStatus.failed,
        staleVersion: e.isStaleVersion,
        errorMessage: e.message,
      ));
      rethrow;
    }
  }

  Future<void> start() async {
    final updated =
        await ref.read(inspectionsRepositoryProvider).start(arg);
    state = AsyncData(_s.copyWith(inspection: updated));
    ref.invalidate(inspectionListProvider);
  }

  Future<void> saveAssessment(InspectionAssessment a) => _mutate((v) => ref
      .read(inspectionsRepositoryProvider)
      .saveAssessment(id: arg, assessment: a, baseVersion: v));

  Future<void> saveOwner(InspectionOwner o) => _mutate((v) => ref
      .read(inspectionsRepositoryProvider)
      .saveOwner(id: arg, owner: o, baseVersion: v));

  Future<void> saveValuation(InspectionValuation val) => _mutate((v) => ref
      .read(inspectionsRepositoryProvider)
      .saveValuation(id: arg, valuation: val, baseVersion: v));

  Future<void> captureLocation({
    required double latitude,
    required double longitude,
    double? accuracyM,
    double? altitudeM,
    String source = 'GPS',
    bool isMocked = false,
    DateTime? capturedAt,
  }) =>
      _mutate((v) => ref.read(inspectionsRepositoryProvider).captureLocation(
            id: arg,
            latitude: latitude,
            longitude: longitude,
            accuracyM: accuracyM,
            altitudeM: altitudeM,
            source: source,
            isMocked: isMocked,
            capturedAt: capturedAt,
            baseVersion: v,
          ));

  /// Flushes pending edits first, then submits. The server re-checks
  /// completeness, so a local "complete" result is never sufficient.
  Future<Inspection> submit() async {
    await flush();
    final updated =
        await ref.read(inspectionsRepositoryProvider).submit(arg);
    state = AsyncData(_s.copyWith(inspection: updated));
    ref.invalidate(inspectionListProvider);
    ref.invalidate(inspectionCountsProvider);
    return updated;
  }
}

final inspectionWorkspaceProvider = AsyncNotifierProvider.autoDispose
    .family<InspectionWorkspaceNotifier, WorkspaceState, String>(
        InspectionWorkspaceNotifier.new);

/// Server-calculated completeness. The client never computes this.
final completenessProvider = FutureProvider.autoDispose
    .family<CompletenessResult, String>((ref, id) =>
        ref.watch(inspectionsRepositoryProvider).completeness(id));
