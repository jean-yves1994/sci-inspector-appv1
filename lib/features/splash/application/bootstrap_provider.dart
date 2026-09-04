import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';

/// Runs application bootstrap exactly once at startup.
///
/// Phase 1 restores the session. Later phases will also open the Drift
/// database, start the connectivity watcher and the sync engine here.
final bootstrapProvider = FutureProvider<void>((ref) async {
  final started = DateTime.now();

  await ref.read(sessionControllerProvider.notifier).restore();

  // Keep the brand animation on screen long enough to not flicker, but never
  // block longer than necessary.
  const minimumSplash = Duration(milliseconds: 1200);
  final elapsed = DateTime.now().difference(started);
  if (elapsed < minimumSplash) {
    await Future<void>.delayed(minimumSplash - elapsed);
  }
});
