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
  InspectionListNotifier.new,
);

// ------------------------------------------------------------- workspace

enum SaveStatus { idle, saving, saved, failed }

class WorkspaceState {
  const WorkspaceState({
    required this.inspection,
    this.template,
    this.completeness,
    this.saveStatus = SaveStatus.idle,
    this.staleVersion = false,
    this.errorMessage,
    this.pendingEdits = 0,
  });

  final Inspection inspection;
  final InspectionTemplate? template;

  /// Latest completeness, refreshed for free by most mutations.
  final CompletenessResult? completeness;

  final SaveStatus saveStatus;
  final bool staleVersion;
  final String? errorMessage;
  final int pendingEdits;

  bool get hasPendingEdits => pendingEdits > 0;

  WorkspaceState copyWith({
    Inspection? inspection,
    InspectionTemplate? template,
    CompletenessResult? completeness,
    SaveStatus? saveStatus,
    bool? staleVersion,
    String? errorMessage,
    int? pendingEdits,
    bool clearError = false,
  }) =>
      WorkspaceState(
        inspection: inspection ?? this.inspection,
        template: template ?? this.template,
        completeness: completeness ?? this.completeness,
        saveStatus: saveStatus ?? this.saveStatus,
        staleVersion: staleVersion ?? this.staleVersion,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        pendingEdits: pendingEdits ?? this.pendingEdits,
      );
}

