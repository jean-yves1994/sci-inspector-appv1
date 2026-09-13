import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/sci_widgets.dart';
import '../../../templates/domain/template.dart';
import '../../application/inspection_providers.dart';

class ClientEstimatePage extends ConsumerWidget {
  const ClientEstimatePage({required this.inspectionId, required this.enabled, super.key});
  final String inspectionId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(inspectionWorkspaceProvider(inspectionId)).valueOrNull;
    final template = ws?.template;
    final status = ws?.inspection;
    final values = <String, dynamic>{};
    for (final v in status?.values ?? const []) {
      values[v.field.code] = v.valueText ?? v.valueNumber ?? v.valueBool ?? v.valueJson;
    }
    final improved = values['PROPERTY_STATUS']?.toString().toUpperCase() == 'PROPERTY_WITH_IMPROVEMENT' || values['PROPERTY_STATUS']?.toString().toUpperCase() == 'IMPROVED';
    final section = template?.sections.firstWhere((s) => s.code == (improved ? 'IMPROVED_VALUATION' : 'LAND_VALUATION'), orElse: () => const TemplateSection(id: '', code: '', name: 'Estimate', sortOrder: 0, isAssessment: false));
    if (section == null || section.fields.isEmpty) {
      return const Center(child: Text('No valuation fields are configured for this inspection.'));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(improved ? 'Property valuation' : 'Land valuation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(improved ? 'Record land, main building and applicable annex values.' : 'Record the estimated land value or unit rate for the vacant plot.'),
      const SizedBox(height: 16),
      ...section.fields.where((f) => f.isVisible(values)).map((field) => _EstimateField(inspectionId: inspectionId, field: field, enabled: enabled)),
    ]);
  }
}

class _EstimateField extends ConsumerStatefulWidget {
  const _EstimateField({required this.inspectionId, required this.field, required this.enabled});
  final String inspectionId;
  final TemplateField field;
  final bool enabled;
  @override ConsumerState<_EstimateField> createState() => _EstimateFieldState();
}
class _EstimateFieldState extends ConsumerState<_EstimateField> {
  late final TextEditingController controller;
  @override void initState() { super.initState(); controller = TextEditingController(); }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, enabled: widget.enabled, keyboardType: widget.field.type == FieldType.currency || widget.field.type == FieldType.number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: widget.field.label, helperText: widget.field.helpText, border: const OutlineInputBorder()), onChanged: (_) {}));
  }
}
