import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Constrains the app to a phone-width column when running in a desktop
/// browser, so `flutter run -d chrome` still exercises the real mobile layout
/// instead of stretching it (spec section 67).
///
/// This is intentionally NOT a separate desktop design.
class MobileFrame extends StatelessWidget {
  const MobileFrame({required this.child, super.key});

  final Widget child;

  static const double _maxWidth = 480;
  static const double _breakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _breakpoint) return child;

    return ColoredBox(
      color: const Color(0xFFE4E8F2),
      child: Center(
        child: Container(
          width: _maxWidth,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ),
    );
  }
}
