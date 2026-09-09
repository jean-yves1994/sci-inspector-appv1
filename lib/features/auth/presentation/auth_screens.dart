import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/sci_widgets.dart';
import '../application/session_controller.dart';
import '../data/auth_repository.dart';

// ===========================================================================
// Shared layout
// ===========================================================================

/// Shared layout for the authentication screens.
///
/// The previous version placed the form in a bare `SingleChildScrollView`.
/// A scroll view sizes to its CONTENT, so on a tall screen the form bunched
/// at the top and left a large void beneath it.
///
/// This uses `LayoutBuilder` + `ConstrainedBox(minHeight)` + `IntrinsicHeight`
/// so the column always fills the card. That is what lets `Spacer()` work —
/// the form sits at the top, the footer pins to the bottom, and the space
/// distributes between them. It still scrolls when the keyboard opens.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;

  /// Main form content, in the upper portion of the card.
  final Widget child;

  /// Pinned to the bottom of the card, above the safe-area inset.
  final Widget? footer;

  final VoidCallback? onBack;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardInset > 0;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.authHeroGradient,
          ),
        ),
        child: Stack(
          children: <Widget>[
            // Hero sits behind the card, top-aligned inside the safe area.
            SafeArea(
              bottom: false,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isKeyboardOpen ? 0 : 1,
                child: FadeTransition(
                  opacity: _fade,
                  child: _Hero(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    onBack: widget.onBack,
                  ),
                ),
              ),
            ),

            // Card pinned to the bottom, occupying a fixed share of the
            // screen. Expanded previously let it consume ALL remaining space,
            // which is why the form floated in a tall, mostly empty panel.
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                // 60% normally; grows when the keyboard is up so the fields
                // and button stay reachable.
                heightFactor: isKeyboardOpen ? 0.92 : 0.65,
                widthFactor: 1,
                child: SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.authCard),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: keyboardInset),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  AppSpacing.xl,
                                  AppSpacing.xl,
                                  AppSpacing.xl,
                                  AppSpacing.lg +
                                      MediaQuery.paddingOf(context).bottom,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    // Two spacers around the form centre it
                                    // in the space above the footer, rather
                                    // than pinning it to the top with a void
                                    // beneath.
                                    const Spacer(flex: 2),

                                    widget.child,

                                    const Spacer(flex: 3),
                                    if (widget.footer != null) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      widget.footer!,
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle, this.onBack});

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, // left  24
        AppSpacing.xxxl, // top   24  <-- clears the notch / status bar
        AppSpacing.xl, // right 24
        AppSpacing.xl, // bottom 24
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),

          // Brand mark. The auth screens were the only place in the app with
          // no SCI identity, which is an odd gap on the screen that carries
          // the most trust weight.
          Row(
            children: <Widget>[
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'SCI',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Smart Collateral Inspection',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxxl),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet informational note for the card footer.
///
/// The "accounts are issued by your administrator" line previously sat in a
/// warning-orange `MessageBanner`, which reads as an error. It is neutral
/// information, so it is styled as a footnote.
class _FooterNote extends StatelessWidget {
  const _FooterNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
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
    );
  }
}

// ===========================================================================
// Login
// ===========================================================================

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
      footer: const _FooterNote(
        'Inspector accounts are issued by your organisation administrator.',
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
                hint: 'Enter your account email',
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
                hint: 'Enter your account password',
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
                child: _busy ? const ButtonSpinner() : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Forgot password
// ===========================================================================

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
    FocusScope.of(context).unfocus();
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
      child: _sent ? _sentState(context) : _formState(),
    );
  }

  Widget _formState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SciTextField(
            controller: _email,
            label: 'EMAIL',
            hint: 'Enter your account email',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !_busy,
            validator: Validators.email,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            MessageBanner(message: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child:
                _busy ? const ButtonSpinner() : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _sentState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(
          Icons.mark_email_read_outlined,
          size: 46,
          color: AppColors.success,
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'If an account exists for ${_email.text.trim()}, a reset link has '
          'been sent.',
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
    );
  }
}

// ===========================================================================
// Reset password
// ===========================================================================

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({this.token, super.key});

  /// Supplied via deep link: /reset-password?token=...
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
    FocusScope.of(context).unfocus();
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
                () => _password.text,
                'Passwords do not match',
              ),
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

// ===========================================================================
// Change password
// ===========================================================================

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
    FocusScope.of(context).unfocus();
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
      // No back button when the change is mandatory — the router redirect
      // would bounce straight back anyway.
      onBack: forced ? null : () => context.pop(),
      footer: forced
          ? TextButton(
              onPressed: _busy
                  ? null
                  : () => ref.read(sessionControllerProvider.notifier).logout(),
              child: const Text('Sign out instead'),
            )
          : null,
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
                () => _next.text,
                'Passwords do not match',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              MessageBanner(message: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child:
                  _busy ? const ButtonSpinner() : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}
