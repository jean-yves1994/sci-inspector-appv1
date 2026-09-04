import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/network/pagination_params.dart';
import '../domain/inspection.dart';
import '../domain/inspection_status.dart';

/// What a mutation endpoint actually returned.
///
/// The SCI API does not use one response shape for mutations — verified by
/// probe against the live server:
///
///   POST  /:id/start      -> full inspection aggregate (has `version`)
///   PATCH /:id/owner      -> completeness result       (no `version`)
///   PATCH /:id/valuation  -> completeness result       (no `version`)
///   PATCH /:id/values     -> completeness result       (assumed, same family)
///   PATCH /:id/assessments-> completeness result       (assumed, same family)
///   POST  /:id/location   -> { location, proximity }   (no `version`)
///
/// Blindly calling `Inspection.fromJson` on all of these crashes, because a
/// completeness payload has no `id`. This type lets the caller see what it
/// actually got and react, rather than guessing.
class MutationResult {
  const MutationResult({
    this.inspection,
    this.completeness,
    this.location,
    this.proximity,
  });

  /// Present only when the endpoint returned the full aggregate.
  final Inspection? inspection;

  /// Present when the endpoint returned completeness — most PATCH endpoints
  /// do. Using it avoids a follow-up GET /completeness.
  final CompletenessResult? completeness;

  final InspectionLocation? location;
  final GpsProximity? proximity;

  /// True when the caller must refetch to learn the new version.
  bool get needsRefetch => inspection == null;

  /// Classifies an arbitrary mutation response without throwing.
  factory MutationResult.parse(Map<String, dynamic> json) {
    final body = unwrap(json);

    // A full aggregate is identifiable by `id` + `status`. Requiring both
    // avoids mistaking a sub-resource that happens to carry an id.
    if (body['id'] is String && body['status'] is String) {
      return MutationResult(inspection: Inspection.fromJson(body));
    }

    // Completeness: { complete, percentage, issues, blockingIssues }
    if (body.containsKey('complete') || body.containsKey('percentage')) {
      return MutationResult(
        completeness: CompletenessResult.fromJson(body),
      );
    }

    // Location: { location, proximity }
    if (body.containsKey('location') || body.containsKey('proximity')) {
      final loc = body['location'];
      final prox = body['proximity'];
      return MutationResult(
        location: loc is Map<String, dynamic>
            ? InspectionLocation.fromJson(loc)
            : null,
        proximity: prox is Map<String, dynamic>
            ? GpsProximity.fromJson(prox)
            : null,
      );
    }

    // Unknown shape: report nothing rather than fabricate an Inspection with
    // version 0, which is what corrupted the local state before.
    return const MutationResult();
  }
}

class InspectionsRepository {
  const InspectionsRepository(this._api);

  final ApiClient _api;

  Future<Paginated<InspectionListItem>> list({
    String? search,
    InspectionStatus? status,
    bool assignedToMe = true,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final d = await _api.get<Map<String, dynamic>>(
      '/inspections',
      query: PaginationParams.build(
        page: page,
        pageSize: limit,
        extra: <String, dynamic>{
          if (assignedToMe) 'assignedToMe': true,
          'search': search,
          'status': status?.wire,
        },
      ),
      cancelToken: cancelToken,
    );
    return Paginated.fromJson<InspectionListItem>(
      d,
      InspectionListItem.fromJson,
    );
  }

  Future<Inspection> byId(String id) async {
    final d = await _api.get<Map<String, dynamic>>('/inspections/$id');
    return Inspection.fromJson(unwrap(d));
  }

  Future<CompletenessResult> completeness(String id) async {
    final d =
        await _api.get<Map<String, dynamic>>('/inspections/$id/completeness');
    return CompletenessResult.fromJson(unwrap(d));
  }

  /// Inspectors cannot assign; the backend assigns the creator automatically.
  Future<Inspection> create({
    required String propertyId,
    required String loanReference,
    required String clientName,
    String priority = 'NORMAL',
    DateTime? dueDate,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'propertyId': propertyId,
      'loanReference': loanReference.trim(),
      'clientName': clientName.trim(),
      'priority': priority,
    };
    if (dueDate != null) {
      body['dueDate'] = '${dueDate.year.toString().padLeft(4, '0')}-'
          '${dueDate.month.toString().padLeft(2, '0')}-'
          '${dueDate.day.toString().padLeft(2, '0')}';
    }
    final n = notes?.trim();
    if (n != null && n.isNotEmpty) body['notes'] = n;

    final d = await _api.post<Map<String, dynamic>>('/inspections', body: body);
    return Inspection.fromJson(unwrap(d));
  }

  /// Returns the full aggregate — verified by probe (version=2, IN_PROGRESS).
  Future<Inspection> start(String id) async {
    final d = await _api.post<Map<String, dynamic>>('/inspections/$id/start');
    return Inspection.fromJson(unwrap(d));
  }

  // --------------------------------------------------------- mutations
  // Each returns MutationResult, never a bare Inspection, because the
  // response shape varies by endpoint.

  Future<MutationResult> saveValues({
    required String id,
    required List<InspectionValue> values,
    required int baseVersion,
  }) async {
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/values',
      body: <String, dynamic>{
        'values': values.map((v) => v.toJson()).toList(),
        'baseVersion': baseVersion,
      },
    );
    return MutationResult.parse(d);
  }

  Future<MutationResult> saveAssessment({
    required String id,
    required InspectionAssessment assessment,
    required int baseVersion,
  }) async {
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/assessments',
      body: <String, dynamic>{
        ...assessment.toJson(),
        'baseVersion': baseVersion,
      },
    );
    return MutationResult.parse(d);
  }

  Future<MutationResult> saveOwner({
    required String id,
    required InspectionOwner owner,
    required int baseVersion,
  }) async {
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/owner',
      body: <String, dynamic>{...owner.toJson(), 'baseVersion': baseVersion},
    );
    return MutationResult.parse(d);
  }

  Future<MutationResult> saveValuation({
    required String id,
    required InspectionValuation valuation,
    required int baseVersion,
  }) async {
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/valuation',
      body: <String, dynamic>{
        ...valuation.toJson(),
        'baseVersion': baseVersion,
      },
    );
    return MutationResult.parse(d);
  }

  Future<MutationResult> captureLocation({
    required String id,
    required double latitude,
    required double longitude,
    required int baseVersion,
    double? accuracyM,
    double? altitudeM,
    String source = 'GPS',
    bool isMocked = false,
    DateTime? capturedAt,
  }) async {
    final d = await _api.post<Map<String, dynamic>>(
      '/inspections/$id/location',
      body: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyM != null) 'accuracyM': accuracyM,
        if (altitudeM != null) 'altitudeM': altitudeM,
        'source': source,
        'isMocked': isMocked,
        'capturedAt': (capturedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'baseVersion': baseVersion,
      },
    );
    return MutationResult.parse(d);
  }

  /// The backend decides SUBMIT vs RESUBMIT from the current status, and
  /// re-validates completeness server-side before accepting.
  Future<MutationResult> submit(String id) async {
    final d = await _api.post<Map<String, dynamic>>('/inspections/$id/submit');
    return MutationResult.parse(d);
  }
}

final inspectionsRepositoryProvider = Provider<InspectionsRepository>(
  (ref) => InspectionsRepository(ref.watch(apiClientProvider)),
);