/// Owns one inspection's editing session.
///
/// Three invariants, each of which was previously violated:
///
///  1. **Mutations are serialised** via [_enqueue], so two saves can never
///     read the same `baseVersion`.
///  2. **Responses are classified, not assumed.** Most mutation endpoints
///     return a completeness payload rather than the aggregate; parsing that
///     as an Inspection crashes on the missing `id`.
///  3. **A conflict never auto-overwrites.** It refetches, keeps unsaved
///     edits, and waits for the inspector to choose.
class InspectionWorkspaceNotifier
    extends AutoDisposeFamilyAsyncNotifier<WorkspaceState, String> {
  Timer? _debounce;

  final Map<String, InspectionValue> _dirty = <String, InspectionValue>{};

  /// Serialises mutations: each awaits its predecessor, so `baseVersion` is
  /// always read after the previous write has landed.
  Future<void> _queue = Future<void>.value();

  @override
  Future<WorkspaceState> build(String inspectionId) async {
    ref.onDispose(() => _debounce?.cancel());

    final repo = ref.read(inspectionsRepositoryProvider);
    final inspection = await repo.byId(inspectionId);

    var template = inspection.template;
    if (template == null || template.sections.isEmpty) {
      final templates = ref.read(templatesRepositoryProvider);
      try {
        template = inspection.templateId != null
            ? await templates.byId(inspection.templateId!)
            : await templates.defaultTemplate();
      } on ApiError {
        template = null; // surfaced in the UI rather than crashing
      }
    }

    CompletenessResult? completeness = inspection.completeness;
    if (completeness == null) {
      try {
        completeness = await repo.completeness(inspectionId);
      } on ApiError {
        completeness = null;
      }
    }

    return WorkspaceState(
      inspection: inspection,
      template: template,
      completeness: completeness,
    );
  }

  WorkspaceState get _s => state.requireValue;

  int get currentVersion => state.valueOrNull?.inspection.version ?? 0;

  // ----------------------------------------------------------- internals

  /// Applies whatever the mutation returned.
  ///
  /// Only `start()` and `GET /:id` carry the aggregate. Everything else needs
  /// a refetch to learn the new version — but the completeness the response
  /// *did* carry is kept, so the extra GET /completeness is skipped.
  Future<void> _applyMutationResult(MutationResult result) async {
    final embeddedCompleteness = result.completeness;

    Inspection inspection;
    if (result.inspection != null &&
        result.inspection!.version >= currentVersion) {
      inspection = result.inspection!;
    } else {
      // Authoritative re-read. Required because the response omitted the
      // version — the defect confirmed by the probe.
      inspection = await ref.read(inspectionsRepositoryProvider).byId(arg);
    }

    state = AsyncData(_s.copyWith(
      inspection: inspection,
      completeness: embeddedCompleteness ?? inspection.completeness,
      saveStatus: SaveStatus.saved,
      staleVersion: false,
      pendingEdits: _dirty.length,
    ));

    // Keep the standalone provider in sync for screens that watch it, without
    // forcing a network round-trip when we already have the answer.
    if (embeddedCompleteness == null) {
      ref.invalidate(completenessProvider(arg));
    }
  }

  Future<T?> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T?>();

    _queue = _queue.then((_) async {
      if (!state.hasValue) {
        completer.complete(null);
        return;
      }
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });

    _queue = _queue.catchError((Object _) {});
    return completer.future;
  }

  // ------------------------------------------------------------ reading

  InspectionValue? valueFor(String fieldId) {
    if (_dirty.containsKey(fieldId)) return _dirty[fieldId];
    final current = state.valueOrNull;
    if (current == null) return null;
    for (final v in current.inspection.values) {
      if (v.fieldId == fieldId) return v;
    }
    return null;
  }

  // ------------------------------------------------------------ editing

  void onFieldChanged(InspectionValue value) {
    if (!state.hasValue) return;

    _dirty[value.fieldId] = value;
    state = AsyncData(
      _s.copyWith(saveStatus: SaveStatus.idle, pendingEdits: _dirty.length),
    );

    // While a conflict is unresolved, keep collecting edits but send nothing.
    if (_s.staleVersion) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), flush);
  }

  Future<void> flush() async {
    if (!state.hasValue || _dirty.isEmpty || _s.staleVersion) return;

    await _enqueue(() async {
      if (_dirty.isEmpty || _s.staleVersion) return;

      final batch = Map<String, InspectionValue>.from(_dirty);

      state = AsyncData(
        _s.copyWith(saveStatus: SaveStatus.saving, clearError: true),
      );

      try {
        final result =
            await ref.read(inspectionsRepositoryProvider).saveValues(
                  id: arg,
                  values: batch.values.toList(),
                  // Read only after the queue grants this turn.
                  baseVersion: currentVersion,
                );

        // Clear only what we sent; anything typed during the request stays
        // dirty for the next flush.
        batch.forEach((fieldId, sent) {
          if (identical(_dirty[fieldId], sent)) _dirty.remove(fieldId);
        });

        await _applyMutationResult(result);
      } on ApiError catch (e) {
        await _handleMutationError(e);
      }
    });
  }

  Future<void> _mutate(
    Future<MutationResult> Function(int baseVersion) run,
  ) async {
    if (!state.hasValue) return;

    await _enqueue(() async {
      if (_s.staleVersion) {
        throw const ApiError(
          code: ApiErrorCode.inspectionStaleVersion,
          message: 'Resolve the sync conflict before saving again.',
        );
      }

      state = AsyncData(
        _s.copyWith(saveStatus: SaveStatus.saving, clearError: true),
      );

      try {
        await _applyMutationResult(await run(currentVersion));
      } on ApiError catch (e) {
        await _handleMutationError(e);
        rethrow;
      }
    });
  }

  /// Never `localVersion = serverVersion; retry` — that would overwrite the
  /// other writer. Refetch, keep local edits, hand the decision back.
  Future<void> _handleMutationError(ApiError e) async {
    if (!e.isStaleVersion) {
      state = AsyncData(_s.copyWith(
        saveStatus: SaveStatus.failed,
        errorMessage: e.message,
      ));
      return;
    }

    Inspection? fresh;
    try {
      fresh = await ref.read(inspectionsRepositoryProvider).byId(arg);
    } on ApiError {
      fresh = null; // offline: keep the conflict, lose nothing
    }

    state = AsyncData(_s.copyWith(
      inspection: fresh ?? _s.inspection,
      saveStatus: SaveStatus.failed,
      staleVersion: true,
      pendingEdits: _dirty.length,
      errorMessage: _dirty.isEmpty
          ? 'This inspection changed on another device. It has been refreshed.'
          : 'This inspection changed on another device. Your ${_dirty.length} '
              'unsaved change(s) were kept — review them, then save again.',
    ));
  }

  // -------------------------------------------------- conflict resolution

  Future<void> retryAfterConflict() async {
    if (!state.hasValue) return;
    state = AsyncData(_s.copyWith(staleVersion: false, clearError: true));
    await flush();
  }

  Future<void> discardAndReload() async {
    _debounce?.cancel();
    _dirty.clear();
    state = const AsyncLoading<WorkspaceState>();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> reload() => discardAndReload();

  // ----------------------------------------------------------- mutations

  Future<void> start() async {
    if (!state.hasValue) return;

    await _enqueue(() async {
      // Verified by probe: start() returns the full aggregate with the new
      // version, so this needs no refetch.
      final updated = await ref.read(inspectionsRepositoryProvider).start(arg);

      state = AsyncData(_s.copyWith(
        inspection: updated,
        completeness: updated.completeness ?? _s.completeness,
      ));
      ref.invalidate(inspectionListProvider);
    });
  }

  Future<void> saveAssessment(InspectionAssessment a) => _mutate(
        (v) => ref
            .read(inspectionsRepositoryProvider)
            .saveAssessment(id: arg, assessment: a, baseVersion: v),
      );

  Future<void> saveOwner(InspectionOwner o) => _mutate(
        (v) => ref
            .read(inspectionsRepositoryProvider)
            .saveOwner(id: arg, owner: o, baseVersion: v),
      );

  Future<void> saveValuation(InspectionValuation val) => _mutate(
        (v) => ref
            .read(inspectionsRepositoryProvider)
            .saveValuation(id: arg, valuation: val, baseVersion: v),
      );

  Future<void> captureLocation({
    required double latitude,
    required double longitude,
    double? accuracyM,
    double? altitudeM,
    String source = 'GPS',
    bool isMocked = false,
    DateTime? capturedAt,
  }) =>
      _mutate(
        (v) => ref.read(inspectionsRepositoryProvider).captureLocation(
              id: arg,
              latitude: latitude,
              longitude: longitude,
              accuracyM: accuracyM,
              altitudeM: altitudeM,
              source: source,
              isMocked: isMocked,
              capturedAt: capturedAt,
              baseVersion: v,
            ),
      );

  /// Flushes pending edits, then submits. Aborts if the flush did not land.
  Future<Inspection> submit() async {
    _debounce?.cancel();
    await flush();

    if (!state.hasValue) {
      throw const ApiError(
        code: ApiErrorCode.unknown,
        message: 'The inspection is not loaded.',
      );
    }

    if (_s.staleVersion) {
      throw const ApiError(
        code: ApiErrorCode.inspectionStaleVersion,
        message: 'This inspection changed on another device. Review the '
            'refreshed version, then submit again.',
      );
    }

    if (_dirty.isNotEmpty) {
      throw ApiError(
        code: ApiErrorCode.unknown,
        message: '${_dirty.length} change(s) could not be saved. Fix the save '
            'error before submitting.',
      );
    }

    final result = await ref.read(inspectionsRepositoryProvider).submit(arg);
    await _applyMutationResult(result);

    ref.invalidate(inspectionListProvider);
    return _s.inspection;
  }
}

final inspectionWorkspaceProvider = AsyncNotifierProvider.autoDispose
    .family<InspectionWorkspaceNotifier, WorkspaceState, String>(
  InspectionWorkspaceNotifier.new,
);

/// Server-calculated completeness.
///
/// Prefers the copy already held by the workspace — most mutations return it,
/// so watching this rarely costs a request.
final completenessProvider = FutureProvider.autoDispose
    .family<CompletenessResult, String>((ref, id) async {
  final cached =
      ref.watch(inspectionWorkspaceProvider(id)).valueOrNull?.completeness;
  if (cached != null) return cached;

  return ref.watch(inspectionsRepositoryProvider).completeness(id);
});
