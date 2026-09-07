import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../application/session_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/sci_text_field.dart';

/// Login screen matching the specified UI reference — gradient hero, slide-up
/// white card, pill primary button — explicitly WITHOUT social login.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      await ref.read(sessionControllerProvider.notifier).login(
            email: _email.text,
            password: _password.text,
          );
      // Navigation is handled by the router redirect.
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Surface an involuntary sign-out reason, e.g. a revoked session.
    final session = ref.watch(sessionControllerProvider);
    final reason = session is SessionUnauthenticated ? session.reason : null;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue your field inspections.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              SciTextField(
                controller: _email,
                label: 'EMAIL',
                hint: 'Enter your account email',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_submitting,
                autofillHints: const <String>[AutofillHints.username],
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),

              SciTextField(
                controller: _password,
                label: 'PASSWORD',
                hint: 'Enter your account password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                enabled: !_submitting,
                autofillHints: const <String>[AutofillHints.password],
                validator: Validators.required('Password is required'),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => context.push(Routes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),

              if (_error != null || reason != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                _ErrorBanner(message: _error ?? reason!),
              ],

              const SizedBox(height: AppSpacing.md),
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
                    : const Text('Sign in'),
              ),

              const SizedBox(height: AppSpacing.lg),
              // Inspector accounts are provisioned by administrators, so no
              // sign-up tab and — per the design brief — no social login.
              const Text(
                'Inspector accounts are issued by your organisation '
                'administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.danger),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
