import '../../../core/utils/json_read.dart';
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

  /// `valueNumber` is a Prisma Decimal and arrives as a STRING ("300").
  /// The previous `as num?` cast is what threw:
  ///   type 'String' is not a subtype of type 'num?'
  factory InspectionValue.fromJson(Map<String, dynamic> j) => InspectionValue(
        fieldId: J.asString(j['fieldId']) ??
            J.asString(j['templateFieldId']) ??
            '',
        valueText: J.asString(j['valueText']),
        valueNumber: J.asDouble(j['valueNumber']),
        valueBool: J.asBool(j['valueBool']),
        valueDate: J.asDate(j['valueDate']),
        valueJson: J.asStringList(j['valueJson']),
      );

  /// Builds the correctly-typed value for a given field.
  static InspectionValue forField(TemplateField f, Object? raw) {
    switch (f.type) {
      case FieldType.number:
      case FieldType.currency:
        return InspectionValue(fieldId: f.id, valueNumber: J.asDouble(raw));

      case FieldType.boolean:
        return InspectionValue(fieldId: f.id, valueBool: J.asBool(raw));

      case FieldType.date:
        return InspectionValue(fieldId: f.id, valueDate: J.asDate(raw));

      case FieldType.multiSelect:
        // `raw is List<String>` was false for the List<dynamic> a FilterChip
        // produces, so selections were silently discarded.
        return InspectionValue(
          fieldId: f.id,
          valueJson: J.asStringList(raw) ?? const <String>[],
        );

      case FieldType.text:
      case FieldType.textarea:
      case FieldType.select:
      case FieldType.phone:
      case FieldType.email:
      case FieldType.nationalId:
      case FieldType.unknown:
        return InspectionValue(fieldId: f.id, valueText: J.asString(raw));
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
        categoryCode: J.asString(j['categoryCode']) ?? '',
        categoryName: J.asString(j['categoryName']) ?? '',
        rating: J.asInt(j['rating']),
        condition: J.asString(j['condition']),
        notes: J.asString(j['notes']),
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
    'OWNER_OCCUPIED',
    'TENANT_OCCUPIED',
    'VACANT',
    'PARTIALLY_OCCUPIED',
    'UNDER_CONSTRUCTION',
  ];

  static const List<String> ownershipOptions = <String>[
    'FREEHOLD',
    'LEASEHOLD',
    'CUSTOMARY',
    'CO_OWNERSHIP',
    'COMPANY_OWNED',
  ];

  static String humanise(String v) {
    if (v.isEmpty) return '';
    final parts = v.toLowerCase().split('_');
    return parts.first[0].toUpperCase() +
        parts.first.substring(1) +
        (parts.length > 1 ? ' ${parts.sublist(1).join(' ')}' : '');
  }

  factory InspectionOwner.fromJson(Map<String, dynamic> j) => InspectionOwner(
        fullName: J.asString(j['fullName']),
        // The server stores this encrypted and returns nationalIdEnc; a
        // decrypted `nationalId` may or may not be present.
        nationalId: J.asString(j['nationalId']),
        phone: J.asString(j['phone']),
        email: J.asString(j['email']),
        occupancyStatus: J.asString(j['occupancyStatus']),
        ownershipType: J.asString(j['ownershipType']),
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

  /// All four money fields are Prisma Decimals — they arrive as strings.
  factory InspectionValuation.fromJson(Map<String, dynamic> j) =>
      InspectionValuation(
        currency: J.asString(j['currency']) ?? 'RWF',
        marketValue: J.asDouble(j['marketValue']),
        forcedSaleValue: J.asDouble(j['forcedSaleValue']),
        replacementCost: J.asDouble(j['replacementCost']),
        rentalEstimate: J.asDouble(j['rentalEstimate']),
        comments: J.asString(j['comments']),
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
    this.distanceFromPropertyM,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? altitudeM;
  final String? source;
  final bool? isMocked;
  final DateTime? capturedAt;

  /// Server-calculated. Present on the location row itself.
  final double? distanceFromPropertyM;

  /// Latitude and longitude are Decimals — always quoted in the response.
  factory InspectionLocation.fromJson(Map<String, dynamic> j) =>
      InspectionLocation(
        latitude: J.asDouble(j['latitude']) ?? 0,
        longitude: J.asDouble(j['longitude']) ?? 0,
        accuracyM: J.asDouble(j['accuracyM']),
        altitudeM: J.asDouble(j['altitudeM']),
        source: J.asString(j['source']),
        isMocked: J.asBool(j['isMocked']),
        capturedAt: J.asDate(j['capturedAt']),
        distanceFromPropertyM: J.asDouble(j['distanceFromPropertyM']),
      );
}

/// Server-calculated GPS proximity. Never recomputed on the client.
class GpsProximity {
  const GpsProximity({this.distanceM, this.verdict, this.withinTolerance});

  final double? distanceM;
  final String? verdict;
  final bool? withinTolerance;

  factory GpsProximity.fromJson(Map<String, dynamic> j) => GpsProximity(
        distanceM:
            J.asDouble(j['distanceM']) ?? J.asDouble(j['distanceMeters']),
        verdict: J.asString(j['verdict']) ?? J.asString(j['status']),
        withinTolerance: J.asBool(j['withinTolerance']),
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

  factory CompletenessIssue.fromJson(
    Map<String, dynamic> j, {
    bool blocking = true,
  }) =>
      CompletenessIssue(
        message: J.asString(j['message']) ??
            J.asString(j['description']) ??
            J.asString(j['code']) ??
            'Requirement outstanding',
        code: J.asString(j['code']),
        sectionCode: J.asString(j['sectionCode']),
        fieldCode: J.asString(j['fieldCode']),
        blocking: J.asBool(j['blocking']) ?? blocking,
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
      complete: J.asBool(j['complete']) ?? false,
      percentage: J.asInt(j['percentage']) ?? 0,
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
    final author = J.asMap(j['author']);
    return InspectionComment(
      body: J.asString(j['body']) ??
          J.asString(j['message']) ??
          J.asString(j['comment']) ??
          J.asString(j['reason']) ??
          '',
      author: author != null
          ? '${J.asString(author['firstName']) ?? ''} '
                  '${J.asString(author['lastName']) ?? ''}'
              .trim()
          : J.asString(j['author']),
      createdAt: J.asDate(j['createdAt']),
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

  /// Optimistic concurrency token.
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
      locations.isEmpty ? null : locations.first;

  /// Narrow copy used to adopt a post-write concurrency token without
  /// refetching the whole aggregate.
  Inspection copyWith({
    int? version,
    InspectionStatus? status,
    CompletenessResult? completeness,
  }) =>
      Inspection(
        id: id,
        status: status ?? this.status,
        priority: priority,
        version: version ?? this.version,
        inspectionNumber: inspectionNumber,
        loanReference: loanReference,
        clientName: clientName,
        propertyId: propertyId,
        propertyReference: propertyReference,
        propertyName: propertyName,
        templateId: templateId,
        dueDate: dueDate,
        submittedAt: submittedAt,
        reviewerName: reviewerName,
        template: template,
        values: values,
        assessments: assessments,
        owner: owner,
        valuation: valuation,
        locations: locations,
        proximity: proximity,
        completeness: completeness ?? this.completeness,
        comments: comments,
        corrections: corrections,
      );

  factory Inspection.fromJson(Map<String, dynamic> j) {
    final property = J.asMap(j['property']);
    final reviewer = J.asMap(j['reviewer']);

    List<T> listOf<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
        raw is List
            ? raw.whereType<Map<String, dynamic>>().map(f).toList()
            : <T>[];

    return Inspection(
      id: J.asString(j['id']) ?? '',
      status: InspectionStatusX.parse(J.asString(j['status'])),
      priority: InspectionPriority.parse(J.asString(j['priority'])),
      version: J.asInt(j['version']) ?? 0,
      inspectionNumber: J.asString(j['inspectionNumber']),
      loanReference: J.asString(j['loanReference']),
      clientName: J.asString(j['clientName']),
      propertyId:
          J.asString(j['propertyId']) ?? J.asString(property?['id']),
      propertyReference: J.asString(property?['reference']),
      propertyName: J.asString(property?['name']),
      templateId: J.asString(j['templateId']),
      dueDate: J.asDate(j['dueDate']),
      submittedAt: J.asDate(j['submittedAt']),
      reviewerName: reviewer != null
          ? '${J.asString(reviewer['firstName']) ?? ''} '
                  '${J.asString(reviewer['lastName']) ?? ''}'
              .trim()
          : null,
      template: J.asMap(j['template']) != null
          ? InspectionTemplate.fromJson(J.asMap(j['template'])!)
          : null,
      values: listOf(j['values'], InspectionValue.fromJson),
      assessments: listOf(j['assessments'], InspectionAssessment.fromJson),
      owner: J.asMap(j['owner']) != null
          ? InspectionOwner.fromJson(J.asMap(j['owner'])!)
          : null,
      valuation: J.asMap(j['valuation']) != null
          ? InspectionValuation.fromJson(J.asMap(j['valuation'])!)
          : null,
      locations: listOf(j['locations'], InspectionLocation.fromJson),
      proximity: J.asMap(j['proximity']) != null
          ? GpsProximity.fromJson(J.asMap(j['proximity'])!)
          : null,
      completeness: J.asMap(j['completeness']) != null
          ? CompletenessResult.fromJson(J.asMap(j['completeness'])!)
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
    final property = J.asMap(j['property']);
    final completeness = J.asMap(j['completeness']);

    return InspectionListItem(
      id: J.asString(j['id']) ?? '',
      status: InspectionStatusX.parse(J.asString(j['status'])),
      priority: InspectionPriority.parse(J.asString(j['priority'])),
      inspectionNumber: J.asString(j['inspectionNumber']),
      loanReference: J.asString(j['loanReference']),
      clientName: J.asString(j['clientName']),
      propertyReference: J.asString(property?['reference']),
      propertyName: J.asString(property?['name']),
      dueDate: J.asDate(j['dueDate']),
      percentage: J.asInt(completeness?['percentage']) ??
          J.asInt(j['completionPercentage']),
    );
  }
}
