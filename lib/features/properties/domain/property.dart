import '../../../core/utils/json_read.dart';

/// Property type values the backend validates. Wire values are exact and
/// case-sensitive.
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
        id: J.asString(j['id']) ?? '',
        status: J.asString(j['status']) ?? '',
        inspectionNumber: J.asString(j['inspectionNumber']),
        loanReference: J.asString(j['loanReference']),
        clientName: J.asString(j['clientName']),
        createdAt: J.asDate(j['createdAt']),
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
    this.plotNumber,
    this.titleNumber,
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

  // Administrative location hierarchy, most specific first.
  final String? province;
  final String? district;
  final String? sector;
  final String? cell;
  final String? villageStreet;

  /// Cadastral parcel number. Displayed to inspectors as "Plot number".
  final String? plotNumber;

  /// Land title reference. Displayed to inspectors as "UPI" — the Rwandan
  /// Unique Parcel Identifier.
  ///
  /// The field name stays `titleNumber` throughout the model and API layer.
  /// Only the UI label says UPI; renaming would break the backend contract.
  final String? titleNumber;

  /// Prisma `Decimal` columns, so these arrive as JSON **strings**
  /// ("51.5077"). Read through [J.asDouble], which accepts either form —
  /// casting with `as num?` throws.
  final double? latitude;
  final double? longitude;

  final DateTime? createdAt;
  final List<PropertyInspectionSummary> recentInspections;

  /// "KG 11 Ave, Nyagatovu, Kimironko, Gasabo, Kigali"
  ///
  /// Source of truth for administrative-location formatting. Blank and null
  /// parts are dropped, so a property with no `villageStreet` never renders
  /// "KG 11 Ave, , Gasabo".
  String get locationSummary {
    final parts = <String?>[villageStreet, cell, sector, district, province]
        .map((p) => p?.trim())
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? 'Location not recorded' : parts.join(', ');
  }

  /// "Plot 1234 · UPI 1/03/07/04/1234", omitting whichever is absent.
  ///
  /// Used on the property list card, where a parcel is usually identified by
  /// its registration reference rather than by its name. Returns an empty
  /// string when neither is recorded — callers should guard with
  /// [hasLandRegistration].
  String get landRegistrationSummary {
    final parts = <String>[
      if (plotNumber?.trim().isNotEmpty ?? false) 'Plot ${plotNumber!.trim()}',
      if (titleNumber?.trim().isNotEmpty ?? false) 'UPI ${titleNumber!.trim()}',
    ];
    return parts.join(' · ');
  }

  /// True when at least one land-registration reference is on file.
  bool get hasLandRegistration =>
      (plotNumber?.trim().isNotEmpty ?? false) ||
      (titleNumber?.trim().isNotEmpty ?? false);

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Property.fromJson(Map<String, dynamic> j) {
    final inspections = j['inspections'] ?? j['recentInspections'];
    final branch = J.asMap(j['branch']);

    return Property(
      id: J.asString(j['id']) ?? '',
      reference: J.asString(j['reference']) ?? '',
      name: J.asString(j['name']) ?? '',
      propertyType: PropertyType.tryParse(J.asString(j['propertyType'])),
      ownerClientName: J.asString(j['ownerClientName']) ?? '',
      branchId: J.asString(j['branchId']),
      branchName: J.asString(branch?['name']) ?? J.asString(j['branchName']),
      province: J.asString(j['province']),
      district: J.asString(j['district']),
      sector: J.asString(j['sector']),
      cell: J.asString(j['cell']),
      villageStreet: J.asString(j['villageStreet']),
      plotNumber: J.asString(j['plotNumber']),
      titleNumber: J.asString(j['titleNumber']),
      latitude: J.asDouble(j['latitude']),
      longitude: J.asDouble(j['longitude']),
      createdAt: J.asDate(j['createdAt']),
      recentInspections: inspections is List
          ? inspections
              .whereType<Map<String, dynamic>>()
              .map(PropertyInspectionSummary.fromJson)
              .toList()
          : const <PropertyInspectionSummary>[],
    );
  }
}

/// Body for `POST /api/v1/properties`.
///
/// Blank optional values are omitted rather than sent as empty strings. The
/// backend trims and stores empty as null, so either would work — but the API
/// runs `forbidNonWhitelisted: true`, and omitting is the safer habit.
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
    this.plotNumber,
    this.titleNumber,
  });

  /// Optional. Omitted, the backend generates PROP-YYYY-XXXX.
  final String? reference;

  final String name;
  final PropertyType propertyType;
  final String ownerClientName;
  final String province;
  final String district;
  final String sector;
  final String cell;
  final String? villageStreet;
  final String? plotNumber;
  final String? titleNumber;

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

    void put(String key, String? value) {
      final s = value?.trim();
      if (s != null && s.isNotEmpty) j[key] = s;
    }

    put('reference', reference);
    put('villageStreet', villageStreet);
    // Exact API names. Never plot_number, upi or title_number.
    put('plotNumber', plotNumber);
    put('titleNumber', titleNumber);

    return j;
  }
}

/// Body for `PATCH /api/v1/properties/:id`.
///
/// Distinguishes "leave unchanged" from "clear this value":
///
///   * a null field is omitted entirely — the server leaves it alone
///   * an empty string is sent as `''`, which the backend stores as null
///
/// A `toJson` that dropped empty strings would make it impossible to clear a
/// plot number once entered — the field would appear blank in the form while
/// silently keeping its old value on the server.
class UpdatePropertyRequest {
  const UpdatePropertyRequest({
    this.name,
    this.propertyType,
    this.ownerClientName,
    this.province,
    this.district,
    this.sector,
    this.cell,
    this.villageStreet,
    this.plotNumber,
    this.titleNumber,
  });

  final String? name;
  final PropertyType? propertyType;
  final String? ownerClientName;
  final String? province;
  final String? district;
  final String? sector;
  final String? cell;
  final String? villageStreet;
  final String? plotNumber;
  final String? titleNumber;

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{};

    void put(String key, String? value) {
      if (value == null) return; // not being changed
      j[key] = value.trim(); // may be '' — the backend maps that to null
    }

    put('name', name);
    if (propertyType != null) j['propertyType'] = propertyType!.wire;
    put('ownerClientName', ownerClientName);
    put('province', province);
    put('district', district);
    put('sector', sector);
    put('cell', cell);
    put('villageStreet', villageStreet);
    put('plotNumber', plotNumber);
    put('titleNumber', titleNumber);

    return j;
  }
}
