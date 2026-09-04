import '../../templates/domain/template.dart';
import 'inspection_status.dart';

/// A saved value for one template field. Only ONE value* key is serialised,
/// chosen by field type.
class InspectionValue {
  const InspectionValue({
    required this.fieldId,
    this.valueText,
    this.valueNumber,
    this.valueBool,
    this.valueDate,
    this.valueJson,
  });

  final String fieldId;
  final String? valueText;
  final double? valueNumber;
  final bool? valueBool;
  final DateTime? valueDate;
  final List<String>? valueJson;

  bool get isEmpty =>
      (valueText == null || valueText!.trim().isEmpty) &&
      valueNumber == null &&
      valueBool == null &&
      valueDate == null &&
      (valueJson == null || valueJson!.isEmpty);

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{'fieldId': fieldId};
    if (valueText != null) j['valueText'] = valueText;
    if (valueNumber != null) j['valueNumber'] = valueNumber;
    if (valueBool != null) j['valueBool'] = valueBool;
    if (valueDate != null) {
      j['valueDate'] = valueDate!.toUtc().toIso8601String();
    }
    if (valueJson != null) j['valueJson'] = valueJson;
    return j;
  }

  factory InspectionValue.fromJson(Map<String, dynamic> j) {
    final raw = j['valueJson'];
    return InspectionValue(
      fieldId: j['fieldId'] as String? ?? j['templateFieldId'] as String? ?? '',
      valueText: j['valueText'] as String?,
      valueNumber: (j['valueNumber'] as num?)?.toDouble(),
      valueBool: j['valueBool'] as bool?,
      valueDate: j['valueDate'] is String
          ? DateTime.tryParse(j['valueDate'] as String)
          : null,
      valueJson: raw is List
          ? raw.map((dynamic e) => e.toString()).toList()
          : null,
    );
  }

  /// Builds the correctly-typed value for a given field.
  static InspectionValue forField(TemplateField f, Object? raw) {
    switch (f.type) {
      case FieldType.number:
      case FieldType.currency:
        return InspectionValue(
          fieldId: f.id,
          valueNumber: raw is num
              ? raw.toDouble()
              : double.tryParse(raw?.toString() ?? ''),
        );
      case FieldType.boolean:
        return InspectionValue(fieldId: f.id, valueBool: raw as bool?);
      case FieldType.date:
        return InspectionValue(fieldId: f.id, valueDate: raw as DateTime?);
      case FieldType.multiSelect:
        return InspectionValue(
          fieldId: f.id,
          valueJson: raw is List<String> ? raw : const <String>[],
        );
      case FieldType.text:
      case FieldType.textarea:
      case FieldType.select:
      case FieldType.phone:
      case FieldType.email:
      case FieldType.nationalId:
      case FieldType.unknown:
        return InspectionValue(fieldId: f.id, valueText: raw?.toString());
    }
  }
}

enum ConditionRating {
  critical('CRITICAL', 1, 'Very Poor'),
  poor('POOR', 2, 'Poor'),
  fair('FAIR', 3, 'Fair'),
  good('GOOD', 4, 'Good'),
  excellent('EXCELLENT', 5, 'Excellent');

  const ConditionRating(this.wire, this.rating, this.label);
  final String wire;
  final int rating;
  final String label;

  static ConditionRating? fromRating(int? r) {
    if (r == null) return null;
    for (final c in ConditionRating.values) {
      if (c.rating == r) return c;
    }
    return null;
  }
}

class InspectionAssessment {
  const InspectionAssessment({
    required this.categoryCode,
    required this.categoryName,
    this.rating,
    this.condition,
    this.notes,
  });

  final String categoryCode;
  final String categoryName;
  final int? rating;
  final String? condition;
  final String? notes;

  factory InspectionAssessment.fromJson(Map<String, dynamic> j) =>
      InspectionAssessment(
        categoryCode: j['categoryCode'] as String? ?? '',
        categoryName: j['categoryName'] as String? ?? '',
        rating: (j['rating'] as num?)?.toInt(),
        condition: j['condition'] as String?,
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'categoryCode': categoryCode,
        'categoryName': categoryName,
        if (rating != null) 'rating': rating,
        if (condition != null) 'condition': condition,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}

class InspectionOwner {
  const InspectionOwner({
    this.fullName,
    this.nationalId,
    this.phone,
    this.email,
    this.occupancyStatus,
    this.ownershipType,
  });

