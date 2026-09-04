import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/splash/application/bootstrap_provider.dart';

void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Redacting global error reporters. Never log tokens or credentials.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (kDebugMode) debugPrint('SCI uncaught: ${details.exceptionAsString()}');
      };

      final container = ProviderContainer();

      // Kick off bootstrap immediately; the splash screen watches its state.
      unawaited(
        container.read(bootstrapProvider.future).catchError((Object _) {}),
      );

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const SciInspectorApp(),
        ),
      );
    },
    (error, stack) {
      if (kDebugMode) debugPrint('SCI zone error: $error');
    },
  );
}
