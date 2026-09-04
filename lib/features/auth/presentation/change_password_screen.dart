import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../application/session_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/sci_text_field.dart';

/// Forced when `user.mustChangePassword == true` (spec section 11).
/// The router redirect prevents leaving this screen until it succeeds.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(sessionControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      // Router redirect takes over once mustChangePassword flips to false.
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final forced = user?.mustChangePassword ?? false;

    return AuthScaffold(
      title: forced ? 'Update your password' : 'Change password',
      subtitle: forced
          ? 'Your organisation requires a new password before you continue.'
          : 'Choose a new password for your SCI account.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SciTextField(
              controller: _current,
              label: 'CURRENT PASSWORD',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              enabled: !_submitting,
              validator: Validators.required('Current password is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _next,
              label: 'NEW PASSWORD',
              icon: Icons.lock_person_outlined,
              obscureText: _obscure,
              enabled: !_submitting,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _confirm,
              label: 'CONFIRM NEW PASSWORD',
              icon: Icons.lock_reset_rounded,
              obscureText: _obscure,
              enabled: !_submitting,
              validator: Validators.matches(
                () => _next.text,
                'Passwords do not match',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Update password'),
            ),
            if (forced) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () =>
                        ref.read(sessionControllerProvider.notifier).logout(),
                child: const Text('Sign out instead'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
