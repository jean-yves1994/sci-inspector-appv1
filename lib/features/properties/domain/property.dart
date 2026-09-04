/// Property type values the backend validates. Wire values are exact.
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
    for (final t in PropertyType.values) {
      if (t.wire.toLowerCase() == v.toLowerCase()) return t;
    }
    return null;
  }
}

class PropertyInspectionSummary {
  const PropertyInspectionSummary({
    required this.id,
    required this.status,
    this.inspectionNumber,
    this.loanReference,
    this.clientName,
    this.createdAt,
  });

  final String id;
  final String status;
  final String? inspectionNumber;
  final String? loanReference;
  final String? clientName;
  final DateTime? createdAt;

  factory PropertyInspectionSummary.fromJson(Map<String, dynamic> j) =>
      PropertyInspectionSummary(
        id: j['id'] as String,
        status: j['status'] as String? ?? '',
        inspectionNumber: j['inspectionNumber'] as String?,
        loanReference: j['loanReference'] as String?,
        clientName: j['clientName'] as String?,
        createdAt: j['createdAt'] is String
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

class Property {
  const Property({
    required this.id,
    required this.reference,
    required this.name,
    required this.ownerClientName,
    this.propertyType,
    this.branchId,
    this.branchName,
    this.province,
    this.district,
    this.sector,
    this.cell,
    this.villageStreet,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.recentInspections = const <PropertyInspectionSummary>[],
  });

  final String id;
  final String reference;
  final String name;
  final PropertyType? propertyType;
  final String ownerClientName;
  final String? branchId;
  final String? branchName;
  final String? province;
  final String? district;
  final String? sector;
  final String? cell;
  final String? villageStreet;

  /// Legacy, read-only. Never collected during basic property creation.
  final double? latitude;
  final double? longitude;

  final DateTime? createdAt;
  final List<PropertyInspectionSummary> recentInspections;

  String get locationSummary {
    final parts = <String?>[villageStreet, cell, sector, district, province]
        .where((p) => p != null && p.trim().isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? 'Location not recorded' : parts.join(', ');
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Property.fromJson(Map<String, dynamic> j) {
    final insp = j['inspections'] ?? j['recentInspections'];
    return Property(
      id: j['id'] as String,
      reference: j['reference'] as String? ?? '',
      name: j['name'] as String? ?? '',
      propertyType: PropertyType.tryParse(j['propertyType'] as String?),
      ownerClientName: j['ownerClientName'] as String? ?? '',
      branchId: j['branchId'] as String?,
      branchName: j['branch'] is Map<String, dynamic>
          ? (j['branch'] as Map<String, dynamic>)['name'] as String?
          : j['branchName'] as String?,
      province: j['province'] as String?,
      district: j['district'] as String?,
      sector: j['sector'] as String?,
      cell: j['cell'] as String?,
      villageStreet: j['villageStreet'] as String?,
      latitude: _d(j['latitude']),
      longitude: _d(j['longitude']),
      createdAt: j['createdAt'] is String
          ? DateTime.tryParse(j['createdAt'] as String)
          : null,
      recentInspections: insp is List
          ? insp
              .whereType<Map<String, dynamic>>()
              .map(PropertyInspectionSummary.fromJson)
              .toList()
          : const <PropertyInspectionSummary>[],
    );
  }

  static double? _d(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// POST /properties body.
///
/// The backend uses forbidNonWhitelisted:true, so nulls and client-only
/// fields must never be serialised.
class CreatePropertyRequest {
  const CreatePropertyRequest({
    required this.name,
    required this.propertyType,
    required this.ownerClientName,
    required this.province,
    required this.district,
    required this.sector,
    required this.cell,
    this.reference,
    this.villageStreet,
  });

  final String? reference;
  final String name;
  final PropertyType propertyType;
  final String ownerClientName;
  final String province;
  final String district;
  final String sector;
  final String cell;
  final String? villageStreet;

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{
      'name': name.trim(),
      'propertyType': propertyType.wire,
      'ownerClientName': ownerClientName.trim(),
      'province': province.trim(),
      'district': district.trim(),
      'sector': sector.trim(),
      'cell': cell.trim(),
    };
    void put(String k, String? v) {
      final s = v?.trim();
      if (s != null && s.isNotEmpty) j[k] = s;
    }

    put('reference', reference);
    put('villageStreet', villageStreet);
    return j;
  }
}
