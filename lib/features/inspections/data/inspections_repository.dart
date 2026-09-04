import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../domain/inspection.dart';
import '../domain/inspection_status.dart';

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
    final q = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (assignedToMe) 'assignedToMe': true,
    };
    final s = search?.trim();
    if (s != null && s.isNotEmpty) q['search'] = s;
    if (status != null) q['status'] = status.wire;

    final d = await _api.get<Map<String, dynamic>>('/inspections',
        query: q, cancelToken: cancelToken);
    return Paginated.fromJson<InspectionListItem>(
        d, InspectionListItem.fromJson);
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
  /// No inspectorId or reviewerId is ever sent.
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
      body['dueDate'] =
          '${dueDate.year.toString().padLeft(4, '0')}-'
          '${dueDate.month.toString().padLeft(2, '0')}-'
          '${dueDate.day.toString().padLeft(2, '0')}';
    }
    final n = notes?.trim();
    if (n != null && n.isNotEmpty) body['notes'] = n;

    final d = await _api.post<Map<String, dynamic>>('/inspections', body: body);
    return Inspection.fromJson(unwrap(d));
  }

  Future<Inspection> start(String id) async {
    final d =
        await _api.post<Map<String, dynamic>>('/inspections/$id/start');
    return Inspection.fromJson(unwrap(d));
  }

  Future<Inspection> saveValues({
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
    return Inspection.fromJson(unwrap(d));
  }

  Future<Inspection> saveAssessment({
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
    return Inspection.fromJson(unwrap(d));
  }

  Future<Inspection> saveOwner({
    required String id,
    required InspectionOwner owner,
    required int baseVersion,
  }) async {
    final d = await _api.patch<Map<String, dynamic>>(
      '/inspections/$id/owner',
      body: <String, dynamic>{...owner.toJson(), 'baseVersion': baseVersion},
    );
    return Inspection.fromJson(unwrap(d));
  }

  Future<Inspection> saveValuation({
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
    return Inspection.fromJson(unwrap(d));
  }

  Future<Inspection> captureLocation({
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
    return Inspection.fromJson(unwrap(d));
  }

  /// The backend decides SUBMIT vs RESUBMIT from the current status, and
  /// re-validates completeness server-side immediately before accepting.
  Future<Inspection> submit(String id) async {
    final d =
        await _api.post<Map<String, dynamic>>('/inspections/$id/submit');
    return Inspection.fromJson(unwrap(d));
  }
}

final inspectionsRepositoryProvider = Provider<InspectionsRepository>(
    (ref) => InspectionsRepository(ref.watch(apiClientProvider)));
