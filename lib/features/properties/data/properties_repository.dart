import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/network/pagination_params.dart';
import '../domain/property.dart';

class PropertiesRepository {
  const PropertiesRepository(this._api);

  final ApiClient _api;

  /// Backend search covers reference, name, owner/client, type and the full
  /// location hierarchy, so a single term is forwarded rather than
  /// reimplemented client-side.
  Future<Paginated<Property>> list({
    String? search,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final d = await _api.get<Map<String, dynamic>>(
      '/properties',
      query: PaginationParams.build(
        page: page,
        pageSize: limit,
        extra: <String, dynamic>{'search': search},
      ),
      cancelToken: cancelToken,
    );
    return Paginated.fromJson<Property>(d, Property.fromJson);
  }

  Future<Property> byId(String id) async {
    final d = await _api.get<Map<String, dynamic>>('/properties/$id');
    return Property.fromJson(unwrap(d));
  }

  /// Returns the SERVER's property, including `plotNumber` and `titleNumber`.
  ///
  /// Callers must use this object rather than reconstructing one locally —
  /// a locally built copy would lose the generated `reference` and both land
  /// registration fields, which is exactly the create-then-inspect bug the
  /// spec warns about.
  Future<Property> create(CreatePropertyRequest request) async {
    final d = await _api.post<Map<String, dynamic>>(
      '/properties',
      body: request.toJson(),
    );
    return Property.fromJson(unwrap(d));
  }

  Future<Property> update(String id, UpdatePropertyRequest request) async {
    final d = await _api.patch<Map<String, dynamic>>(
      '/properties/$id',
      body: request.toJson(),
    );
    return Property.fromJson(unwrap(d));
  }
}

final propertiesRepositoryProvider = Provider<PropertiesRepository>(
  (ref) => PropertiesRepository(ref.watch(apiClientProvider)),
);
