import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../templates/data/templates_repository.dart';
import '../../templates/domain/template.dart';
import '../data/inspections_repository.dart';
import '../domain/inspection.dart';
import '../domain/inspection_status.dart';
import 'dashboard_provider.dart';
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
    this.errorMessage,
    this.pendingEdits = 0,
  });

  final Inspection inspection;
  final InspectionTemplate? template;
  final CompletenessResult? completeness;
  final SaveStatus saveStatus;

  /// Populated only for genuine, unrecoverable save failures. There is no
  /// longer a `staleVersion` latch: the previous design suppressed every
  /// subsequent save once it was set, so a single conflict silently froze the
  /// whole form.
  final String? errorMessage;

  final int pendingEdits;

  bool get hasPendingEdits => pendingEdits > 0;

  WorkspaceState copyWith({
    Inspection? inspection,
    InspectionTemplate? template,
    CompletenessResult? completeness,
    SaveStatus? saveStatus,
    String? errorMessage,
    int? pendingEdits,
    bool clearError = false,
  }) =>
      WorkspaceState(
        inspection: inspection ?? this.inspection,
        template: template ?? this.template,
        completeness: completeness ?? this.completeness,
        saveStatus: saveStatus ?? this.saveStatus,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        pendingEdits: pendingEdits ?? this.pendingEdits,
      );
}

