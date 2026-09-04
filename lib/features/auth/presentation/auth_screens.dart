import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/sci_widgets.dart';
import '../application/session_controller.dart';
import '../data/auth_repository.dart';

/// Shared auth layout: deep-blue gradient hero with a white rounded card
/// sliding up over it. Matches the login UI reference — no social login.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.authHeroGradient,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              FadeTransition(
                opacity: _fade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xs,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (widget.onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.white,
                            tooltip: 'Back',
                          ),
                        ),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 14.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.authCard),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.xxl,
                          AppSpacing.xl,
                          AppSpacing.xl +
                              MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            widget.child,
                            if (AppConfig.isInsecureWebSession) ...<Widget>[
                              const SizedBox(height: AppSpacing.lg),
                              const MessageBanner(
                                message:
                                    'Development web session. Tokens are held '
                                    'in memory only and clear on reload.',
                                color: AppColors.warning,
                                icon: Icons.info_outline_rounded,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- login

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
  bool _busy = false;
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
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(email: _email.text, password: _password.text);
      // Router redirect handles navigation.
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                hint: 'inspector@sci.rw',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
                autofillHints: const <String>[AutofillHints.username],
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              SciTextField(
                controller: _password,
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
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error != null || reason != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                MessageBanner(message: _error ?? reason!),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy ? const ButtonSpinner() : const Text('Sign in'),
              ),
              const SizedBox(height: AppSpacing.lg),
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

// ------------------------------------------------------- forgot password

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'We will send a reset link to your registered email.',
      onBack: () => context.pop(),
      child: _sent
          ? Column(
              children: <Widget>[
                const Icon(Icons.mark_email_read_outlined,
                    size: 46, color: AppColors.success),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Check your email',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'If an account exists for ${_email.text.trim()}, a reset '
                  'link has been sent.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => context.go(Routes.login),
                  child: const Text('Back to sign in'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SciTextField(
                    controller: _email,
                    label: 'EMAIL',
                    hint: 'inspector@sci.rw',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    validator: Validators.email,
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    MessageBanner(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const ButtonSpinner()
                        : const Text('Send reset link'),
                  ),
                ],
              ),
            ),
    );
  }
}

// -------------------------------------------------------- reset password

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({this.token, super.key});
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _token =
      TextEditingController(text: widget.token ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: _token.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Please sign in.')),
      );
      context.go(Routes.login);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Set new password',
      subtitle: 'Enter the reset code sent to your email.',
      onBack: () => context.go(Routes.login),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SciTextField(
              controller: _token,
              label: 'RESET CODE',
              icon: Icons.key_outlined,
              enabled: !_busy,
              validator: Validators.required('Reset code is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _password,
              label: 'NEW PASSWORD',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              enabled: !_busy,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _confirm,
              label: 'CONFIRM NEW PASSWORD',
              icon: Icons.lock_reset_rounded,
              obscureText: _obscure,
              enabled: !_busy,
              validator: Validators.matches(
                  () => _password.text, 'Passwords do not match'),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              MessageBanner(message: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child:
                  _busy ? const ButtonSpinner() : const Text('Reset password'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- change password

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password updated.')));
      if (context.canPop()) context.pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forced = ref.watch(currentUserProvider)?.mustChangePassword ?? false;

    return AuthScaffold(
      title: forced ? 'Update your password' : 'Change password',
      subtitle: forced
          ? 'Your organisation requires a new password before you continue.'
          : 'Choose a new password for your SCI account.',
      onBack: forced ? null : () => context.pop(),
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
              enabled: !_busy,
              validator: Validators.required('Current password is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _next,
              label: 'NEW PASSWORD',
              icon: Icons.lock_person_outlined,
              obscureText: _obscure,
              enabled: !_busy,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            SciTextField(
              controller: _confirm,
              label: 'CONFIRM NEW PASSWORD',
              icon: Icons.lock_reset_rounded,
              obscureText: _obscure,
              enabled: !_busy,
              validator: Validators.matches(
                  () => _next.text, 'Passwords do not match'),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              MessageBanner(message: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const ButtonSpinner()
                  : const Text('Update password'),
            ),
            if (forced) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _busy
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
