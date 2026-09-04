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
import '../../properties/application/property_providers.dart';
import '../application/inspection_providers.dart';
import '../data/inspections_repository.dart';
import '../domain/inspection.dart';
import '../domain/inspection_status.dart';

// --------------------------------------------------------------- list

class InspectionListScreen extends ConsumerStatefulWidget {
  const InspectionListScreen({super.key});

  @override
  ConsumerState<InspectionListScreen> createState() =>
      _InspectionListScreenState();
}

class _InspectionListScreenState
    extends ConsumerState<InspectionListScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  static const List<(String, InspectionStatus?)> _filters =
      <(String, InspectionStatus?)>[
    ('All', null),
    ('Assigned', InspectionStatus.assigned),
    ('In progress', InspectionStatus.inProgress),
    ('Corrections', InspectionStatus.correctionRequested),
    ('Submitted', InspectionStatus.submitted),
    ('Approved', InspectionStatus.approved),
    ('Rejected', InspectionStatus.rejected),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 400) {
        ref.read(inspectionListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(inspectionListProvider);
    final active = ref.watch(inspectionFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My inspections')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) =>
                  ref.read(inspectionSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Inspection no, loan ref, client, property',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _search,
                  builder: (context, v, _) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _search.clear();
                            ref
                                .read(inspectionSearchProvider.notifier)
                                .state = '';
                          },
                        ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _filters.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final (label, status) = _filters[i];
                return ChoiceChip(
                  label: Text(label),
                  selected: active == status,
                  onSelected: (_) => ref
                      .read(inspectionFilterProvider.notifier)
                      .state = status,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: list.when(
              loading: () => const ListSkeleton(),
              error: (e, _) => ErrorStateView(
                error: e,
                onRetry: () => ref.invalidate(inspectionListProvider),
              ),
              data: (state) => RefreshIndicator(
                onRefresh: ref.read(inspectionListProvider.notifier).refresh,
                child: state.items.isEmpty
                    ? ListView(
                        children: <Widget>[
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.5,
                            child: const EmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No inspections assigned',
                              message:
                                  'You currently have no inspections matching '
                                  'this filter.',
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, 120),
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
                          return InspectionCard(item: state.items[i]);
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

class InspectionCard extends StatelessWidget {
  const InspectionCard({required this.item, super.key});
  final InspectionListItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(Routes.inspectionDetail(item.id)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.propertyReference ??
                          item.inspectionNumber ??
                          'Inspection',
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
                  StatusBadge(
                    label: item.status.label,
                    color: item.status.color,
                    icon: item.status.icon,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.propertyName ?? item.clientName ?? 'Property',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: <Widget>[
                  if (item.loanReference != null) ...<Widget>[
                    const Icon(Icons.receipt_long_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      item.loanReference!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (item.priority != InspectionPriority.normal)
                    StatusBadge(
                      label: item.priority.label,
                      color: item.priority.color,
                    ),
                  const Spacer(),
                  if (item.percentage != null)
                    Text(
                      '${item.percentage}%',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                ],
              ),
              if (item.percentage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: item.percentage! / 100,
                    minHeight: 4,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- detail

class InspectionDetailScreen extends ConsumerWidget {
  const InspectionDetailScreen({required this.inspectionId, super.key});
  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inspectionWorkspaceProvider(inspectionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Inspection')),
      body: state.when(
        loading: () => const ListSkeleton(itemCount: 4, height: 120),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () =>
              ref.invalidate(inspectionWorkspaceProvider(inspectionId)),
        ),
        data: (ws) {
          final i = ws.inspection;
          return ListView(
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
                          Expanded(
                            child: Text(
                              i.inspectionNumber ?? 'Inspection',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          StatusBadge(
                            label: i.status.label,
                            color: i.status.color,
                            icon: i.status.icon,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _kv('Property', i.propertyName),
                      _kv('Property ref', i.propertyReference),
                      _kv('Loan reference', i.loanReference),
                      _kv('Client', i.clientName),
                      _kv('Priority', i.priority.label),
                      if (i.dueDate != null)
                        _kv('Due',
                            DateFormat('d MMM yyyy').format(i.dueDate!)),
                      if (i.submittedAt != null)
                        _kv(
                          'Submitted',
                          DateFormat('d MMM yyyy HH:mm')
                              .format(i.submittedAt!.toLocal()),
                        ),
                      if (i.reviewerName != null &&
                          i.reviewerName!.isNotEmpty)
                        _kv('Reviewer', i.reviewerName),
                    ],
                  ),
                ),
              ),
              if (i.status.isCorrection) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Corrections requested'),
                for (final c in <InspectionComment>[
                  ...i.corrections,
                  ...i.comments
                ])
                  if (c.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AlertTile(
                        title: c.body,
                        subtitle: <String?>[
                          c.author,
                          if (c.createdAt != null)
                            DateFormat('d MMM yyyy')
                                .format(c.createdAt!.toLocal()),
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                        icon: Icons.report_problem_outlined,
                        color: AppColors.warning,
                      ),
                    ),
              ],
              const SizedBox(height: 100),
            ],
          );
        },
      ),
      bottomNavigationBar: state.hasValue
          ? _DetailActions(
              inspectionId: inspectionId,
              status: state.requireValue.inspection.status,
            )
          : null,
    );
  }

  Widget _kv(String k, String? v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 120,
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
                (v == null || v.trim().isEmpty) ? '—' : v,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _DetailActions extends ConsumerStatefulWidget {
  const _DetailActions({required this.inspectionId, required this.status});
  final String inspectionId;
  final InspectionStatus status;

  @override
  ConsumerState<_DetailActions> createState() => _DetailActionsState();
}

class _DetailActionsState extends ConsumerState<_DetailActions> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(inspectionWorkspaceProvider(widget.inspectionId).notifier)
          .start();
      if (mounted) {
        context.push(Routes.inspectionWorkspace(widget.inspectionId));
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
    // Reviewer decisions are never exposed here.
    final Widget? action;
    if (widget.status.canStart) {
      action = FilledButton.icon(
        onPressed: _busy ? null : _start,
        icon: _busy
            ? const ButtonSpinner()
            : const Icon(Icons.play_arrow_rounded),
        label: const Text('Start inspection'),
      );
    } else if (widget.status.isEditable) {
      action = FilledButton.icon(
        onPressed: () =>
            context.push(Routes.inspectionWorkspace(widget.inspectionId)),
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: Text(widget.status.isCorrection
            ? 'Open corrections'
            : 'Continue inspection'),
      );
    } else {
      action = OutlinedButton.icon(
        onPressed: () =>
            context.push(Routes.inspectionWorkspace(widget.inspectionId)),
        icon: const Icon(Icons.visibility_outlined, size: 20),
        label: const Text('View inspection'),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: action,
      ),
    );
  }
}

// ------------------------------------------------------------- create

class CreateInspectionScreen extends ConsumerStatefulWidget {
  const CreateInspectionScreen({required this.propertyId, super.key});
  final String propertyId;

  @override
  ConsumerState<CreateInspectionScreen> createState() =>
      _CreateInspectionScreenState();
}

class _CreateInspectionScreenState
    extends ConsumerState<CreateInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loanRef = TextEditingController();
  final _client = TextEditingController();
  final _notes = TextEditingController();
  InspectionPriority _priority = InspectionPriority.normal;
  DateTime? _dueDate;
  bool _busy = false;
  String? _error;
  bool _seeded = false;

  @override
  void dispose() {
    _loanRef.dispose();
    _client.dispose();
    _notes.dispose();
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
      final created =
          await ref.read(inspectionsRepositoryProvider).create(
                propertyId: widget.propertyId,
                loanReference: _loanRef.text,
                clientName: _client.text,
                priority: _priority.wire,
                dueDate: _dueDate,
                notes: _notes.text,
              );
      ref.invalidate(inspectionListProvider);
      if (!mounted) return;
      // Straight to detail so the inspector can start immediately.
      context.pushReplacement(Routes.inspectionDetail(created.id));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = ref.watch(propertyDetailProvider(widget.propertyId));
    final canCreate =
        ref.watch(hasPermissionProvider(Permissions.inspectionsCreate));

    // Prefill the client from the property owner as a convenience.
    property.whenData((p) {
      if (!_seeded && _client.text.isEmpty) {
        _seeded = true;
        _client.text = p.ownerClientName;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('New inspection')),
      body: !canCreate
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Not permitted',
              message:
                  'Your account cannot create inspections.',
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  property.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (p) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.apartment_rounded,
                            color: AppColors.primary),
                        title: Text(p.name),
                        subtitle: Text(p.reference),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SciTextField(
                    controller: _loanRef,
                    label: 'LOAN REFERENCE',
                    hint: 'LOAN-2026-001',
                    icon: Icons.receipt_long_outlined,
                    enabled: !_busy,
                    validator:
                        Validators.required('Loan reference is required'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SciTextField(
                    controller: _client,
                    label: 'CLIENT NAME',
                    icon: Icons.person_outline_rounded,
                    enabled: !_busy,
                    validator:
                        Validators.required('Client name is required'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'PRIORITY',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<InspectionPriority>(
                        initialValue: _priority,
                        isExpanded: true,
                        items: <DropdownMenuItem<InspectionPriority>>[
                          for (final p in InspectionPriority.values)
                            DropdownMenuItem<InspectionPriority>(
                                value: p, child: Text(p.label)),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(
                                () => _priority = v ?? _priority),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'DUE DATE (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: _busy
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate ?? now,
                                  firstDate: now,
                                  lastDate: DateTime(now.year + 3),
                                );
                                if (picked != null) {
                                  setState(() => _dueDate = picked);
                                }
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon:
                                Icon(Icons.event_outlined, size: 20),
                          ),
                          child: Text(
                            _dueDate == null
                                ? 'Select a due date'
                                : DateFormat('d MMM yyyy').format(_dueDate!),
                            style: TextStyle(
                              fontSize: 14,
                              color: _dueDate == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SciTextField(
                    controller: _notes,
                    label: 'NOTES (OPTIONAL)',
                    enabled: !_busy,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // No assignee or reviewer picker: the backend assigns the
                  // creating inspector automatically.
                  const MessageBanner(
                    message: 'This inspection will be assigned to you '
                        'automatically.',
                    color: AppColors.primary,
                    icon: Icons.info_outline_rounded,
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    MessageBanner(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const ButtonSpinner()
                        : const Text('Create inspection'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
