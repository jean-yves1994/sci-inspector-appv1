import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sci_widgets.dart';
import '../../../templates/domain/template.dart';
import '../../application/inspection_providers.dart';
import '../../domain/inspection.dart';
import 'dynamic_field.dart';

bool _isRetiredInsideWindowField(String code) =>
    code == 'BUILDING_INSIDE_WINDOW_MATERIAL' ||
    RegExp(r'^ANNEX_[1-4]_INSIDE_WINDOW_MATERIAL$').hasMatch(code);

/// Template section renderer with client-side conditional visibility.
class ConditionalTemplateSectionPage extends ConsumerWidget {
  const ConditionalTemplateSectionPage({
    required this.inspectionId,
    required this.section,
    required this.enabled,
    super.key,
  });

  final String inspectionId;
  final TemplateSection section;
  final bool enabled;

  Object? _raw(InspectionValue? value) {
    if (value == null) return null;
    if (value.valueText != null) return value.valueText;
    if (value.valueNumber != null) return value.valueNumber;
    if (value.valueBool != null) return value.valueBool;
    if (value.valueDate != null) return value.valueDate;
    return value.valueJson;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection =
        ref.watch(inspectionWorkspaceProvider(inspectionId)).valueOrNull?.inspection;
    final valuesById = <String, InspectionValue>{
      for (final value in inspection?.values ?? const <InspectionValue>[])
        value.fieldId: value,
    };
    final valuesByCode = <String, dynamic>{};

    for (final templateSection
        in inspection?.template?.sections ?? const <TemplateSection>[]) {
      for (final field in templateSection.fields) {
        final value = valuesById[field.id];
        if (value != null) {
          valuesByCode[field.code] = _raw(value);
        }
      }
    }

    final visible = section.fields
        .where(
          (field) =>
              field.isVisible(valuesByCode) &&
              !_isRetiredInsideWindowField(field.code),
        )
        .toList();

    final notifier =
        ref.read(inspectionWorkspaceProvider(inspectionId).notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        SectionLabel(section.name),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'No information is required for this selection.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  for (final field in visible)
                    DynamicInspectionField(
                      field: field,
                      value: notifier.valueFor(field.id),
                      enabled: enabled,
                      onChanged: (value) => notifier.onFieldChanged(
                        value,
                        sectionCode: section.code,
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 120),
      ],
    );
  }
}
