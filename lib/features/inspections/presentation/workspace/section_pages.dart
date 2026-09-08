import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sci_widgets.dart';
import '../../../photos/data/image_picker_service.dart';
import '../../../photos/data/photos_repository.dart';
import '../../../photos/domain/photo.dart';
import '../../../templates/domain/template.dart';
import '../../application/inspection_providers.dart';
import '../../domain/inspection.dart';
import 'dynamic_field.dart';

/// Template-driven field section.
class TemplateSectionPage extends ConsumerWidget {
  const TemplateSectionPage({
    required this.inspectionId,
    required this.section,
    required this.enabled,
    super.key,
  });

  final String inspectionId;
  final TemplateSection section;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(inspectionWorkspaceProvider(inspectionId).notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        SectionLabel(section.name),
        if (section.fields.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'This section has no fields in the current template.',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  for (final f in section.fields)
                    DynamicInspectionField(
                      field: f,
                      value: notifier.valueFor(f.id),
                      enabled: enabled,
                      onChanged: (value) => notifier.onFieldChanged(value, sectionCode: section.code),
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

/// Condition assessments — rendered from section.isAssessment, not a
/// hard-coded category list.
class AssessmentsPage extends ConsumerWidget {
  const AssessmentsPage({
    required this.inspectionId,
    required this.sections,
    required this.enabled,
    super.key,
  });

  final String inspectionId;
  final List<TemplateSection> sections;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inspectionWorkspaceProvider(inspectionId));
    final existing = state.valueOrNull?.inspection.assessments ??
        const <InspectionAssessment>[];

    InspectionAssessment? findFor(String code) {
      for (final a in existing) {
        if (a.categoryCode == code) return a;
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        const SectionLabel('Condition assessments'),
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Every assessment category needs a rating before submission.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
        for (final s in sections)
          _AssessmentCard(
            inspectionId: inspectionId,
            section: s,
            existing: findFor(s.code),
            enabled: enabled,
          ),
        const SizedBox(height: 120),
      ],
    );
  }
}

class _AssessmentCard extends ConsumerStatefulWidget {
  const _AssessmentCard({
    required this.inspectionId,
    required this.section,
    required this.existing,
    required this.enabled,
  });

  final String inspectionId;
  final TemplateSection section;
  final InspectionAssessment? existing;
  final bool enabled;

  @override
  ConsumerState<_AssessmentCard> createState() => _AssessmentCardState();
}

class _AssessmentCardState extends ConsumerState<_AssessmentCard> {
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  int? _rating;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(inspectionWorkspaceProvider(widget.inspectionId).notifier)
          .saveAssessment(
            InspectionAssessment(
              categoryCode: widget.section.code,
              categoryName: widget.section.name,
              rating: _rating,
              condition: ConditionRating.fromRating(_rating)?.wire,
              notes: _notes.text,
            ),
          );
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rated = _rating != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.section.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusBadge(
                    label: rated
                        ? ConditionRating.fromRating(_rating)!.label
                        : 'Not rated',
                    color: rated ? AppColors.success : AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  for (final c in ConditionRating.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Semantics(
                          button: true,
                          selected: _rating == c.rating,
                          label: '${c.rating} ${c.label}',
                          child: InkWell(
                            onTap: widget.enabled
                                ? () => setState(() => _rating = c.rating)
                                : null,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                            child: Container(
                              height: AppSpacing.touchTarget,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _rating == c.rating
                                    ? AppColors.primary
                                    : AppColors.primary
                                        .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(
                                '${c.rating}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _rating == c.rating
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                rated
                    ? ConditionRating.fromRating(_rating)!.label
                    : '1 Very Poor  ·  5 Excellent',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notes,
                enabled: widget.enabled,
                maxLines: 2,
                decoration:
                    const InputDecoration(hintText: 'Notes (optional)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed:
                      widget.enabled && rated && !_busy ? _save : null,
                  child: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save assessment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owner information.
class OwnerPage extends ConsumerStatefulWidget {
  const OwnerPage({
    required this.inspectionId,
    required this.enabled,
    super.key,
  });

  final String inspectionId;
  final bool enabled;

  @override
  ConsumerState<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends ConsumerState<OwnerPage> {
  final _name = TextEditingController();
  final _nationalId = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _occupancy;
  String? _ownership;
  bool _busy = false;
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _nationalId.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _seed(InspectionOwner? o) {
    if (_seeded || o == null) return;
    _seeded = true;
    _name.text = o.fullName ?? '';
    _nationalId.text = o.nationalId ?? '';
    _phone.text = o.phone ?? '';
    _email.text = o.email ?? '';
    _occupancy = o.occupancyStatus;
    _ownership = o.ownershipType;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(inspectionWorkspaceProvider(widget.inspectionId).notifier)
          .saveOwner(InspectionOwner(
            fullName: _name.text,
            nationalId: _nationalId.text,
            phone: _phone.text,
            email: _email.text,
            occupancyStatus: _occupancy,
            ownershipType: _ownership,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Owner information saved.')));
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionWorkspaceProvider(widget.inspectionId));
    _seed(state.valueOrNull?.inspection.owner);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        const SectionLabel('Owner information'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: <Widget>[
                SciTextField(
                  controller: _name,
                  label: 'FULL NAME',
                  icon: Icons.person_outline_rounded,
                  enabled: widget.enabled,
                ),
                const SizedBox(height: AppSpacing.md),
                SciTextField(
                  controller: _nationalId,
                  label: 'NATIONAL ID',
                  icon: Icons.badge_outlined,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  helper: 'Encrypted by the server. Never stored in clear '
                      'text on this device.',
                ),
                const SizedBox(height: AppSpacing.md),
                SciTextField(
                  controller: _phone,
                  label: 'PHONE',
                  icon: Icons.phone_outlined,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  hint: '+250788000000',
                ),
                const SizedBox(height: AppSpacing.md),
                SciTextField(
                  controller: _email,
                  label: 'EMAIL',
                  icon: Icons.alternate_email_rounded,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                _Dropdown(
                  label: 'OCCUPANCY STATUS',
                  value: _occupancy,
                  options: InspectionOwner.occupancyOptions,
                  enabled: widget.enabled,
                  onChanged: (v) => setState(() => _occupancy = v),
                ),
                const SizedBox(height: AppSpacing.md),
                _Dropdown(
                  label: 'OWNERSHIP TYPE',
                  value: _ownership,
                  options: InspectionOwner.ownershipOptions,
                  enabled: widget.enabled,
                  onChanged: (v) => setState(() => _ownership = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: widget.enabled && !_busy ? _save : null,
          child: _busy
              ? const ButtonSpinner()
              : const Text('Save owner information'),
        ),
        const SizedBox(height: 120),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: options.contains(value) ? value : null,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Select'),
          items: <DropdownMenuItem<String>>[
            for (final o in options)
              DropdownMenuItem<String>(
                  value: o, child: Text(InspectionOwner.humanise(o))),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

/// Valuation. Currency defaults to RWF, never "RF".
class ValuationPage extends ConsumerStatefulWidget {
  const ValuationPage({
    required this.inspectionId,
    required this.enabled,
    super.key,
  });

  final String inspectionId;
  final bool enabled;

  @override
  ConsumerState<ValuationPage> createState() => _ValuationPageState();
}

class _ValuationPageState extends ConsumerState<ValuationPage> {
  final _market = TextEditingController();
  final _forced = TextEditingController();
  final _replacement = TextEditingController();
  final _rental = TextEditingController();
  final _comments = TextEditingController();
  bool _busy = false;
  bool _seeded = false;

  @override
  void dispose() {
    _market.dispose();
    _forced.dispose();
    _replacement.dispose();
    _rental.dispose();
    _comments.dispose();
    super.dispose();
  }

  static String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(0);

  void _seed(InspectionValuation? v) {
    if (_seeded || v == null) return;
    _seeded = true;
    _market.text = _fmt(v.marketValue);
    _forced.text = _fmt(v.forcedSaleValue);
    _replacement.text = _fmt(v.replacementCost);
    _rental.text = _fmt(v.rentalEstimate);
    _comments.text = v.comments ?? '';
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(inspectionWorkspaceProvider(widget.inspectionId).notifier)
          .saveValuation(InspectionValuation(
            currency: 'RWF',
            marketValue: double.tryParse(_market.text),
            forcedSaleValue: double.tryParse(_forced.text),
            replacementCost: double.tryParse(_replacement.text),
            rentalEstimate: double.tryParse(_rental.text),
            comments: _comments.text,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Valuation saved.')));
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionWorkspaceProvider(widget.inspectionId));
    _seed(state.valueOrNull?.inspection.valuation);

    Widget money(String label, TextEditingController c) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: SciTextField(
            controller: c,
            label: label,
            enabled: widget.enabled,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            hint: '0',
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        const SectionLabel('Valuation'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const StatusBadge(
                  label: 'Currency: RWF',
                  color: AppColors.primary,
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                money('MARKET VALUE (RWF)', _market),
                money('FORCED SALE VALUE (RWF)', _forced),
                money('REPLACEMENT COST (RWF)', _replacement),
                money('RENTAL ESTIMATE (RWF)', _rental),
                SciTextField(
                  controller: _comments,
                  label: 'COMMENTS',
                  enabled: widget.enabled,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: widget.enabled && !_busy ? _save : null,
          child: _busy ? const ButtonSpinner() : const Text('Save valuation'),
        ),
        const SizedBox(height: 120),
      ],
    );
  }
}

/// GPS capture. Location is a blocking requirement for submission.
class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({
    required this.inspectionId,
    required this.enabled,
    super.key,
  });

  final String inspectionId;
  final bool enabled;

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  bool _busy = false;
  String? _error;

  Future<void> _capture() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fix = await ref.read(locationServiceProvider).current();
      await ref
          .read(inspectionWorkspaceProvider(widget.inspectionId).notifier)
          .captureLocation(
            latitude: fix.latitude,
            longitude: fix.longitude,
            accuracyM: fix.accuracyM,
            altitudeM: fix.altitudeM,
            source: fix.source,
            isMocked: fix.isMocked,
            capturedAt: fix.capturedAt,
          );
    } on LocationDenied catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionWorkspaceProvider(widget.inspectionId));
    final inspection = state.valueOrNull?.inspection;
    final loc = inspection?.latestLocation;
    final prox = inspection?.proximity;
    final poorAccuracy = (loc?.accuracyM ?? 0) > 30;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        const SectionLabel('Property location'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (loc == null)
                  const Text(
                    'No location captured yet. GPS evidence is required '
                    'before this inspection can be submitted.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  )
                else ...<Widget>[
                  _kv('Latitude', loc.latitude.toStringAsFixed(6)),
                  _kv('Longitude', loc.longitude.toStringAsFixed(6)),
                  _kv(
                    'GPS accuracy',
                    loc.accuracyM == null
                        ? '—'
                        : '${loc.accuracyM!.toStringAsFixed(1)} m',
                  ),
                  _kv('Source', loc.source ?? '—'),
                  if (loc.capturedAt != null)
                    _kv(
                      'Captured',
                      DateFormat('d MMM yyyy HH:mm')
                          .format(loc.capturedAt!.toLocal()),
                    ),
                  // Server-calculated. Never recomputed on the client.
                  if (prox?.distanceM != null)
                    _kv(
                      'Distance from property',
                      '${prox!.distanceM!.toStringAsFixed(0)} m',
                    ),
                  if (prox?.verdict != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: StatusBadge(
                        label: prox!.verdict!,
                        color: prox.withinTolerance == false
                            ? AppColors.danger
                            : AppColors.success,
                        icon: Icons.gps_fixed_rounded,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (loc != null && poorAccuracy) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          MessageBanner(
            message:
                'GPS accuracy is currently ${loc.accuracyM!.toStringAsFixed(0)}m. '
                'Move to an open area and capture again.',
            color: AppColors.warning,
            icon: Icons.satellite_alt_outlined,
          ),
        ],
        if (prox?.withinTolerance == false) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const MessageBanner(
            message: 'The server reports this capture is far from the '
                'registered property location. Verify you are at the correct '
                'property.',
            color: AppColors.danger,
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          MessageBanner(message: _error!),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: widget.enabled && !_busy ? _capture : null,
          icon: _busy
              ? const ButtonSpinner()
              : const Icon(Icons.my_location_rounded, size: 20),
          label: Text(loc == null
              ? 'Capture current location'
              : 'Capture again'),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 150,
              child: Text(
                k,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// Photo evidence, driven by template.photoRules.
final inspectionPhotosProvider = FutureProvider.autoDispose
    .family<List<InspectionPhoto>, String>(
        (ref, id) => ref.watch(photosRepositoryProvider).list(id));

class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({
    required this.inspectionId,
    required this.rules,
    required this.enabled,
    super.key,
  });

  final String inspectionId;
  final List<TemplatePhotoRule> rules;
  final bool enabled;

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  final Set<String> _uploading = <String>{};
  final Map<String, double> _uploadProgress = <String, double>{};
  final Map<String, List<EvidenceFile>> _pendingPreviews =
      <String, List<EvidenceFile>>{};

  Future<void> _capture(PhotoCategory category) async {
    final picker = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(c).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(c).pop(false),
            ),
          ],
        ),
      ),
    );
    if (picker == null || !mounted) return;

    setState(() => _uploading.add(category.wire));
    try {
      final file = await pickEvidence(fromCamera: picker);
      if (file == null) return;

      if (file.exceedsLimit) {
        throw const ApiError(
          code: 'PHOTO_TOO_LARGE',
          message: 'That image is larger than the 4 MB upload limit.',
        );
      }

      if (mounted) {
        setState(() {
          _pendingPreviews.putIfAbsent(category.wire, () => <EvidenceFile>[]).add(file);
          _uploadProgress[category.wire] = 0;
        });
      }

      // A retry of this upload must reuse the same id for idempotency.
      final clientRequestId = const Uuid().v4();

      LocationFix? fix;
      try {
        fix = await ref.read(locationServiceProvider).current();
      } on Object {
        fix = null; // GPS on a photo is a bonus, not a hard requirement
      }

      await ref.read(photosRepositoryProvider).upload(
            inspectionId: widget.inspectionId,
            file: file,
            category: category,
            clientRequestId: clientRequestId,
            capturedAt: DateTime.now(),
            latitude: fix?.latitude,
            longitude: fix?.longitude,
            accuracyM: fix?.accuracyM,
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _uploadProgress[category.wire] = sent / total);
            },
          );

      if (mounted) {
        setState(() {
          final pending = _pendingPreviews[category.wire];
          if (pending != null && pending.isNotEmpty) pending.removeAt(0);
          if (pending != null && pending.isEmpty) {
            _pendingPreviews.remove(category.wire);
          }
          _uploadProgress.remove(category.wire);
        });
      }
      ref.invalidate(inspectionPhotosProvider(widget.inspectionId));
      ref.read(inspectionWorkspaceProvider(widget.inspectionId).notifier)
          .photoChanged(category.wire);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          final pending = _pendingPreviews[category.wire];
          if (pending != null && pending.isNotEmpty) pending.removeAt(0);
          if (pending != null && pending.isEmpty) _pendingPreviews.remove(category.wire);
          _uploadProgress.remove(category.wire);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading.remove(category.wire);
          _uploadProgress.remove(category.wire);
        });
      }
    }
  }

  Future<void> _delete(InspectionPhoto photo) async {
    try {
      await ref.read(photosRepositoryProvider).delete(photo.id);
      ref.invalidate(inspectionPhotosProvider(widget.inspectionId));
      ref.invalidate(completenessProvider(widget.inspectionId));
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(inspectionPhotosProvider(widget.inspectionId));

    return photos.when(
      loading: () => const ListSkeleton(itemCount: 4, height: 140),
      error: (e, _) => ErrorStateView(
        error: e,
        onRetry: () =>
            ref.invalidate(inspectionPhotosProvider(widget.inspectionId)),
      ),
      data: (all) {
        // Render the ACTUAL backend rules, plus any category already used.
        final categories = <PhotoCategory, int>{};
        for (final r in widget.rules) {
          categories[PhotoCategory.parse(r.category)] = r.minCount;
        }
        for (final p in all) {
          categories.putIfAbsent(p.category, () => 0);
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            const SectionLabel('Photographs'),
            if (categories.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'The current template defines no photo requirements.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ),
            for (final entry in categories.entries)
              _CategoryBlock(
                category: entry.key,
                minCount: entry.value,
                photos:
                    all.where((p) => p.category == entry.key).toList(),
                enabled: widget.enabled,
                uploading: _uploading.contains(entry.key.wire),
                uploadProgress: _uploadProgress[entry.key.wire] ?? 0,
                pendingPreviews: _pendingPreviews[entry.key.wire] ?? const <EvidenceFile>[],
                onCapture: () => _capture(entry.key),
                onDelete: _delete,
              ),
            const SizedBox(height: 120),
          ],
        );
      },
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    required this.category,
    required this.minCount,
    required this.photos,
    required this.enabled,
    required this.uploading,
    required this.uploadProgress,
    required this.pendingPreviews,
    required this.onCapture,
    required this.onDelete,
  });

  final PhotoCategory category;
  final int minCount;
  final List<InspectionPhoto> photos;
  final bool enabled;
  final bool uploading;
  final double uploadProgress;
  final List<EvidenceFile> pendingPreviews;
  final VoidCallback onCapture;
  final ValueChanged<InspectionPhoto> onDelete;

  @override
  Widget build(BuildContext context) {
    final visibleCount = photos.length + pendingPreviews.length;
    final satisfied = visibleCount >= minCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      category.label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusBadge(
                    label: '$visibleCount / $minCount',
                    color: satisfied
                        ? AppColors.success
                        : (minCount > 0
                            ? AppColors.warning
                            : AppColors.offline),
                    icon: satisfied ? Icons.check_rounded : null,
                  ),
                ],
              ),
              if (photos.isNotEmpty || pendingPreviews.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length + pendingPreviews.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      if (i < photos.length) {
                        return _Thumb(
                          photo: photos[i],
                          enabled: enabled,
                          onDelete: () => onDelete(photos[i]),
                        );
                      }
                      return _PendingThumb(
                        file: pendingPreviews[i - photos.length],
                        progress: uploadProgress,
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: enabled && !uploading ? onCapture : null,
                  icon: uploading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(
                      photos.isEmpty ? 'Take photo' : 'Take another'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingThumb extends StatelessWidget {
  const _PendingThumb({required this.file, required this.progress});

  final EvidenceFile file;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            height: 92,
            width: 92,
            child: Image.memory(file.bytes, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: CircularProgressIndicator(
                  value: progress > 0 && progress < 1 ? progress : null,
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          Positioned(
            left: 4,
            right: 4,
            bottom: 3,
            child: Text(
              progress > 0 ? '${(progress * 100).round()}%' : 'Uploading…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.enabled,
    required this.onDelete,
  });

  final InspectionPhoto photo;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: 92,
            width: 92,
            child: photo.url == null
                ? const ColoredBox(
                    color: Color(0xFFE9ECF4),
                    child: Icon(Icons.image_outlined),
                  )
                : Image.network(
                    photo.url!,
                    fit: BoxFit.cover,
                    // Signed URLs expire; degrade gracefully.
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFE9ECF4),
                      child: Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ),
          ),
        ),
        if (photo.hasGps)
          const Positioned(
            left: 4,
            bottom: 4,
            child: Icon(Icons.gps_fixed_rounded,
                size: 14, color: Colors.white),
          ),
        if (enabled)
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  borderRadius:
                      BorderRadius.only(bottomLeft: Radius.circular(8)),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 13, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
