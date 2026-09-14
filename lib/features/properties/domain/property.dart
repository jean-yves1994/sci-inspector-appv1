import '../../../core/utils/json_read.dart';

enum PropertyType {
  residential('Residential'),
  commercial('Commercial'),
  industrial('Industrial'),
  agricultural('Agricultural'),
  land('Land'),
  other('Other');
  const PropertyType(this.wire);
  final String wire;
  String get label => wire;
  static PropertyType? tryParse(String? v) {
    if (v == null) return null;
    for (final t in PropertyType.values) { if (t.wire.toLowerCase() == v.toLowerCase()) return t; }
    return null;
  }
}

class PropertyInspectionSummary {
  const PropertyInspectionSummary({required this.id, required this.status, this.inspectionNumber, this.loanReference, this.clientName, this.createdAt});
  final String id; final String status; final String? inspectionNumber; final String? loanReference; final String? clientName; final DateTime? createdAt;
  factory PropertyInspectionSummary.fromJson(Map<String, dynamic> j) => PropertyInspectionSummary(id: J.asString(j['id']) ?? '', status: J.asString(j['status']) ?? '', inspectionNumber: J.asString(j['inspectionNumber']), loanReference: J.asString(j['loanReference']), clientName: J.asString(j['clientName']), createdAt: J.asDate(j['createdAt']));
}

class Property {
  const Property({required this.id, required this.reference, required this.name, required this.ownerClientName, this.propertyType, this.branchId, this.branchName, this.province, this.district, this.sector, this.cell, this.villageStreet, this.titleNumber, this.latitude, this.longitude, this.createdAt, this.recentInspections = const <PropertyInspectionSummary>[]});
  final String id; final String reference; final String name; final PropertyType? propertyType; final String ownerClientName; final String? branchId; final String? branchName;
  final String? province; final String? district; final String? sector; final String? cell; final String? villageStreet;
  /// UPI / Unique Parcel Identifier. This is the only land identifier exposed by the current workflow.
  final String? titleNumber;
  final double? latitude; final double? longitude; final DateTime? createdAt; final List<PropertyInspectionSummary> recentInspections;
  String get locationSummary { final parts = <String?>[villageStreet, cell, sector, district, province].map((p) => p?.trim()).where((p) => p != null && p.isNotEmpty).cast<String>().toList(); return parts.isEmpty ? 'Location not recorded' : parts.join(', '); }
  String get landRegistrationSummary => titleNumber?.trim().isNotEmpty ?? false ? 'UPI ${titleNumber!.trim()}' : '';
  bool get hasLandRegistration => titleNumber?.trim().isNotEmpty ?? false;
  bool get hasCoordinates => latitude != null && longitude != null;
  factory Property.fromJson(Map<String, dynamic> j) {
    final inspections = j['inspections'] ?? j['recentInspections']; final branch = J.asMap(j['branch']);
    return Property(id: J.asString(j['id']) ?? '', reference: J.asString(j['reference']) ?? '', name: J.asString(j['name']) ?? '', propertyType: PropertyType.tryParse(J.asString(j['propertyType'])), ownerClientName: J.asString(j['ownerClientName']) ?? '', branchId: J.asString(j['branchId']), branchName: J.asString(branch?['name']) ?? J.asString(j['branchName']), province: J.asString(j['province']), district: J.asString(j['district']), sector: J.asString(j['sector']), cell: J.asString(j['cell']), villageStreet: J.asString(j['villageStreet']), titleNumber: J.asString(j['titleNumber']), latitude: J.asDouble(j['latitude']), longitude: J.asDouble(j['longitude']), createdAt: J.asDate(j['createdAt']), recentInspections: inspections is List ? inspections.whereType<Map<String, dynamic>>().map(PropertyInspectionSummary.fromJson).toList() : const <PropertyInspectionSummary>[]);
  }
}

class CreatePropertyRequest {
  const CreatePropertyRequest({required this.name, required this.propertyType, required this.ownerClientName, required this.province, required this.district, required this.sector, required this.cell, this.villageStreet, this.titleNumber});
  final String name; final PropertyType propertyType; final String ownerClientName; final String province; final String district; final String sector; final String cell; final String? villageStreet; final String? titleNumber;
  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{'name': name.trim(), 'propertyType': propertyType.wire, 'ownerClientName': ownerClientName.trim(), 'province': province.trim(), 'district': district.trim(), 'sector': sector.trim(), 'cell': cell.trim()};
    void put(String key, String? value) { final s = value?.trim(); if (s != null && s.isNotEmpty) j[key] = s; }
    put('villageStreet', villageStreet); put('titleNumber', titleNumber); return j;
  }
}

class UpdatePropertyRequest {
  const UpdatePropertyRequest({this.name, this.propertyType, this.ownerClientName, this.province, this.district, this.sector, this.cell, this.villageStreet, this.titleNumber});
  final String? name; final PropertyType? propertyType; final String? ownerClientName; final String? province; final String? district; final String? sector; final String? cell; final String? villageStreet; final String? titleNumber;
  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{};
    void put(String key, String? value) { if (value != null) j[key] = value.trim(); }
    put('name', name); if (propertyType != null) j['propertyType'] = propertyType!.wire; put('ownerClientName', ownerClientName); put('province', province); put('district', district); put('sector', sector); put('cell', cell); put('villageStreet', villageStreet); put('titleNumber', titleNumber); return j;
  }
}
