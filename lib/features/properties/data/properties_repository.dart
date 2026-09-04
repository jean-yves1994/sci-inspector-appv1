import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../domain/property.dart';

class PropertiesRepository {
  const PropertiesRepository(this._api);
  final ApiClient _api;

  /// Backend search already covers reference/name/owner/type/location, so a
  /// single term is forwarded rather than reimplemented client-side.
  Future<Paginated<Property>> list({
    String? search,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final q = <String, dynamic>{'page': page, 'pageSize': limit};
    final s = search?.trim();
    if (s != null && s.isNotEmpty) q['search'] = s;

    final d = await _api.get<Map<String, dynamic>>('/properties',
        query: q, cancelToken: cancelToken);
    return Paginated.fromJson<Property>(d, Property.fromJson);
  }

  Future<Property> byId(String id) async {
    final d = await _api.get<Map<String, dynamic>>('/properties/$id');
    return Property.fromJson(unwrap(d));
  }

  Future<Property> create(CreatePropertyRequest r) async {
    final d =
        await _api.post<Map<String, dynamic>>('/properties', body: r.toJson());
    return Property.fromJson(unwrap(d));
  }
}

final propertiesRepositoryProvider = Provider<PropertiesRepository>(
    (ref) => PropertiesRepository(ref.watch(apiClientProvider)));
