import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sci_widgets.dart';

/// Shared layout for the authentication screens.
///
/// The previous version put the form in a `SingleChildScrollView` inside an
/// `Expanded`, which sizes to its content — so on a tall screen everything
/// bunched at the top and left a large void beneath.
///
/// This uses a `LayoutBuilder` + `ConstrainedBox(minHeight)` + `IntrinsicHeight`
/// so the card always fills the available height. The form can then use
/// `Spacer`s to distribute content vertically, while still scrolling when the
/// keyboard appears on a short screen.
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

  /// Main form content. Sits in the upper portion of the card.
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

  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
          .animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));

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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              // ---- Hero -------------------------------------------------
              // Collapses when the keyboard is open so the form keeps room.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: isKeyboardOpen
                    ? const SizedBox(height: AppSpacing.sm)
                    : FadeTransition(
                        opacity: _fade,
                        child: _Hero(
                          title: widget.title,
                          subtitle: widget.subtitle,
                          onBack: widget.onBack,
                        ),
                      ),
              ),

              // ---- Card -------------------------------------------------
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: EdgeInsets.only(bottom: keyboardInset),
                            child: ConstrainedBox(
                              // Forcing the child to at least the card's
                              // height is what lets Spacer() work inside it.
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    AppSpacing.xl,
                                    AppSpacing.xxl,
                                    AppSpacing.xl,
                                    AppSpacing.lg +
                                        MediaQuery.paddingOf(context).bottom,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      widget.child,

                                      // Pushes the footer to the bottom
                                      // instead of leaving dead space.
                                      const Spacer(),

                                      if (AppConfig.isInsecureWebSession) ...[
                                        const SizedBox(height: AppSpacing.md),
                                      ],

                                      if (widget.footer != null) ...[
                                        const SizedBox(height: AppSpacing.lg),
                                        widget.footer!,
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xl,
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

          // Brand mark. The login screen was the only place in the app with
          // no SCI identity at all.
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

          const SizedBox(height: AppSpacing.lg),
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
