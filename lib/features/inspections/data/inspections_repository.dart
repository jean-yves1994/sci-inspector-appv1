import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/network/pagination_params.dart';
import '../domain/inspection.dart';
import '../domain/inspection_status.dart';

/// What a mutation returned.
///
/// The API uses several shapes, confirmed by probe:
///
///   POST  /:id/start       -> full aggregate            id, status, version
///   POST  /:id/submit      -> full aggregate            id, status, version
///   PATCH /:id/values      -> completeness (+ version)  no id
///   PATCH /:id/assessments -> completeness (+ version)  no id
///   PATCH /:id/owner       -> completeness (+ version)  no id
///   PATCH /:id/valuation   -> completeness (+ version)  no id
///   POST  /:id/location    -> { location, proximity } (+ version)
///
/// `version` is read independently of the payload shape, so it is picked up
/// whether or not the backend patch that adds it has been deployed.
class MutationResult {
  const MutationResult({
    this.inspection,
    this.completeness,
    this.location,
    this.proximity,
    this.version,
    this.status,
  });

  final Inspection? inspection;
  final CompletenessResult? completeness;
  final InspectionLocation? location;
  final GpsProximity? proximity;
  final int? version;
  final String? status;

  static int? _readVersion(Map<String, dynamic> body) {
    final raw = body['version'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Classifies any response without throwing.
  factory MutationResult.parse(Map<String, dynamic> json) {
    final body = unwrap(json);
    final version = _readVersion(body);
    final status = body['status'] is String ? body['status'] as String : null;

    if (body['id'] is String && body['status'] is String) {
      final inspection = Inspection.fromJson(body);
      return MutationResult(
        inspection: inspection,
        completeness: inspection.completeness,
        version: version ?? inspection.version,
        status: status,
      );
    }

    if (body.containsKey('complete') || body.containsKey('percentage')) {
      return MutationResult(
        completeness: CompletenessResult.fromJson(body),
        version: version,
        status: status,
      );
    }

    if (body.containsKey('location') || body.containsKey('proximity')) {
      final loc = body['location'];
      final prox = body['proximity'];
      return MutationResult(
        location: loc is Map<String, dynamic>
            ? InspectionLocation.fromJson(loc)
            : null,
        proximity:
            prox is Map<String, dynamic> ? GpsProximity.fromJson(prox) : null,
        version: version,
        status: status,
      );
    }

    return MutationResult(version: version, status: status);
  }
}

class InspectionsRepository {
  const InspectionsRepository(this._api);

  final ApiClient _api;

  // ------------------------------------------------------------- reading

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

  /// Reads the authoritative concurrency token for callers that do not have
  /// an active workspace session. Workspace mutations pass their current
  /// version directly, avoiding an extra GET for every edit.
  Future<int> currentVersion(String id) async {
    final inspection = await byId(id);
    return inspection.version;
  }

  Future<CompletenessResult> completeness(String id) async {
    final d =
        await _api.get<Map<String, dynamic>>('/inspections/$id/completeness');
    return CompletenessResult.fromJson(unwrap(d));
  }

  // ------------------------------------------------------------ creating

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

  Future<Inspection> start(String id) async {
    final d = await _api.post<Map<String, dynamic>>('/inspections/$id/start');
    return Inspection.fromJson(unwrap(d));
  }

  // ----------------------------------------------------------- mutations
  //
  // The workspace passes its current server version so ordinary edits do not
  // perform a GET immediately before every PATCH. The optional fallback keeps
  // this repository safe for callers that do not own a workspace session.

  Future<MutationResult> saveValues({
    required String id,
    required List<InspectionValue> values,
    int? baseVersion,
  }) async {
    final version = baseVersion ?? await currentVersion(id);
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/values',
      body: <String, dynamic>{
        'values': values.map((v) => v.toJson()).toList(),
        'baseVersion': version,
      },
    );
    return MutationResult.parse(d);
  }

  Future<MutationResult> saveAssessment({
    required String id,
    required InspectionAssessment assessment,
    int? baseVersion,
  }) async {
    final version = baseVersion ?? await currentVersion(id);
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/assessments',
      body: <String, dynamic>{
        ...assessment.toJson(),
        'baseVersion': version,
      },
    );
    return MutationResult.parse(d);
  }

  Future<MutationResult> saveOwner({
    required String id,
    required InspectionOwner owner,
    int? baseVersion,
  }) async {
    final version = baseVersion ?? await currentVersion(id);
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/owner',
      body: <String, dynamic>{...owner.toJson(), 'baseVersion': version},
    );
    return MutationResult.parse(d);
  }

  Future<MutationResult> saveValuation({
    required String id,
    required InspectionValuation valuation,
    int? baseVersion,
  }) async {
    final version = baseVersion ?? await currentVersion(id);
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/valuation',
      body: <String, dynamic>{
        ...valuation.toJson(),
        'baseVersion': version,
      },
    );
    return MutationResult.parse(d);
  }

  Future<MutationResult> captureLocation({
    required String id,
    required double latitude,
    required double longitude,
    double? accuracyM,
    double? altitudeM,
    String source = 'GPS',
    bool isMocked = false,
    DateTime? capturedAt,
    int? baseVersion,
  }) async {
    final version = baseVersion ?? await currentVersion(id);
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
        'baseVersion': version,
      },
    );
    return MutationResult.parse(d);
  }

  /// The backend decides SUBMIT vs RESUBMIT from the current status and
  /// re-validates completeness server-side before accepting.
  Future<MutationResult> submit(String id) async {
    final d = await _api.post<Map<String, dynamic>>('/inspections/$id/submit');
    return MutationResult.parse(d);
  }
}

final inspectionsRepositoryProvider = Provider<InspectionsRepository>(
  (ref) => InspectionsRepository(ref.watch(apiClientProvider)),
);
