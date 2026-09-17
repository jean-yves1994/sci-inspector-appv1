import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sci_widgets.dart';
import '../../../templates/domain/template.dart';
import '../../application/inspection_providers.dart';
import '../../domain/inspection.dart';
import 'dynamic_field.dart';

class ClientEstimatePage extends ConsumerWidget {
  const ClientEstimatePage({required this.inspectionId, required this.enabled, super.key});
  final String inspectionId;
  final bool enabled;

  Object? _raw(InspectionValue? v) {
    if (v == null) return null;
    if (v.valueText != null) return v.valueText;
    if (v.valueNumber != null) return v.valueNumber;
    if (v.valueBool != null) return v.valueBool;
    if (v.valueDate != null) return v.valueDate;
    return v.valueJson;
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _annexTotal(Map<String, dynamic> valuesByCode) {
    var total = 0.0;
    for (var i = 1; i <= 4; i++) {
      total += _number(valuesByCode['ANNEX_${i}_VALUE']);
    }
    return total;
  }

  Widget _calculatedField({required String label, required double value}) {
    final formatted = NumberFormat('#,##0.00', 'en_US').format(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'RWF',
          filled: true,
          fillColor: AppColors.surface2,
        ),
        child: Text(
          formatted,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(inspectionWorkspaceProvider(inspectionId)).valueOrNull?.inspection;
    final template = inspection?.template;
    final valuesById = <String, InspectionValue>{
      for (final v in inspection?.values ?? const <InspectionValue>[]) v.fieldId: v,
    };
    final valuesByCode = <String, dynamic>{};
    for (final s in template?.sections ?? const <TemplateSection>[]) {
      for (final f in s.fields) {
        final v = valuesById[f.id];
        if (v != null) valuesByCode[f.code] = _raw(v);
      }
    }

    final status = valuesByCode['PROPERTY_STATUS']?.toString().toUpperCase();
    final improved = status == 'PROPERTY_WITH_IMPROVEMENT' || status == 'IMPROVED';
    final sectionCode = improved ? 'IMPROVED_VALUATION' : 'LAND_VALUATION';
    TemplateSection? section;
    for (final s in template?.sections ?? const <TemplateSection>[]) {
      if (s.code == sectionCode) {
        section = s;
        break;
      }
    }
    if (section == null) {
      return const Center(child: Text('No valuation fields are configured for this inspection.'));
    }

    final notifier = ref.read(inspectionWorkspaceProvider(inspectionId).notifier);
    final visible = section!.fields.where((f) => f.isVisible(valuesByCode)).toList();
    final annexTotal = improved ? _annexTotal(valuesByCode) : 0.0;
    final landValue = improved
        ? _number(valuesByCode['IMPROVED_LAND_VALUE'])
        : _number(valuesByCode['LAND_ESTIMATED_VALUE']);
    final mainBuildingValue = improved ? _number(valuesByCode['MAIN_BUILDING_VALUE']) : 0.0;
    final totalEstimatedValue = improved
        ? landValue + mainBuildingValue + annexTotal
        : landValue;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        SectionLabel(improved ? 'Property valuation' : 'Land valuation'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: <Widget>[
                for (final field in visible)
                  if (field.code == 'ANNEX_TOTAL_VALUE')
                    _calculatedField(label: field.label, value: annexTotal)
                  else if (field.code == 'IMPROVED_TOTAL_VALUE')
                    _calculatedField(label: field.label, value: totalEstimatedValue)
                  else
                    DynamicInspectionField(
                      field: field,
                      value: notifier.valueFor(field.id),
                      enabled: enabled,
                      onChanged: (value) => notifier.onFieldChanged(
                        value,
                        sectionCode: sectionCode,
                      ),
                    ),
              ],
            ),
          ),
        ),
        if (improved)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Total estimated value = land value + main building value + annexes total value.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 120),
      ],
    );
  }
}
