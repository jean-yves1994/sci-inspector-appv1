import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../templates/domain/template.dart';
import '../../domain/inspection.dart';

/// Renders ONE template field from the backend-supplied definition.
///
/// There is deliberately no hard-coded screen per field: administrators can
/// change the template without shipping a new app, so everything routes
/// through this single switch on [TemplateField.type].
class DynamicInspectionField extends StatefulWidget {
  const DynamicInspectionField({
    required this.field,
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final TemplateField field;
  final InspectionValue? value;
  final bool enabled;
  final ValueChanged<InspectionValue> onChanged;

  @override
  State<DynamicInspectionField> createState() =>
      _DynamicInspectionFieldState();
}

class _DynamicInspectionFieldState extends State<DynamicInspectionField> {
  TextEditingController? _controller;
  bool _revealNationalId = false;

  @override
  void initState() {
    super.initState();
    if (_isTextual) {
      _controller = TextEditingController(text: _initialText);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _isTextual => const <FieldType>{
        FieldType.text,
        FieldType.textarea,
        FieldType.number,
        FieldType.currency,
        FieldType.phone,
        FieldType.email,
        FieldType.nationalId,
        FieldType.unknown,
      }.contains(widget.field.type);

  String get _initialText {
    final v = widget.value;
    if (v == null) return '';
    if (v.valueNumber != null) {
      final n = v.valueNumber!;
      return n == n.roundToDouble()
          ? n.toStringAsFixed(0)
          : n.toString();
    }
    return v.valueText ?? '';
  }

  void _emit(Object? raw) =>
      widget.onChanged(InspectionValue.forField(widget.field, raw));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.field.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (widget.field.required)
                const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _control(context),
          if (widget.field.helpText != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              widget.field.helpText!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _control(BuildContext context) {
    switch (widget.field.type) {
      case FieldType.textarea:
        return TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          maxLines: 4,
          onChanged: _emit,
          decoration: const InputDecoration(hintText: 'Enter details'),
        );

      case FieldType.number:
        return TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: _emit,
          decoration: const InputDecoration(hintText: '0'),
        );

      case FieldType.currency:
        return TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: _emit,
          decoration: const InputDecoration(
            prefixText: 'RWF ',
            hintText: '0',
          ),
        );

      case FieldType.date:
        final d = widget.value?.valueDate;
        return InkWell(
          onTap: widget.enabled ? () => _pickDate(context) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.event_outlined, size: 20),
            ),
            child: Text(
              d == null ? 'Select date' : DateFormat('d MMM yyyy').format(d),
              style: TextStyle(
                fontSize: 14,
                color: d == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        );

      case FieldType.select:
        final current = widget.value?.valueText;
        return DropdownButtonFormField<String>(
          initialValue:
              widget.field.options.contains(current) ? current : null,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Select an option'),
          items: <DropdownMenuItem<String>>[
            for (final o in widget.field.options)
              DropdownMenuItem<String>(value: o, child: Text(o)),
          ],
          onChanged: widget.enabled ? _emit : null,
        );

      case FieldType.multiSelect:
        final selected = <String>{...?widget.value?.valueJson};
        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final o in widget.field.options)
              FilterChip(
                label: Text(o),
                selected: selected.contains(o),
                onSelected: widget.enabled
                    ? (on) {
                        final next = <String>{...selected};
                        on ? next.add(o) : next.remove(o);
                        _emit(next.toList());
                      }
                    : null,
              ),
          ],
        );

      case FieldType.boolean:
        final on = widget.value?.valueBool ?? false;
        return SwitchListTile.adaptive(
          value: on,
          onChanged: widget.enabled ? _emit : null,
          title: Text(
            on ? 'Yes' : 'No',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          contentPadding: EdgeInsets.zero,
        );

      case FieldType.phone:
        return TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.phone,
          onChanged: _emit,
          decoration: const InputDecoration(hintText: '+250 7XX XXX XXX'),
        );

      case FieldType.email:
        return TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.emailAddress,
          onChanged: _emit,
          decoration: const InputDecoration(hintText: 'name@example.com'),
        );

      case FieldType.nationalId:
        // Masked unless actively revealed; never shown casually.
        if (!_revealNationalId && !widget.enabled) {
          return InputDecorator(
            decoration: const InputDecoration(),
            child: Text(maskNationalId(widget.value?.valueText)),
          );
        }
        return TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          obscureText: !_revealNationalId,
          keyboardType: TextInputType.number,
          onChanged: _emit,
          decoration: InputDecoration(
            hintText: 'National ID',
            suffixIcon: IconButton(
              tooltip: _revealNationalId ? 'Hide' : 'Show',
              icon: Icon(
                _revealNationalId
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _revealNationalId = !_revealNationalId),
            ),
          ),
        );

      case FieldType.text:
        return TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: _emit,
          decoration: const InputDecoration(hintText: 'Enter value'),
        );

      case FieldType.unknown:
        // Forward-compatible: a new backend type renders read-only rather
        // than crashing the field renderer.
        return InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.info_outline_rounded, size: 20),
          ),
          child: Text(
            widget.value?.valueText ??
                'This field type is not supported by your app version.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        );
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value?.valueDate ?? now,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) _emit(picked);
  }
}