  final String? fullName;
  final String? nationalId;
  final String? phone;
  final String? email;
  final String? occupancyStatus;
  final String? ownershipType;

  static const List<String> occupancyOptions = <String>[
    'OWNER_OCCUPIED', 'TENANT_OCCUPIED', 'VACANT',
    'PARTIALLY_OCCUPIED', 'UNDER_CONSTRUCTION',
  ];

  static const List<String> ownershipOptions = <String>[
    'FREEHOLD', 'LEASEHOLD', 'CUSTOMARY', 'CO_OWNERSHIP', 'COMPANY_OWNED',
  ];

  static String humanise(String v) {
    if (v.isEmpty) return '';
    final parts = v.toLowerCase().split('_');
    return parts.first[0].toUpperCase() +
        parts.first.substring(1) +
        (parts.length > 1 ? ' ${parts.sublist(1).join(' ')}' : '');
  }

  factory InspectionOwner.fromJson(Map<String, dynamic> j) => InspectionOwner(
        fullName: j['fullName'] as String?,
        nationalId: j['nationalId'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        occupancyStatus: j['occupancyStatus'] as String?,
        ownershipType: j['ownershipType'] as String?,
      );

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{};
    void put(String k, String? v) {
      final s = v?.trim();
      if (s != null && s.isNotEmpty) j[k] = s;
    }

    put('fullName', fullName);
    put('nationalId', nationalId);
    put('phone', phone);
    put('email', email);
    put('occupancyStatus', occupancyStatus);
    put('ownershipType', ownershipType);
    return j;
  }
}

class InspectionValuation {
  const InspectionValuation({
    this.currency = 'RWF',
    this.marketValue,
    this.forcedSaleValue,
    this.replacementCost,
    this.rentalEstimate,
    this.comments,
  });

  /// Backend default is RWF. Never "RF".
  final String currency;
  final double? marketValue;
  final double? forcedSaleValue;
  final double? replacementCost;
  final double? rentalEstimate;
  final String? comments;

  factory InspectionValuation.fromJson(Map<String, dynamic> j) =>
      InspectionValuation(
        currency: j['currency'] as String? ?? 'RWF',
        marketValue: (j['marketValue'] as num?)?.toDouble(),
        forcedSaleValue: (j['forcedSaleValue'] as num?)?.toDouble(),
        replacementCost: (j['replacementCost'] as num?)?.toDouble(),
        rentalEstimate: (j['rentalEstimate'] as num?)?.toDouble(),
        comments: j['comments'] as String?,
      );

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{'currency': currency};
    if (marketValue != null) j['marketValue'] = marketValue;
    if (forcedSaleValue != null) j['forcedSaleValue'] = forcedSaleValue;
    if (replacementCost != null) j['replacementCost'] = replacementCost;
    if (rentalEstimate != null) j['rentalEstimate'] = rentalEstimate;
    final c = comments?.trim();
    if (c != null && c.isNotEmpty) j['comments'] = c;
    return j;
  }
}

class InspectionLocation {
  const InspectionLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.altitudeM,
    this.source,
    this.isMocked,
    this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? altitudeM;
  final String? source;
  final bool? isMocked;
  final DateTime? capturedAt;

  factory InspectionLocation.fromJson(Map<String, dynamic> j) =>
      InspectionLocation(
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        accuracyM: (j['accuracyM'] as num?)?.toDouble(),
        altitudeM: (j['altitudeM'] as num?)?.toDouble(),
        source: j['source'] as String?,
        isMocked: j['isMocked'] as bool?,
        capturedAt: j['capturedAt'] is String
            ? DateTime.tryParse(j['capturedAt'] as String)
            : null,
      );
}

/// Server-calculated GPS proximity. Never recomputed on the client.
class GpsProximity {
  const GpsProximity({this.distanceM, this.verdict, this.withinTolerance});

  final double? distanceM;
  final String? verdict;
  final bool? withinTolerance;

  factory GpsProximity.fromJson(Map<String, dynamic> j) => GpsProximity(
        distanceM: (j['distanceM'] as num?)?.toDouble() ??
            (j['distanceMeters'] as num?)?.toDouble(),
        verdict: j['verdict'] as String? ?? j['status'] as String?,
        withinTolerance: j['withinTolerance'] as bool?,
      );
}

