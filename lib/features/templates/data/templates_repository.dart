import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../domain/template.dart';

class TemplatesRepository {
  const TemplatesRepository(this._api);
  final ApiClient _api;

  Future<InspectionTemplate> byId(String id) async {
    final d = await _api.get<Map<String, dynamic>>('/templates/$id');
    return InspectionTemplate.fromJson(unwrap(d));
  }

  Future<InspectionTemplate> defaultTemplate() async {
    final d = await _api.get<Map<String, dynamic>>('/templates/default');
    return InspectionTemplate.fromJson(unwrap(d));
  }
}

final templatesRepositoryProvider = Provider<TemplatesRepository>(
    (ref) => TemplatesRepository(ref.watch(apiClientProvider)));
