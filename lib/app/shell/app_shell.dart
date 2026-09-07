import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/user.dart';
import '../../features/notifications/notifications.dart';
import '../router/routes.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

/// Authenticated shell.
///
/// Uses `StylishBottomBar` in its AnimatedNavigationBar configuration, with a
/// notched centre FAB for the create action — matching the reference design.
///
/// Replaces the previous hand-built `SciBottomNav`. That widget can be deleted
/// once this is in place; nothing else references it.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.child,
    required this.location,
    super.key,
  });

  final Widget child;
  final String location;

  /// Four tabs, because the notch occupies the centre slot. Properties moved
  /// under the FAB action, where property creation already lives.
  static const List<_NavDestination> _destinations = <_NavDestination>[
    _NavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
      route: Routes.home,
    ),
    _NavDestination(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
      label: 'Inspections',
      route: Routes.inspections,
    ),
    _NavDestination(
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment_rounded,
      label: 'Properties',
      route: Routes.properties,
    ),
    _NavDestination(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      label: 'Alerts',
      route: Routes.notifications,
    ),
  ];

  int get _currentIndex {
    final index = _destinations.indexWhere((d) => location.startsWith(d.route));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Required for the notch cut-out to render transparently.
      extendBody: true,
      body: child,

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        tooltip: 'Create property or inspection',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: StylishBottomBar(
        option: AnimatedBarOptions(
          iconSize: 26,
          barAnimation: BarAnimation.blink,
          iconStyle: IconStyle.animated,
        ),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 8,
        // Cuts the circular notch the FAB sits in.
        hasNotch: true,
        fabLocation: StylishBarFabLocation.center,
        currentIndex: _currentIndex,
        notchStyle: NotchStyle.circle,
        onTap: (index) => context.go(_destinations[index].route),
        items: <BottomBarItem>[
          for (var i = 0; i < _destinations.length; i++)
            _buildItem(
              _destinations[i],
              // The unread badge belongs only on Alerts.
              badgeCount:
                  _destinations[i].route == Routes.notifications ? unread : 0,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  BottomBarItem _buildItem(
    _NavDestination destination, {
    required int badgeCount,
    required bool isDark,
  }) {
    return BottomBarItem(
      icon: Icon(destination.icon),
      selectedIcon: Icon(destination.selectedIcon),
      selectedColor: AppColors.primary,
      unSelectedColor:
          isDark ? Colors.white.withValues(alpha: 0.55) : AppColors.offline,
      // Label alongside the icon: icons alone fail the accessibility rule in
      // the spec, and inspectors use this in bright field conditions.
      title: Text(destination.label),
      showBadge: badgeCount > 0,
      badge: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
      badgeColor: AppColors.danger,
      badgePadding: const EdgeInsets.symmetric(horizontal: 4),
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
                leading: const Icon(Icons.add_home_work_outlined,
                    color: AppColors.primary),
                title: const Text('New property'),
                subtitle: const Text('Register a property from the field'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push(Routes.propertyNew);
                },
              ),
            if (canCreateInspection)
              ListTile(
                leading:
                    const Icon(Icons.assignment_add, color: AppColors.primary),
                title: const Text('New inspection'),
                subtitle:
                    const Text('Pick a property, then create the inspection'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  // Inspections are always raised against a property.
                  context.go(Routes.properties);
                },
              ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}
