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
import '../data/rwanda_locations_repository.dart';
import '../domain/property.dart';

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
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400)
      ref.read(propertyListProvider.notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(propertyListProvider);
    final term = ref.watch(propertySearchProvider);
    final canCreate =
        ref.watch(hasPermissionProvider(Permissions.propertiesWrite));
    return Scaffold(
      appBar: AppBar(title: const Text('Properties'), actions: [
        if (canCreate)
          IconButton(
              tooltip: 'New property',
              onPressed: () => context.push(Routes.propertyNew),
              icon: const Icon(Icons.add_rounded)),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: TextField(
            controller: _search,
            onChanged: ref.read(propertySearchProvider.notifier).onChanged,
            decoration: InputDecoration(
              hintText: 'Search reference, owner, UPI or location',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _search.clear();
                        ref.read(propertySearchProvider.notifier).clear();
                        setState(() {});
                      }),
            ),
          ),
        ),
        Expanded(
            child: list.when(
          loading: () => const ListSkeleton(),
          error: (e, _) => ErrorStateView(
              error: e, onRetry: () => ref.invalidate(propertyListProvider)),
          data: (state) => RefreshIndicator(
            onRefresh: ref.read(propertyListProvider.notifier).refresh,
            child: state.items.isEmpty
                ? ListView(children: [
                    SizedBox(
                        height: MediaQuery.sizeOf(context).height * .55,
                        child: EmptyState(
                            icon: Icons.apartment_outlined,
                            title: term.isEmpty
                                ? 'No properties yet'
                                : 'No properties found',
                            message: term.isEmpty
                                ? 'Register a property to start an inspection.'
                                : 'Try another search.',
                            actionLabel: canCreate ? '+ New property' : null,
                            onAction: canCreate
                                ? () => context.push(Routes.propertyNew)
                                : null))
                  ])
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.xs, AppSpacing.md, 120),
                    itemCount: state.items.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (i == state.items.length)
                        return state.isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)))
                            : const SizedBox.shrink();
                      return _PropertyCard(property: state.items[i]);
                    },
                  ),
          ),
        )),
      ]),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});
  final Property property;
  @override
  Widget build(BuildContext context) => Card(
          child: InkWell(
        onTap: () => context.push(Routes.propertyDetail(property.id)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.apartment_rounded,
                    size: 22, color: AppColors.primary)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
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
                                color: AppColors.primary))),
                    if (property.propertyType != null)
                      StatusBadge(
                          label: property.propertyType!.label,
                          color: AppColors.violet)
                  ]),
                  const SizedBox(height: 2),
                  Text(property.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  _Meta(
                      icon: Icons.person_outline_rounded,
                      text: property.ownerClientName.isEmpty
                          ? 'Owner not recorded'
                          : property.ownerClientName),
                  _Meta(
                      icon: Icons.place_outlined,
                      text: property.locationSummary),
                  if (property.titleNumber?.trim().isNotEmpty ?? false)
                    _Meta(
                        icon: Icons.confirmation_number_outlined,
                        text: 'UPI ${property.titleNumber!.trim()}'),
                ])),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textSecondary),
          ]),
        ),
      ));
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)))
      ]));
}

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
            onRetry: () => ref.invalidate(propertyDetailProvider(propertyId))),
        data: (p) => RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(propertyDetailProvider(propertyId)),
            child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                      height: 48,
                                      width: 48,
                                      decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: .10),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.md)),
                                      child: const Icon(Icons.apartment_rounded,
                                          color: AppColors.primary)),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(p.reference,
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary)),
                                        Text(p.name,
                                            style: const TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w800))
                                      ]))
                                ]),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(spacing: AppSpacing.xs, children: [
                                  if (p.propertyType != null)
                                    StatusBadge(
                                        label: p.propertyType!.label,
                                        color: AppColors.violet,
                                        icon: Icons.category_outlined),
                                  if (p.branchName != null)
                                    StatusBadge(
                                        label: p.branchName!,
                                        color: AppColors.primary,
                                        icon: Icons.account_balance_outlined),
                                  if (p.hasCoordinates)
                                    const StatusBadge(
                                        label: 'Coordinates on file',
                                        color: AppColors.success,
                                        icon: Icons.gps_fixed_rounded)
                                ])
                              ]))),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Land information',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: AppSpacing.sm),
                                _Row(
                                    label: 'UPI',
                                    value: p.titleNumber,
                                    emptyText: 'Not recorded'),
                              ]))),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Administrative location',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: AppSpacing.sm),
                                _Row(
                                    label: 'Location',
                                    value: p.locationSummary),
                                const Divider(height: AppSpacing.lg),
                                _Row(label: 'Province', value: p.province),
                                _Row(label: 'District', value: p.district),
                                _Row(label: 'Sector', value: p.sector),
                                _Row(label: 'Cell', value: p.cell),
                                _Row(
                                    label: 'Village / street',
                                    value: p.villageStreet),
                              ]))),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Details',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: AppSpacing.sm),
                                _Row(
                                    label: 'Owner / client',
                                    value: p.ownerClientName),
                                if (p.createdAt != null)
                                  _Row(
                                      label: 'Registered',
                                      value: DateFormat('d MMM yyyy')
                                          .format(p.createdAt!)),
                              ]))),
                  const SizedBox(height: AppSpacing.md),
                  const Padding(
                      padding: EdgeInsets.only(
                          left: AppSpacing.xxs, bottom: AppSpacing.sm),
                      child: Text('Inspection history',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800))),
                  if (p.recentInspections.isEmpty)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                                'No inspections recorded for this property yet.',
                                style:
                                    TextStyle(color: AppColors.textSecondary))))
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
                                  DateFormat('d MMM yyyy').format(i.createdAt!)
                              ]
                                  .where((s) => s != null && s.isNotEmpty)
                                  .join(' · '),
                              icon: Icons.assignment_outlined,
                              color: AppColors.primary,
                              onTap: () =>
                                  context.push(Routes.inspectionDetail(i.id)),
                              trailing: StatusBadge(
                                  label:
                                      InspectionStatusX.parse(i.status).label,
                                  color: InspectionStatusX.parse(i.status)
                                      .color))),
                  const SizedBox(height: AppSpacing.xxxl),
                ])),
      ),
      bottomNavigationBar: detail.hasValue && canCreate
          ? SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton.icon(
                      onPressed: () =>
                          context.push(Routes.inspectionNewFor(propertyId)),
                      icon: const Icon(Icons.assignment_add, size: 20),
                      label: const Text('Create inspection'))))
          : null,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.emptyText = '—'});
  final String label;
  final String? value;
  final String emptyText;
  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.trim().isEmpty;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600))),
          Expanded(
              child: Text(empty ? emptyText : value!,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: empty
                          ? AppColors.textSecondary
                          : AppColors.textPrimary)))
        ]));
  }
}

