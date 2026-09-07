import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../features/auth/application/session_controller.dart';
import '../theme/app_theme.dart';

/// Account avatar with a menu — the entry point to Profile now that the
/// bottom bar has four tabs and a notch.
///
/// Used in two places with different layout needs:
///
///   * the Home header card, where it LEADS a row  -> no trailing padding
///   * other tabs' `AppBar.actions`, where it trails -> trailing padding
class AccountAvatar extends ConsumerWidget {
  const AccountAvatar({
    this.radius = 18,
    this.showTrailingPadding = true,
    super.key,
  });

  final double radius;

  /// False when the avatar leads a row rather than sitting in `actions`.
  /// Defaults to true, so existing `AppBar` uses are unaffected.
  final bool showTrailingPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Padding(
      padding: EdgeInsets.only(
        right: showTrailingPadding ? AppSpacing.md : 0,
      ),
      child: Semantics(
        button: true,
        label: 'Account menu for ${user?.fullName ?? 'your account'}',
        child: InkWell(
          onTap: () => _showMenu(context, ref),
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: user?.fullName ?? 'Account',
            child: CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                user?.initials ?? '?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: radius * 0.72,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Identity header — confirms which account is signed in before
            // any destructive action is offered.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          user?.fullName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (user?.isInspector ?? false)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Inspector',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Profile'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(Routes.profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Change password'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(Routes.changePassword);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text(
                'Sign out',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _confirmSignOut(context, ref);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Any unsynced work will remain on this device until you sign in '
          'again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}
