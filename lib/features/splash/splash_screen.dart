import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../auth/application/session_controller.dart';

/// Runs bootstrap exactly once at startup.
final bootstrapProvider = FutureProvider<void>((ref) async {
  final started = DateTime.now();
  await ref.read(sessionControllerProvider.notifier).restore();

  // Keep the brand animation visible long enough to avoid a flicker, but
  // never block longer than necessary.
  const minimum = Duration(milliseconds: 1100);
  final elapsed = DateTime.now().difference(started);
  if (elapsed < minimum) {
    await Future<void>.delayed(minimum - elapsed);
  }
});

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.86, end: 1)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);

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
          child: Column(
            children: <Widget>[
              const Spacer(),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    height: 104,
                    width: 104,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'SCI',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeTransition(
                opacity: _fade,
                child: const Column(
                  children: <Widget>[
                    Text(
                      'Smart Collateral Inspection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Inspector Field Application',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                child: bootstrap.when(
                  loading: () => const _Bar(label: 'Preparing…'),
                  data: (_) => const _Bar(label: 'Starting…'),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl),
                    child: Column(
                      children: <Widget>[
                        const Icon(Icons.wifi_off_rounded,
                            color: Colors.white70, size: 30),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Could not start the application',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(bootstrapProvider),
                          child: const Text('Retry'),
                        ),
                      ],
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

class _Bar extends StatelessWidget {
  const _Bar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
