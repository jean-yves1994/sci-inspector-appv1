import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'shell/mobile_frame.dart';

class SciInspectorApp extends ConsumerWidget {
  const SciInspectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SCI Inspector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Respect user text scaling, but guard dense field forms.
        final scaler = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.5);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          // MaterialApp.router can receive a tighter child constraint than the
          // host viewport (especially in browser/device-preview environments).
          // Expand the frame first so full-screen routes such as the splash
          // actually paint across the entire available surface.
          child: SizedBox.expand(
            child: MobileFrame(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
