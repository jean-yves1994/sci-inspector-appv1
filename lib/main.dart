import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('SCI uncaught: ${details.exceptionAsString()}');
    }
  };

  final container = ProviderContainer();

  // Start bootstrap immediately; the splash screen watches its state.
  unawaited(container.read(bootstrapProvider.future).catchError((Object _) {}));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SciInspectorApp(),
    ),
  );
}
