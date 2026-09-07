import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/sci_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/user.dart';
import '../../inspections/domain/inspection_status.dart';
import '../application/property_providers.dart';
import '../data/properties_repository.dart';
import '../domain/property.dart';

// --------------------------------------------------------------- list

class PropertyListScreen extends ConsumerStatefulWidget {
  const PropertyListScreen({super.key});

  @override
  ConsumerState<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends ConsumerState<PropertyListScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      ref.read(propertyListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(propertyListProvider);
    final term = ref.watch(propertySearchProvider);
    final canCreate =
        ref.watch(hasPermissionProvider(Permissions.propertiesWrite));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Properties'),
        actions: <Widget>[
          if (canCreate)
            IconButton(
              tooltip: 'New property',
              onPressed: () => context.push(Routes.propertyNew),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _search,
              onChanged: ref.read(propertySearchProvider.notifier).onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search reference, name, owner, plot, UPI',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _search,
                  builder: (context, v, _) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _search.clear();
                            ref.read(propertySearchProvider.notifier).clear();
                          },
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const ListSkeleton(),
              error: (e, _) => ErrorStateView(
                error: e,
                onRetry: () => ref.invalidate(propertyListProvider),
              ),
              data: (state) => RefreshIndicator(
                onRefresh: ref.read(propertyListProvider.notifier).refresh,
                child: state.items.isEmpty
                    ? ListView(
                        children: <Widget>[
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.55,
                            child: EmptyState(
                              icon: Icons.apartment_outlined,
                              title: term.isEmpty
                                  ? 'No properties yet'
                                  : 'No properties found',
                              message: term.isEmpty
                                  ? 'Register a property to start an '
                                      'inspection from the field.'
                                  : 'Try another search or register a new '
                                      'property.',
                              actionLabel: canCreate ? '+ New property' : null,
                              onAction: canCreate
                                  ? () => context.push(Routes.propertyNew)
                                  : null,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.xs, AppSpacing.md, 120),
                        itemCount: state.items.length + 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          if (i == state.items.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg),
                              child: Center(
                                child: state.isLoadingMore
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2.2)
                                    : const SizedBox.shrink(),
                              ),
                            );
                          }
                          return _PropertyCard(property: state.items[i]);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(Routes.propertyDetail(property.id)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.apartment_rounded,
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            property.reference.isEmpty
                                ? 'Reference pending'
                                : property.reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (property.propertyType != null)
                          StatusBadge(
                            label: property.propertyType!.label,
                            color: AppColors.violet,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      property.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _Meta(
                      icon: Icons.person_outline_rounded,
                      text: property.ownerClientName.isEmpty
                          ? 'Owner not recorded'
                          : property.ownerClientName,
                    ),
                    _Meta(
                      icon: Icons.place_outlined,
                      text: property.locationSummary,
                    ),
                    // Land registration identifies a parcel in the field, so
                    // it earns a line. Older records may predate the fields
                    // being required, hence the guard.
                    if (property.hasLandRegistration)
                      _Meta(
                        icon: Icons.confirmation_number_outlined,
                        text: property.landRegistrationSummary,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- detail

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(propertyDetailProvider(propertyId));
    final canCreate =
        ref.watch(hasPermissionProvider(Permissions.inspectionsCreate));

    return Scaffold(
      appBar: AppBar(title: const Text('Property')),
      body: detail.when(
        loading: () => const ListSkeleton(itemCount: 4, height: 120),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.invalidate(propertyDetailProvider(propertyId)),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(propertyDetailProvider(propertyId)),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(Icons.apartment_rounded,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  p.reference,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          if (p.propertyType != null)
                            StatusBadge(
                              label: p.propertyType!.label,
                              color: AppColors.violet,
                              icon: Icons.category_outlined,
                            ),
                          if (p.branchName != null)
                            StatusBadge(
                              label: p.branchName!,
                              color: AppColors.primary,
                              icon: Icons.account_balance_outlined,
                            ),
                          if (p.hasCoordinates)
                            const StatusBadge(
                              label: 'Coordinates on file',
                              color: AppColors.success,
                              icon: Icons.gps_fixed_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Land registration ---------------------------------
              // Directly below identification: the plot number and UPI ARE
              // the parcel's legal identity, so they belong with the
              // reference rather than at the foot of the screen.
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Land information',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Rows always render. Records created before these
                      // became mandatory will show "Not recorded", which is
                      // explicit — an absent row would be ambiguous in an
                      // audit document.
                      _Row(
                        label: 'Plot number',
                        value: p.plotNumber,
                        emptyText: 'Not recorded',
                      ),
                      _Row(
                        label: 'UPI',
                        value: p.titleNumber,
                        emptyText: 'Not recorded',
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Administrative location ---------------------------
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Administrative location',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // The joined summary first, matching the report, then
                      // each level for a reviewer who needs a specific one.
                      _Row(label: 'Location', value: p.locationSummary),
                      const Divider(height: AppSpacing.lg),
                      _Row(label: 'Province', value: p.province),
                      _Row(label: 'District', value: p.district),
                      _Row(label: 'Sector', value: p.sector),
                      _Row(label: 'Cell', value: p.cell),
                      _Row(label: 'Village / street', value: p.villageStreet),
                    ],
                  ),
                ),
              ),

              // ---- Details -------------------------------------------
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _Row(label: 'Owner / client', value: p.ownerClientName),
                      if (p.createdAt != null)
                        _Row(
                          label: 'Registered',
                          value: DateFormat('d MMM yyyy').format(p.createdAt!),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              const Padding(
                padding: EdgeInsets.only(
                    left: AppSpacing.xxs, bottom: AppSpacing.sm),
                child: Text('Inspection history',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              if (p.recentInspections.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No inspections recorded for this property yet.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                for (final i in p.recentInspections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: AlertTile(
                      title: i.inspectionNumber ?? 'Inspection',
                      subtitle: <String?>[
                        i.loanReference,
                        i.clientName,
                        if (i.createdAt != null)
                          DateFormat('d MMM yyyy').format(i.createdAt!),
                      ].where((s) => s != null && s.isNotEmpty).join(' · '),
                      icon: Icons.assignment_outlined,
                      color: AppColors.primary,
                      onTap: () => context.push(Routes.inspectionDetail(i.id)),
                      trailing: StatusBadge(
                        label: InspectionStatusX.parse(i.status).label,
                        color: InspectionStatusX.parse(i.status).color,
                      ),
                    ),
                  ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: detail.hasValue && canCreate
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(Routes.inspectionNewFor(propertyId)),
                  icon: const Icon(Icons.assignment_add, size: 20),
                  label: const Text('Create inspection'),
                ),
              ),
            )
          : null,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emptyText = '—',
  });

  final String label;
  final String? value;

  /// Shown when the value is null or blank.
  ///
  /// Defaults to an em-dash, but land-registration rows pass "Not recorded"
  /// so the app matches the generated report — in an audit document, an
  /// em-dash is ambiguous between "no value" and "not applicable".
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.trim().isEmpty;
    final display = isEmpty ? emptyText : value!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                // A missing value reads as secondary, so a filled field is
                // scannable at a glance in the field.
                color: isEmpty
                    ? AppColors.textSecondary.withValues(alpha: 0.8)
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- create

class CreatePropertyScreen extends ConsumerStatefulWidget {
  const CreatePropertyScreen({super.key});

  @override
  ConsumerState<CreatePropertyScreen> createState() =>
      _CreatePropertyScreenState();
}

class _CreatePropertyScreenState extends ConsumerState<CreatePropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _province = TextEditingController();
  final _district = TextEditingController();
  final _sector = TextEditingController();
  final _cell = TextEditingController();
  final _village = TextEditingController();
  final _plotNumber = TextEditingController();
  final _titleNumber = TextEditingController();

  PropertyType? _type;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _reference,
      _name,
      _owner,
      _province,
      _district,
      _sector,
      _cell,
      _village,
      _plotNumber,
      _titleNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // The repository returns the SERVER's property, so `reference`,
      // `plotNumber` and `titleNumber` are all present. Never construct a
      // local Property from these form fields — it would silently drop them.
      final property = await ref.read(propertiesRepositoryProvider).create(
            CreatePropertyRequest(
              reference: _reference.text,
              name: _name.text,
              propertyType: _type!,
              ownerClientName: _owner.text,
              province: _province.text,
              district: _district.text,
              sector: _sector.text,
              cell: _cell.text,
              villageStreet: _village.text,
              plotNumber: _plotNumber.text,
              titleNumber: _titleNumber.text,
            ),
          );

      ref.read(propertyListProvider.notifier).prepend(property);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Property ${property.reference} created.')),
      );
      // Straight to detail so the inspector can create an inspection now.
      context.pushReplacement(Routes.propertyDetail(property.id));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New property')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            // ---- Identification ------------------------------------
            const SectionLabel('Identification'),
            SciTextField(
              controller: _reference,
              label: 'PROPERTY REFERENCE (OPTIONAL)',
              hint: 'Auto-generated if left blank',
              icon: Icons.tag_rounded,
              enabled: !_busy,
              helper: 'Leave blank and the server assigns PROP-YYYY-XXXX.',
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _name,
              label: 'PROPERTY NAME / DESCRIPTION',
              hint: 'Kigali Commercial Building',
              icon: Icons.apartment_rounded,
              enabled: !_busy,
              validator: Validators.required('Property name is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'PROPERTY TYPE',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<PropertyType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined, size: 20),
                    hintText: 'Select property type',
                  ),
                  items: <DropdownMenuItem<PropertyType>>[
                    for (final t in PropertyType.values)
                      DropdownMenuItem<PropertyType>(
                          value: t, child: Text(t.label)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _type = v),
                  validator: (v) =>
                      v == null ? 'Property type is required' : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _owner,
              label: 'OWNER / CLIENT NAME',
              hint: 'John Doe',
              icon: Icons.person_outline_rounded,
              enabled: !_busy,
              validator: Validators.required('Owner / client name is required'),
            ),

            // ---- Land registration ---------------------------------
            // Placed immediately after Identification: the plot number and
            // UPI are the parcel's legal identity, and both are mandatory.
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Land information'),
            SciTextField(
              controller: _plotNumber,
              label: 'PLOT NUMBER',
              hint: 'Enter plot number',
              icon: Icons.crop_square_rounded,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              validator: Validators.required('Plot number is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _titleNumber,
              label: 'UPI',
              hint: 'Enter Unique Parcel Identifier',
              icon: Icons.confirmation_number_outlined,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              validator: Validators.required('UPI is required'),
              helper: 'Unique Parcel Identifier from the land title.',
            ),

            // ---- Location ------------------------------------------
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Location'),
            SciTextField(
              controller: _province,
              label: 'PROVINCE',
              hint: 'Kigali',
              icon: Icons.map_outlined,
              enabled: !_busy,
              validator: Validators.required('Province is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _district,
              label: 'DISTRICT',
              hint: 'Gasabo',
              icon: Icons.location_city_outlined,
              enabled: !_busy,
              validator: Validators.required('District is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _sector,
              label: 'SECTOR',
              hint: 'Kimironko',
              icon: Icons.grid_view_outlined,
              enabled: !_busy,
              validator: Validators.required('Sector is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _cell,
              label: 'CELL',
              hint: 'Nyagatovu',
              icon: Icons.hexagon_outlined,
              enabled: !_busy,
              validator: Validators.required('Cell is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _village,
              label: 'VILLAGE / STREET (OPTIONAL)',
              hint: 'KG 11 Ave',
              icon: Icons.signpost_outlined,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
            ),

            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              MessageBanner(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child:
                  _busy ? const ButtonSpinner() : const Text('Create property'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
