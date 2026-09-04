import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SciNavItem {
  const SciNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}

/// Floating, rounded, detached bottom bar with an animated pill indicator and
/// a raised centre action — matching the cybersecurity UI reference.
class SciBottomNav extends StatelessWidget {
  const SciBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.onPrimaryAction,
    this.notificationBadgeCount = 0,
    super.key,
  });

  final List<SciNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onPrimaryAction;
  final int notificationBadgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: <Widget>[
            Container(
              height: 68,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < items.length; i++) ...<Widget>[
                    if (i == items.length ~/ 2) const SizedBox(width: 60),
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        selected: i == currentIndex,
                        badgeCount: items[i].label == 'Alerts'
                            ? notificationBadgeCount
                            : 0,
                        onTap: () => onSelected(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: -18,
              child: Semantics(
                button: true,
                label: 'Create new property or inspection',
                child: GestureDetector(
                  onTap: onPrimaryAction,
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.primaryLight,
                          AppColors.primary,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.badgeCount,
  });

  final SciNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SizedBox(
          height: AppSpacing.touchTarget,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(
                horizontal: 2, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                      .withValues(alpha: isDark ? 0.22 : 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                  backgroundColor: AppColors.danger,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 20,
                    color: selected ? AppColors.primary : inactive,
                  ),
                ),
                const SizedBox(height: 2),
                // Icons plus text, never icons alone.
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.1,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : inactive,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
