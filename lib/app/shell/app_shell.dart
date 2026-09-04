import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/user.dart';
import '../router/routes.dart';
import 'sci_bottom_nav.dart';

/// Authenticated shell hosting the five tabs plus the raised primary action.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.child,
    required this.location,
    super.key,
  });

  final Widget child;
  final String location;

  static const List<SciNavItem> _items = <SciNavItem>[
    SciNavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Home',
      route: Routes.home,
    ),
    SciNavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: 'Inspections',
      route: Routes.inspections,
    ),
    SciNavItem(
      icon: Icons.apartment_outlined,
      activeIcon: Icons.apartment_rounded,
      label: 'Properties',
      route: Routes.properties,
    ),
    SciNavItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      label: 'Alerts',
      route: Routes.notifications,
    ),
    SciNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
      route: Routes.profile,
    ),
  ];

  int get _currentIndex {
    final index = _items.indexWhere((i) => location.startsWith(i.route));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SciBottomNav(
        items: _items,
        currentIndex: _currentIndex,
        onSelected: (i) => context.go(_items[i].route),
        onPrimaryAction: () => _showCreateSheet(context, ref),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    // Permission-gated: only render actions the backend actually grants.
    final canCreateProperty =
        ref.read(hasPermissionProvider(Permissions.propertiesWrite));
    final canCreateInspection =
        ref.read(hasPermissionProvider(Permissions.inspectionsCreate));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (canCreateProperty)
              ListTile(
                leading: const Icon(Icons.add_home_work_outlined),
                title: const Text('New property'),
                subtitle: const Text('Register a property from the field'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  // Phase 2 wires this to /properties/new.
                  _notImplemented(context, 'Create property (Phase 2)');
                },
              ),
            if (canCreateInspection)
              ListTile(
                leading: const Icon(Icons.assignment_add),
                title: const Text('New inspection'),
                subtitle: const Text('Assigned to you automatically'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  // Phase 3 wires this to the create-inspection flow.
                  _notImplemented(context, 'Create inspection (Phase 3)');
                },
              ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  void _notImplemented(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is not implemented yet.')),
    );
  }
}
