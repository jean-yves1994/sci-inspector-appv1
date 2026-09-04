import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Constrains the app to phone width in a desktop browser so
/// `flutter run -d chrome` still exercises the real mobile layout.
class MobileFrame extends StatelessWidget {
  const MobileFrame({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width <= 600) return child;

    return ColoredBox(
      color: const Color(0xFFE4E8F2),
      child: Center(
        child: Container(
          width: 460,
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
          child: child,
        ),
      ),
    );
  }
}