/// Owns one inspection's editing session.
///
/// Design notes, each addressing a bug found in the previous implementation:
///
///  * **No cached version.** The repository reads the authoritative version
///    immediately before every write, so there is nothing to go stale. This
///    is the change that removes INSPECTION_STALE_VERSION in the
///    single-inspector workflow the backend already enforces.
///
///  * **No `staleVersion` latch.** The old flag, once set, made
///    `onFieldChanged` and `flush` return early forever — the inspector kept
///    typing into a void and completeness never moved.
///
///  * **Mutations are serialised** through [_enqueue], so two writes cannot
///    interleave between the version read and the write.
///
///  * **Every failure is an ApiError.** Non-Dio exceptions are wrapped, so a
///    parse error can no longer surface as a bare "Something went wrong".
class InspectionWorkspaceNotifier
    extends AutoDisposeFamilyAsyncNotifier<WorkspaceState, String> {
  Timer? _debounce;

  final Map<String, InspectionValue> _dirty = <String, InspectionValue>{};

  Future<void> _queue = Future<void>.value();

  @override
  Future<WorkspaceState> build(String inspectionId) async {
    ref.onDispose(() => _debounce?.cancel());

    final repo = ref.read(inspectionsRepositoryProvider);

    // Any throw here — including a parse failure — becomes an ApiError, so
    // ErrorStateView can show a real cause instead of a generic message.
    final Inspection inspection;
    try {
      inspection = await repo.byId(inspectionId);
    } on ApiError {
      rethrow;
    } catch (error, stack) {
      throw ApiError.fromException(error, stack);
    }

    InspectionTemplate? template = inspection.template;
    if (template == null || template.sections.isEmpty) {
      try {
        final templates = ref.read(templatesRepositoryProvider);
        template = inspection.templateId != null
            ? await templates.byId(inspection.templateId!)
            : await templates.defaultTemplate();
      } catch (_) {
        template = null; // surfaced in the UI as a banner, not a crash
      }
    }

    CompletenessResult? completeness = inspection.completeness;
    if (completeness == null) {
      try {
        completeness = await repo.completeness(inspectionId);
      } catch (_) {
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

  // ----------------------------------------------------------- internals

  /// Runs [action] after every previously queued mutation has settled.
  Future<void> _enqueue(Future<void> Function() action) {
    final completer = Completer<void>();

    _queue = _queue.then((_) async {
      if (!state.hasValue) {
        completer.complete();
        return;
      }
      try {
        await action();
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });

    _queue = _queue.catchError((Object _) {});
    return completer.future;
  }

  /// Applies a mutation response.
  ///
  /// Adopts the version when the response carries one; otherwise refetches.
  /// Either way the local copy ends up consistent, and because the NEXT write
  /// re-reads the version anyway, a miss here cannot cause a later conflict.
  Future<void> _apply(MutationResult result) async {
    Inspection inspection;

    if (result.inspection != null) {
      inspection = result.inspection!;
    } else if (result.version != null) {
      inspection = _s.inspection.copyWith(
        version: result.version,
        status: result.status == null
            ? null
            : InspectionStatusX.parse(result.status),
      );
    } else {
      inspection = await ref.read(inspectionsRepositoryProvider).byId(arg);
    }

    state = AsyncData(_s.copyWith(
      inspection: inspection,
      completeness: result.completeness ?? inspection.completeness,
      saveStatus: SaveStatus.saved,
      pendingEdits: _dirty.length,
      clearError: true,
    ));

    // Completeness changed, so anything watching it must re-read.
    ref.invalidate(completenessProvider(arg));
  }

  /// Single funnel for every write.
  Future<void> _run(Future<MutationResult> Function() action) {
    return _enqueue(() async {
      state = AsyncData(
        _s.copyWith(saveStatus: SaveStatus.saving, clearError: true),
      );

      try {
        await _apply(await action());
      } on ApiError catch (e) {
        state = AsyncData(_s.copyWith(
          saveStatus: SaveStatus.failed,
          errorMessage: e.isStaleVersion
              // Now genuinely rare: the version was read moments before the
              // write, so this means a real concurrent writer.
              ? 'Another device changed this inspection while you were saving. '
                  'Your changes were kept — tap Save to try again.'
              : e.message,
          pendingEdits: _dirty.length,
        ));
      } catch (error, stack) {
        final wrapped = ApiError.fromException(error, stack);
        state = AsyncData(_s.copyWith(
          saveStatus: SaveStatus.failed,
          errorMessage: wrapped.message,
          pendingEdits: _dirty.length,
        ));
      }
    });
  }

  /// Updates the visible completeness immediately when the inspector fixes
  /// a known outstanding requirement. The server remains authoritative; the
  /// next successful mutation replaces this estimate with the server result.
  ///
  /// This is intentionally conservative: when we cannot identify the issue
  /// that changed, the current server value is kept rather than inventing a
  /// percentage.
  CompletenessResult? _optimisticCompleteness({
    String? fieldCode,
    String? sectionCode,
    String? textMatch,
  }) {
    final current = _s.completeness;
    if (current == null) return null;

    final needleField = fieldCode?.trim().toUpperCase();
    final needleSection = sectionCode?.trim().toUpperCase();
    final needleText = textMatch?.trim().toUpperCase();

    bool matches(CompletenessIssue issue) {
      if (needleField != null &&
          issue.fieldCode?.trim().toUpperCase() == needleField) {
        return true;
      }
      if (needleSection != null &&
          issue.fieldCode == null &&
          issue.sectionCode?.trim().toUpperCase() == needleSection) {
        return true;
      }
      if (needleText != null) {
        final haystack = '${issue.code ?? ''} ${issue.message}'.toUpperCase();
        return haystack.contains(needleText);
      }
      return false;
    }

    final issues = current.issues.where((i) => !matches(i)).toList();
    final blocking =
        current.blockingIssues.where((i) => !matches(i)).toList();
    final oldOutstanding = current.outstanding.length;
    final newOutstanding = blocking.isNotEmpty ? blocking.length : issues.length;
    if (newOutstanding == oldOutstanding) return null;

    final total = current.percentage >= 100
        ? math.max(1, oldOutstanding)
        : math.max(
            oldOutstanding,
            ((oldOutstanding * 100) /
                    math.max(1, 100 - current.percentage))
                .round(),
          );
    final percentage = current.percentage >= 100
        ? 100
        : ((total - newOutstanding) * 100 / total)
            .round()
            .clamp(0, 100)
            .toInt();

    return CompletenessResult(
      complete: blocking.isEmpty && issues.isEmpty,
      percentage: percentage,
      issues: issues,
      blockingIssues: blocking,
    );
  }

  void _applyOptimisticCompleteness(CompletenessResult? next) {
    if (next == null || !state.hasValue) return;
    state = AsyncData(_s.copyWith(completeness: next));
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

  void onFieldChanged(InspectionValue value, {String? sectionCode}) {
    if (!state.hasValue) return;

    _dirty[value.fieldId] = value;
    final values = [..._s.inspection.values];
    final index = values.indexWhere((item) => item.fieldId == value.fieldId);
    if (index >= 0) {
      values[index] = value;
    } else {
      values.add(value);
    }
    final nextCompleteness = _optimisticCompleteness(
      fieldCode: value.fieldId,
      sectionCode: sectionCode,
    );
    state = AsyncData(
      _s.copyWith(
        inspection: _s.inspection.copyWith(values: values),
        completeness: nextCompleteness ?? _s.completeness,
        saveStatus: SaveStatus.idle,
        pendingEdits: _dirty.length,
      ),
    );

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), flush);
  }

  /// Sends pending field values. Safe to call concurrently.
  Future<void> flush() async {
    if (!state.hasValue || _dirty.isEmpty) return;

    await _enqueue(() async {
      if (_dirty.isEmpty) return;

      final batch = Map<String, InspectionValue>.from(_dirty);

      state = AsyncData(
        _s.copyWith(saveStatus: SaveStatus.saving, clearError: true),
      );

      try {
        final result = await ref
            .read(inspectionsRepositoryProvider)
            .saveValues(
              id: arg,
              values: batch.values.toList(),
              baseVersion: state.valueOrNull?.inspection.version,
            );

        // Clear only what was sent; anything typed during the request stays
        // dirty and is picked up by the next flush.
        batch.forEach((fieldId, sent) {
          if (identical(_dirty[fieldId], sent)) _dirty.remove(fieldId);
        });

        await _apply(result);
      } on ApiError catch (e) {
        state = AsyncData(_s.copyWith(
          saveStatus: SaveStatus.failed,
          errorMessage: e.message,
          pendingEdits: _dirty.length,
        ));
      } catch (error, stack) {
        state = AsyncData(_s.copyWith(
          saveStatus: SaveStatus.failed,
          errorMessage: ApiError.fromException(error, stack).message,
          pendingEdits: _dirty.length,
        ));
      }
    });
  }

  /// Manual retry for the "Not saved" indicator.
  Future<void> retry() => flush();

  Future<void> discardAndReload() async {
    _debounce?.cancel();
    _dirty.clear();
    state = const AsyncLoading<WorkspaceState>();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> reload() => discardAndReload();

  /// Re-reads after a write that bypassed this notifier — photo upload and
  /// delete go straight to the photos endpoints.
  Future<void> resyncAfterExternalWrite() async {
    if (!state.hasValue) return;

    await _enqueue(() async {
      try {
        final fresh = await ref.read(inspectionsRepositoryProvider).byId(arg);
        state = AsyncData(_s.copyWith(
          inspection: fresh,
          completeness: fresh.completeness ?? _s.completeness,
        ));
        ref.invalidate(completenessProvider(arg));
      } catch (_) {
        // Offline: keep what we have. The next write re-reads the version
        // anyway, so nothing depends on this succeeding.
      }
    });
  }

  // ----------------------------------------------------------- mutations

  Future<void> start() async {
    if (!state.hasValue) return;

    await _enqueue(() async {
      final updated = await ref.read(inspectionsRepositoryProvider).start(arg);
      state = AsyncData(_s.copyWith(
        inspection: updated,
        completeness: updated.completeness ?? _s.completeness,
      ));
      ref.invalidate(inspectionListProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(completenessProvider(arg));
    });
  }

  Future<void> saveAssessment(InspectionAssessment a) {
    if (state.hasValue) {
      final assessments = [..._s.inspection.assessments];
      final index = assessments.indexWhere(
        (item) => item.categoryCode == a.categoryCode,
      );
      if (index >= 0) {
        assessments[index] = a;
      } else {
        assessments.add(a);
      }
      final nextCompleteness = _optimisticCompleteness(
        sectionCode: a.categoryCode,
      );
      state = AsyncData(_s.copyWith(
        inspection: _s.inspection.copyWith(assessments: assessments),
        completeness: nextCompleteness ?? _s.completeness,
        saveStatus: SaveStatus.idle,
      ));
    }
    return _run(
      () => ref.read(inspectionsRepositoryProvider).saveAssessment(
            id: arg,
            assessment: a,
            baseVersion: state.valueOrNull?.inspection.version,
          ),
    );
  }

  Future<void> saveOwner(InspectionOwner o) {
    if (state.hasValue) {
      _applyOptimisticCompleteness(_optimisticCompleteness(sectionCode: 'OWNER'));
      state = AsyncData(_s.copyWith(
        inspection: _s.inspection.copyWith(owner: o),
        saveStatus: SaveStatus.idle,
      ));
    }
    return _run(
      () => ref.read(inspectionsRepositoryProvider).saveOwner(
            id: arg,
            owner: o,
            baseVersion: state.valueOrNull?.inspection.version,
          ),
    );
  }

  Future<void> saveValuation(InspectionValuation v) {
    if (state.hasValue) {
      _applyOptimisticCompleteness(
        _optimisticCompleteness(sectionCode: 'VALUATION'),
      );
      state = AsyncData(_s.copyWith(
        inspection: _s.inspection.copyWith(valuation: v),
        saveStatus: SaveStatus.idle,
      ));
    }
    return _run(
      () => ref.read(inspectionsRepositoryProvider).saveValuation(
            id: arg,
            valuation: v,
            baseVersion: state.valueOrNull?.inspection.version,
          ),
    );
  }

  Future<void> captureLocation({
    required double latitude,
    required double longitude,
    double? accuracyM,
    double? altitudeM,
    String source = 'GPS',
    bool isMocked = false,
    DateTime? capturedAt,
  }) =>
      _run(
        () => ref.read(inspectionsRepositoryProvider).captureLocation(
              id: arg,
              latitude: latitude,
              longitude: longitude,
              accuracyM: accuracyM,
              altitudeM: altitudeM,
              source: source,
              isMocked: isMocked,
              capturedAt: capturedAt,
              baseVersion: state.valueOrNull?.inspection.version,
            ),
      );

  /// Lets the workspace react immediately after a successful photo mutation.
  void photoChanged(String categoryWire) {
    if (!state.hasValue) return;
    final next = _optimisticCompleteness(
      sectionCode: 'PHOTOS',
      textMatch: categoryWire,
    );
    if (next != null) _applyOptimisticCompleteness(next);
    ref.invalidate(completenessProvider(arg));
  }

  /// Flushes pending edits, then submits. Refuses if the flush did not land,
  /// since submitting would send an inspection the inspector believes is
  /// complete but the server does not.
  Future<Inspection> submit() async {
    _debounce?.cancel();
    await flush();

    if (!state.hasValue) {
      throw const ApiError(
        code: ApiErrorCode.unknown,
        message: 'The inspection is not loaded.',
      );
    }

    if (_dirty.isNotEmpty) {
      throw ApiError(
        code: ApiErrorCode.unknown,
        message: '${_dirty.length} change(s) could not be saved. Resolve the '
            'save error before submitting.',
      );
    }

    final result = await ref.read(inspectionsRepositoryProvider).submit(arg);
    await _apply(result);

    ref.invalidate(inspectionListProvider);
    ref.invalidate(dashboardProvider);
    return _s.inspection;
  }
}

final inspectionWorkspaceProvider = AsyncNotifierProvider.autoDispose
    .family<InspectionWorkspaceNotifier, WorkspaceState, String>(
  InspectionWorkspaceNotifier.new,
);

/// Server-calculated completeness.
///
/// Uses `ref.read`, not `ref.watch`, on the workspace: watching created a
/// cycle with the workspace's own `ref.invalidate(completenessProvider(...))`
/// and rebuilt the progress bar on every keystroke.
final completenessProvider = FutureProvider.autoDispose
    .family<CompletenessResult, String>((ref, id) async {
  final cached =
      ref.read(inspectionWorkspaceProvider(id)).valueOrNull?.completeness;
  if (cached != null) return cached;

  return ref.read(inspectionsRepositoryProvider).completeness(id);
});