class CreatePropertyScreen extends ConsumerStatefulWidget {
  const CreatePropertyScreen({super.key});
  @override
  ConsumerState<CreatePropertyScreen> createState() =>
      _CreatePropertyScreenState();
}

class _CreatePropertyScreenState extends ConsumerState<CreatePropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  String? _province;
  String? _provinceCode;
  String? _district;
  String? _districtCode;
  String? _sector;
  String? _sectorCode;
  String? _cell;
  List<RwandaLocation> _provinces = [];
  List<RwandaLocation> _districts = [];
  List<RwandaLocation> _sectors = [];
  List<RwandaLocation> _cells = [];
  bool _locationsLoading = true;
  String? _locationError;
  final _upi = TextEditingController();
  PropertyType? _type;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    try {
      final items = await ref.read(rwandaLocationsRepositoryProvider).provinces();
      if (!mounted) return;
      setState(() { _provinces = items; _locationsLoading = false; _locationError = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _locationsLoading = false; _locationError = 'Unable to load locations. Check your connection and retry.'; });
    }
  }

  Future<void> _selectProvince(RwandaLocation? value) async {
    setState(() {
      _province = value?.name; _provinceCode = value?.code;
      _district = null; _districtCode = null; _districts = [];
      _sector = null; _sectorCode = null; _sectors = [];
      _cell = null; _cells = [];
      _locationError = null;
    });
    if (value == null) return;
    try {
      final items = await ref.read(rwandaLocationsRepositoryProvider).districts(value.code);
      if (mounted && _provinceCode == value.code) setState(() => _districts = items);
    } catch (_) { if (mounted) setState(() => _locationError = 'Could not load districts. Please retry.'); }
  }

  Future<void> _selectDistrict(RwandaLocation? value) async {
    setState(() {
      _district = value?.name; _districtCode = value?.code;
      _sector = null; _sectorCode = null; _sectors = [];
      _cell = null; _cells = []; _locationError = null;
    });
    if (value == null) return;
    try {
      final items = await ref.read(rwandaLocationsRepositoryProvider).sectors(value.code);
      if (mounted && _districtCode == value.code) setState(() => _sectors = items);
    } catch (_) { if (mounted) setState(() => _locationError = 'Could not load sectors. Please retry.'); }
  }

  Future<void> _selectSector(RwandaLocation? value) async {
    setState(() {
      _sector = value?.name; _sectorCode = value?.code;
      _cell = null; _cells = []; _locationError = null;
    });
    if (value == null) return;
    try {
      final items = await ref.read(rwandaLocationsRepositoryProvider).cells(value.code);
      if (mounted && _sectorCode == value.code) setState(() => _cells = items);
    } catch (_) { if (mounted) setState(() => _locationError = 'Could not load cells. Please retry.'); }
  }

  Future<void> _selectCell(RwandaLocation value) async {
    setState(() => _cell = value.name);
  }

  Future<void> _reloadCurrentLevel() async {
    if (_provinceCode == null) return _loadProvinces();
    if (_districtCode == null) return _selectProvince(_provinces.firstWhere((e) => e.code == _provinceCode));
    if (_sectorCode == null) return _selectDistrict(_districts.firstWhere((e) => e.code == _districtCode));
    return _selectSector(_sectors.firstWhere((e) => e.code == _sectorCode));
  }

  Future<void> _chooseLocation({
    required String label,
    required List<RwandaLocation> items,
    required String? selected,
    required ValueChanged<RwandaLocation> onSelected,
    bool searchable = false,
  }) async {
    final picked = await showModalBottomSheet<RwandaLocation>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LocationPickerSheet(title: label, items: items, searchable: searchable),
    );
    if (picked != null) onSelected(picked);
  }

  Widget _locationField({
    required String label,
    required String? value,
    required List<RwandaLocation> items,
    required VoidCallback? onTap,
    required String? Function(String?) validator,
    required IconData icon,
  }) => FormField<String>(
    key: ValueKey<String?>(value),
    initialValue: value,
    validator: validator,
    builder: (field) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.xs),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InputDecorator(
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: 'Select ${label.toLowerCase()}',
            errorText: field.errorText,
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          ),
          child: Text(value ?? '', style: TextStyle(color: value == null ? AppColors.textSecondary : AppColors.textPrimary)),
        ),
      ),
    ]),
  );

  @override
  void dispose() {
    for (final c in [
      _name,
      _owner,
      _upi
    ]) c.dispose();
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
      final property = await ref
          .read(propertiesRepositoryProvider)
          .create(CreatePropertyRequest(
            name: _name.text,
            propertyType: _type!,
            ownerClientName: _owner.text,
            province: _province!,
            district: _district!,
            sector: _sector!,
            cell: _cell!,
            titleNumber: _upi.text,
          ));
      ref.read(propertyListProvider.notifier).prepend(property);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Property ${property.reference} created.')));
      context.pushReplacement(Routes.propertyDetail(property.id));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New property')),
        body: Form(
            key: _formKey,
            child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  const SectionLabel('Identification'),
                  SciTextField(
                      controller: _name,
                      label: 'PROPERTY NAME / DESCRIPTION',
                      hint: 'Kigali Commercial Building',
                      icon: Icons.apartment_rounded,
                      enabled: !_busy,
                      validator:
                          Validators.required('Property name is required')),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PROPERTY TYPE',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<PropertyType>(
                            initialValue: _type,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                prefixIcon:
                                    Icon(Icons.category_outlined, size: 20),
                                hintText: 'Select property type'),
                            items: [
                              for (final t in PropertyType.values)
                                DropdownMenuItem(value: t, child: Text(t.label))
                            ],
                            onChanged:
                                _busy ? null : (v) => setState(() => _type = v),
                            validator: (v) =>
                                v == null ? 'Property type is required' : null)
                      ]),
                  const SizedBox(height: AppSpacing.md),
                  SciTextField(
                      controller: _owner,
                      label: 'OWNER / CLIENT NAME',
                      hint: 'John Doe',
                      icon: Icons.person_outline_rounded,
                      enabled: !_busy,
                      validator: Validators.required(
                          'Owner / client name is required')),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Land information'),
                  SciTextField(
                      controller: _upi,
                      label: 'UPI',
                      hint: 'Enter Unique Parcel Identifier',
                      icon: Icons.confirmation_number_outlined,
                      enabled: !_busy,
                      validator: Validators.required('UPI is required'),
                      helper:
                          'UPI is the only land identifier required. Please fill it in very carefully.'),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Location'),
                  if (_locationsLoading)
                    const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator()))
                  else ...[
                    _locationField(label: 'PROVINCE', value: _province, items: _provinces, icon: Icons.map_outlined, onTap: _busy || _provinces.isEmpty ? null : () => _chooseLocation(label: 'Province', items: _provinces, selected: _province, onSelected: _selectProvince), validator: Validators.required('Province is required')),
                    const SizedBox(height: AppSpacing.md),
                    _locationField(label: 'DISTRICT', value: _district, items: _districts, icon: Icons.location_city_outlined, onTap: _busy || _provinceCode == null || _districts.isEmpty ? null : () => _chooseLocation(label: 'District', items: _districts, selected: _district, searchable: true, onSelected: _selectDistrict), validator: Validators.required('District is required')),
                    const SizedBox(height: AppSpacing.md),
                    _locationField(label: 'SECTOR', value: _sector, items: _sectors, icon: Icons.grid_view_outlined, onTap: _busy || _districtCode == null || _sectors.isEmpty ? null : () => _chooseLocation(label: 'Sector', items: _sectors, selected: _sector, searchable: true, onSelected: _selectSector), validator: Validators.required('Sector is required')),
                    const SizedBox(height: AppSpacing.md),
                    _locationField(label: 'CELL', value: _cell, items: _cells, icon: Icons.hexagon_outlined, onTap: _busy || _sectorCode == null || _cells.isEmpty ? null : () => _chooseLocation(label: 'Cell', items: _cells, selected: _cell, searchable: true, onSelected: _selectCell), validator: Validators.required('Cell is required')),
                    if (_locationError != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      MessageBanner(message: _locationError!),
                      TextButton.icon(onPressed: _provinceCode == null ? _loadProvinces : _reloadCurrentLevel, icon: const Icon(Icons.refresh), label: const Text('Retry location loading')),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: const Text(
                          'Property reference is generated automatically by the server from the owner name and creation date. It is not entered or edited here.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary))),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    MessageBanner(message: _error!)
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const ButtonSpinner()
                          : const Text('Create property')),
                  const SizedBox(height: AppSpacing.xl),
                ])),
      );
}


class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({required this.title, required this.items, required this.searchable});
  final String title;
  final List<RwandaLocation> items;
  final bool searchable;
  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((item) => item.name.toLowerCase().contains(query.trim().toLowerCase())).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .68,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Select ${widget.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (widget.searchable) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name')),
            ],
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: filtered.isEmpty
              ? const Center(child: Text('No matching locations found'))
              : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) {
                  final item = filtered[index];
                  return ListTile(title: Text(item.name), onTap: () => Navigator.pop(context, item));
                })),
          ]),
        ),
      ),
    );
  }
}
