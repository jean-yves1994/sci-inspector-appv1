import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../templates/domain/template.dart';
import '../../application/inspection_providers.dart';
import '../../domain/inspection.dart';
import 'dynamic_field.dart';

/// Template section renderer with client-side conditional visibility.
class ConditionalTemplateSectionPage extends ConsumerWidget {
  const ConditionalTemplateSectionPage({required this.inspectionId, required this.section, required this.enabled, super.key});
  final String inspectionId;
  final TemplateSection section;
  final bool enabled;

  Object? _raw(InspectionValue? v) {
    if (v == null) return null;
    if (v.valueText != null) return v.valueText;
    if (v.valueNumber != null) return v.valueNumber;
    if (v.valueBool != null) return v.valueBool;
    if (v.valueDate != null) return v.valueDate;
    return v.valueJson;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(inspectionWorkspaceProvider(inspectionId)).valueOrNull?.inspection;
    final valuesById = <String, InspectionValue>{for (final v in inspection?.values ?? const <InspectionValue>[]) v.fieldId: v};
    final valuesByCode = <String, dynamic>{};
    for (final s in inspection?.template?.sections ?? const <TemplateSection>[]) {
      for (final f in s.fields) {
        final v = valuesById[f.id];
        if (v != null) valuesByCode[f.code] = _raw(v);
      }
    }
    final visible = section.fields.where((f) => f.isVisible(valuesByCode)).toList();
    final notifier = ref.read(inspectionWorkspaceProvider(inspectionId).notifier);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        SectionLabel(section.name),
        if (visible.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Text('No information is required for this selection.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))))
        else
          Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(children: <Widget>[for (final f in visible) DynamicInspectionField(field: f, value: notifier.valueFor(f.id), enabled: enabled, onChanged: (v) => notifier.onFieldChanged(v, sectionCode: section.code))]))),
        const SizedBox(height: 120),
      ],
    );
  }
}
