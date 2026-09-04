import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_widgets.dart';
import '../auth/application/session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, 120),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 28,
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
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          children: <Widget>[
                            for (final r in user?.roles ?? <String>[])
                              StatusBadge(
                                label:
                                    r == 'INSPECTOR' ? 'Inspector' : r,
                                color: AppColors.primary,
                                icon: Icons.verified_user_outlined,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AlertTile(
            title: 'Change password',
            subtitle: 'Update your SCI account password',
            icon: Icons.lock_outline_rounded,
            color: AppColors.primary,
            onTap: () => context.push(Routes.changePassword),
          ),
          const SizedBox(height: AppSpacing.xs),
          AlertTile(
            title: 'Environment',
            subtitle: '${AppConfig.environment} · ${AppConfig.platform}',
            icon: Icons.dns_outlined,
            color: AppColors.violet,
          ),
          const SizedBox(height: AppSpacing.xs),
          AlertTile(
            title: 'Sign out',
            subtitle: 'End this session on this device',
            icon: Icons.logout_rounded,
            color: AppColors.danger,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                      'You will need to sign in again to continue your '
                      'inspections.'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(c).pop(true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (ok ?? false) {
                await ref.read(sessionControllerProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}
