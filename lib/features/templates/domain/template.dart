/// Backend template field types.
enum FieldType {
  text('TEXT'),
  textarea('TEXTAREA'),
  number('NUMBER'),
  currency('CURRENCY'),
  date('DATE'),
  select('SELECT'),
  multiSelect('MULTI_SELECT'),
  boolean('BOOLEAN'),
  phone('PHONE'),
  email('EMAIL'),
  nationalId('NATIONAL_ID'),

  /// Fallback so a newly added backend type never crashes the app.
  unknown('UNKNOWN');

  const FieldType(this.wire);
  final String wire;

  static FieldType parse(String? v) {
    if (v == null) return FieldType.unknown;
    for (final t in FieldType.values) {
      if (t.wire == v.toUpperCase()) return t;
    }
    return FieldType.unknown;
  }
}

class TemplateField {
  const TemplateField({
    required this.id,
    required this.code,
    required this.label,
    required this.type,
    required this.required,
    required this.sortOrder,
    this.options = const <String>[],
    this.helpText,
  });

  final String id;
  final String code;
  final String label;
  final FieldType type;
  final bool required;
  final int sortOrder;
  final List<String> options;
  final String? helpText;

  factory TemplateField.fromJson(Map<String, dynamic> j) {
    final raw = j['options'];
    final options = <String>[];
    if (raw is List) {
      for (final o in raw) {
        if (o is String) {
          options.add(o);
        } else if (o is Map<String, dynamic>) {
          final v = o['value'] ?? o['label'] ?? o['code'];
          if (v != null) options.add(v.toString());
        }
      }
    }

    return TemplateField(
      id: j['id'] as String,
      code: j['code'] as String? ?? '',
      label: j['label'] as String? ?? j['code'] as String? ?? 'Field',
      type: FieldType.parse(j['type'] as String?),
      required: j['required'] as bool? ?? false,
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      options: options,
      helpText: j['helpText'] as String?,
    );
  }
}

class TemplateSection {
  const TemplateSection({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.isAssessment,
    this.fields = const <TemplateField>[],
  });

  final String id;
  final String code;
  final String name;
  final int sortOrder;

  /// Assessment sections are rendered as rating cards, not field forms.
  final bool isAssessment;
  final List<TemplateField> fields;

  factory TemplateSection.fromJson(Map<String, dynamic> j) {
    final raw = j['fields'];
    final fields = raw is List
        ? (raw.whereType<Map<String, dynamic>>().map(TemplateField.fromJson)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        : <TemplateField>[];

    return TemplateSection(
      id: j['id'] as String,
      code: j['code'] as String? ?? '',
      name: j['name'] as String? ?? j['code'] as String? ?? 'Section',
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      isAssessment: j['isAssessment'] as bool? ?? false,
      fields: fields,
    );
  }
}

class TemplatePhotoRule {
  const TemplatePhotoRule({
    required this.id,
    required this.category,
    required this.minCount,
    required this.required,
  });

  final String id;
  final String category;
  final int minCount;
  final bool required;

  factory TemplatePhotoRule.fromJson(Map<String, dynamic> j) =>
      TemplatePhotoRule(
        id: j['id'] as String? ?? j['category'] as String? ?? '',
        category: j['category'] as String? ?? '',
        minCount: (j['minCount'] as num?)?.toInt() ??
            (j['min'] as num?)?.toInt() ??
            1,
        required: j['required'] as bool? ?? true,
      );
}

class InspectionTemplate {
  const InspectionTemplate({
    required this.id,
    required this.name,
    this.sections = const <TemplateSection>[],
    this.photoRules = const <TemplatePhotoRule>[],
  });

  final String id;
  final String name;
  final List<TemplateSection> sections;
  final List<TemplatePhotoRule> photoRules;

  List<TemplateSection> get fieldSections =>
      sections.where((s) => !s.isAssessment).toList();

  List<TemplateSection> get assessmentSections =>
      sections.where((s) => s.isAssessment).toList();

  factory InspectionTemplate.fromJson(Map<String, dynamic> j) {
    final rawSections = j['sections'];
    final sections = rawSections is List
        ? (rawSections
            .whereType<Map<String, dynamic>>()
            .map(TemplateSection.fromJson)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        : <TemplateSection>[];

    final rawRules = j['photoRules'];
    final rules = rawRules is List
        ? rawRules
            .whereType<Map<String, dynamic>>()
            .map(TemplatePhotoRule.fromJson)
            .toList()
        : <TemplatePhotoRule>[];

    return InspectionTemplate(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? 'Inspection template',
      sections: sections,
      photoRules: rules,
    );
  }
}
