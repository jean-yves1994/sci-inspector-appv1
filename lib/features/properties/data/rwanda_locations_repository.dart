import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';

class RwandaLocation {
  const RwandaLocation({required this.code, required this.name});
  final String code;
  final String name;
  factory RwandaLocation.fromJson(Map<String, dynamic> json) => RwandaLocation(code: json['code'].toString(), name: json['name'] as String);
  Map<String, dynamic> toJson() => {'code': code, 'name': name};
}

class RwandaLocationsRepository {
  RwandaLocationsRepository(this._api);
  final ApiClient _api;
  final Map<String, List<RwandaLocation>> _memory = {};

  Future<List<RwandaLocation>> provinces() => _load('provinces', '/locations/provinces');
  Future<List<RwandaLocation>> districts(String provinceCode) => _load('districts:$provinceCode', '/locations/districts', {'provinceCode': provinceCode});
  Future<List<RwandaLocation>> sectors(String districtCode) => _load('sectors:$districtCode', '/locations/sectors', {'districtCode': districtCode});
  Future<List<RwandaLocation>> cells(String sectorCode) => _load('cells:$sectorCode', '/locations/cells', {'sectorCode': sectorCode});

  Future<List<RwandaLocation>> _load(String key, String path, [Map<String, dynamic>? query]) async {
    if (_memory.containsKey(key)) return _memory[key]!;
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _api.get<Map<String, dynamic>>(path, query: query);
      final raw = response['items'];
      if (raw is! List) throw const FormatException('Invalid location response');
      final items = raw.whereType<Map<String, dynamic>>().map(RwandaLocation.fromJson).toList(growable: false);
      _memory[key] = items;
      await prefs.setString('sci_location_cache_$key', jsonEncode(items.map((e) => e.toJson()).toList()));
      return items;
    } catch (_) {
      final cached = prefs.getString('sci_location_cache_$key');
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached);
      if (decoded is! List) rethrow;
      final items = decoded.whereType<Map<String, dynamic>>().map(RwandaLocation.fromJson).toList(growable: false);
      _memory[key] = items;
      return items;
    }
  }
}

final rwandaLocationsRepositoryProvider = Provider<RwandaLocationsRepository>((ref) => RwandaLocationsRepository(ref.watch(apiClientProvider)));