class CompletenessIssue {
  const CompletenessIssue({
    required this.message,
    this.code,
    this.sectionCode,
    this.fieldCode,
    this.blocking = true,
  });

  final String message;
  final String? code;
  final String? sectionCode;
  final String? fieldCode;
  final bool blocking;

  factory CompletenessIssue.fromJson(Map<String, dynamic> j,
          {bool blocking = true}) =>
      CompletenessIssue(
        message: j['message'] as String? ??
            j['description'] as String? ??
            j['code'] as String? ??
            'Requirement outstanding',
        code: j['code'] as String?,
        sectionCode: j['sectionCode'] as String?,
        fieldCode: j['fieldCode'] as String?,
        blocking: j['blocking'] as bool? ?? blocking,
      );
}

class CompletenessResult {
  const CompletenessResult({
    required this.complete,
    required this.percentage,
    this.issues = const <CompletenessIssue>[],
    this.blockingIssues = const <CompletenessIssue>[],
  });

  final bool complete;
  final int percentage;
  final List<CompletenessIssue> issues;
  final List<CompletenessIssue> blockingIssues;

  /// Prefer blocking issues; fall back to all issues.
  List<CompletenessIssue> get outstanding =>
      blockingIssues.isNotEmpty ? blockingIssues : issues;

  factory CompletenessResult.fromJson(Map<String, dynamic> j) {
    List<CompletenessIssue> parse(Object? raw, bool blocking) => raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map((m) => CompletenessIssue.fromJson(m, blocking: blocking))
            .toList()
        : const <CompletenessIssue>[];

    return CompletenessResult(
      complete: j['complete'] as bool? ?? false,
      percentage: (j['percentage'] as num?)?.toInt() ?? 0,
      issues: parse(j['issues'], false),
      blockingIssues: parse(j['blockingIssues'], true),
    );
  }
}

class InspectionComment {
  const InspectionComment({required this.body, this.author, this.createdAt});

  final String body;
  final String? author;
  final DateTime? createdAt;

  factory InspectionComment.fromJson(Map<String, dynamic> j) {
    final author = j['author'];
    return InspectionComment(
      body: j['body'] as String? ??
          j['message'] as String? ??
          j['comment'] as String? ??
          j['reason'] as String? ??
          '',
      author: author is Map<String, dynamic>
          ? '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim()
          : author as String?,
      createdAt: j['createdAt'] is String
          ? DateTime.tryParse(j['createdAt'] as String)
          : null,
    );
  }
}

/// Full inspection aggregate returned by GET /inspections/:id.
class Inspection {
  const Inspection({
    required this.id,
    required this.status,
    required this.priority,
    required this.version,
    this.inspectionNumber,
    this.loanReference,
    this.clientName,
    this.propertyId,
    this.propertyReference,
    this.propertyName,
    this.templateId,
    this.dueDate,
    this.submittedAt,
    this.reviewerName,
    this.template,
    this.values = const <InspectionValue>[],
    this.assessments = const <InspectionAssessment>[],
    this.owner,
    this.valuation,
    this.locations = const <InspectionLocation>[],
    this.proximity,
    this.completeness,
    this.comments = const <InspectionComment>[],
    this.corrections = const <InspectionComment>[],
  });

  final String id;
  final InspectionStatus status;
  final InspectionPriority priority;

  /// Optimistic concurrency token sent as baseVersion on every mutation.
  final int version;

  final String? inspectionNumber;
  final String? loanReference;
  final String? clientName;
  final String? propertyId;
  final String? propertyReference;
  final String? propertyName;
  final String? templateId;
  final DateTime? dueDate;
  final DateTime? submittedAt;
  final String? reviewerName;

  final InspectionTemplate? template;
  final List<InspectionValue> values;
  final List<InspectionAssessment> assessments;
  final InspectionOwner? owner;
  final InspectionValuation? valuation;
  final List<InspectionLocation> locations;
  final GpsProximity? proximity;
  final CompletenessResult? completeness;
  final List<InspectionComment> comments;
  final List<InspectionComment> corrections;

