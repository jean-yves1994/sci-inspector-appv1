import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'shell/mobile_frame.dart';

class SciInspectorApp extends ConsumerWidget {
  const SciInspectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SCI Inspector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        // Respect the user's text scale (accessibility), but guard against
        // extreme values breaking dense field forms.
        final scaler = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.6);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: MobileFrame(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
