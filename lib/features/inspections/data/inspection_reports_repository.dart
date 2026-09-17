import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class InspectionReportsRepository {
  const InspectionReportsRepository(this._api);

  final ApiClient _api;

  Future<String> finalReportDownloadUrl(String inspectionId) async {
    final inspection = await _api.get<Map<String, dynamic>>('/inspections/$inspectionId');
    final reportsRaw = inspection['reports'];
    final reports = reportsRaw is List ? reportsRaw.whereType<Map<String, dynamic>>() : const <Map<String, dynamic>>[];

    final finalReports = reports.where((report) {
      final number = report['reportNumber']?.toString() ?? '';
      return number.isNotEmpty && !number.startsWith('DRF-');
    }).toList();

    if (finalReports.isEmpty) {
      throw Exception('The final report is not available yet.');
    }

    finalReports.sort((a, b) {
      final av = int.tryParse(a['version']?.toString() ?? '') ?? 0;
      final bv = int.tryParse(b['version']?.toString() ?? '') ?? 0;
      return bv.compareTo(av);
    });

    final reportId = finalReports.first['id']?.toString();
    if (reportId == null || reportId.isEmpty) {
      throw Exception('The final report could not be located.');
    }

    final result = await _api.get<Map<String, dynamic>>('/reports/$reportId/download');
    final url = result['url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('The final report download URL was not returned.');
    }
    return url;
  }
}

final inspectionReportsRepositoryProvider = Provider<InspectionReportsRepository>(
  (ref) => InspectionReportsRepository(ref.watch(apiClientProvider)),
);