  bool get isEditable => status.isEditable;
  InspectionLocation? get latestLocation =>
      locations.isEmpty ? null : locations.last;

  factory Inspection.fromJson(Map<String, dynamic> j) {
    final property = j['property'];
    final reviewer = j['reviewer'];

    List<T> listOf<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
        raw is List
            ? raw.whereType<Map<String, dynamic>>().map(f).toList()
            : <T>[];

    return Inspection(
      id: j['id'] as String,
      status: InspectionStatusX.parse(j['status'] as String?),
      priority: InspectionPriority.parse(j['priority'] as String?),
      version: (j['version'] as num?)?.toInt() ?? 0,
      inspectionNumber: j['inspectionNumber'] as String?,
      loanReference: j['loanReference'] as String?,
      clientName: j['clientName'] as String?,
      propertyId: j['propertyId'] as String? ??
          (property is Map<String, dynamic> ? property['id'] as String? : null),
      propertyReference: property is Map<String, dynamic>
          ? property['reference'] as String?
          : null,
      propertyName:
          property is Map<String, dynamic> ? property['name'] as String? : null,
      templateId: j['templateId'] as String?,
      dueDate:
          j['dueDate'] is String ? DateTime.tryParse(j['dueDate'] as String) : null,
      submittedAt: j['submittedAt'] is String
          ? DateTime.tryParse(j['submittedAt'] as String)
          : null,
      reviewerName: reviewer is Map<String, dynamic>
          ? '${reviewer['firstName'] ?? ''} ${reviewer['lastName'] ?? ''}'.trim()
          : null,
      template: j['template'] is Map<String, dynamic>
          ? InspectionTemplate.fromJson(j['template'] as Map<String, dynamic>)
          : null,
      values: listOf(j['values'], InspectionValue.fromJson),
      assessments: listOf(j['assessments'], InspectionAssessment.fromJson),
      owner: j['owner'] is Map<String, dynamic>
          ? InspectionOwner.fromJson(j['owner'] as Map<String, dynamic>)
          : null,
      valuation: j['valuation'] is Map<String, dynamic>
          ? InspectionValuation.fromJson(
              j['valuation'] as Map<String, dynamic>)
          : null,
      locations: listOf(j['locations'], InspectionLocation.fromJson),
      proximity: j['proximity'] is Map<String, dynamic>
          ? GpsProximity.fromJson(j['proximity'] as Map<String, dynamic>)
          : null,
      completeness: j['completeness'] is Map<String, dynamic>
          ? CompletenessResult.fromJson(
              j['completeness'] as Map<String, dynamic>)
          : null,
      comments: listOf(j['comments'], InspectionComment.fromJson),
      corrections: listOf(j['corrections'], InspectionComment.fromJson),
    );
  }
}

/// Lightweight row for the inspection list.
class InspectionListItem {
  const InspectionListItem({
    required this.id,
    required this.status,
    required this.priority,
    this.inspectionNumber,
    this.loanReference,
    this.clientName,
    this.propertyReference,
    this.propertyName,
    this.dueDate,
    this.percentage,
  });

  final String id;
  final InspectionStatus status;
  final InspectionPriority priority;
  final String? inspectionNumber;
  final String? loanReference;
  final String? clientName;
  final String? propertyReference;
  final String? propertyName;
  final DateTime? dueDate;
  final int? percentage;

  factory InspectionListItem.fromJson(Map<String, dynamic> j) {
    final property = j['property'];
    final completeness = j['completeness'];

    return InspectionListItem(
      id: j['id'] as String,
      status: InspectionStatusX.parse(j['status'] as String?),
      priority: InspectionPriority.parse(j['priority'] as String?),
      inspectionNumber: j['inspectionNumber'] as String?,
      loanReference: j['loanReference'] as String?,
      clientName: j['clientName'] as String?,
      propertyReference: property is Map<String, dynamic>
          ? property['reference'] as String?
          : null,
      propertyName:
          property is Map<String, dynamic> ? property['name'] as String? : null,
      dueDate: j['dueDate'] is String
          ? DateTime.tryParse(j['dueDate'] as String)
          : null,
      percentage: completeness is Map<String, dynamic>
          ? (completeness['percentage'] as num?)?.toInt()
          : (j['completionPercentage'] as num?)?.toInt(),
    );
  }
}
