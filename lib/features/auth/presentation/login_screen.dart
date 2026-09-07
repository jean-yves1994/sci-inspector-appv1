import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/sci_widgets.dart';
import '../application/session_controller.dart';
import 'auth_scaffold.dart';

/// Sign-in screen.
///
/// No social login, per the design brief — inspector accounts are provisioned
/// by an administrator.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
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
      await ref
          .read(sessionControllerProvider.notifier)
          .login(email: _email.text, password: _password.text);
      // Navigation is handled by the router redirect.
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
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

      // Pinned to the bottom of the card by the scaffold's Spacer, rather
      // than floating directly under the button with dead space beneath.
      footer: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Inspector accounts are issued by your organisation '
                    'administrator.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Smart Collateral Inspection',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),

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
                hint: 'inspector@sci.rw',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
                autofillHints: const <String>[AutofillHints.username],
                validator: Validators.email,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.md),

              SciTextField(
                controller: _password,
                focusNode: _passwordFocus,
                label: 'PASSWORD',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                enabled: !_busy,
                autofillHints: const <String>[AutofillHints.password],
                validator: Validators.required('Password is required'),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      _busy ? null : () => context.push(Routes.forgotPassword),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),

              if (_error != null || reason != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                MessageBanner(message: _error ?? reason!),
              ],

              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const ButtonSpinner()
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
