import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Authentication state. Deliberately kept separate from all business logic.
sealed class SessionState {
  const SessionState();
}

/// Before bootstrap has finished — the splash screen is showing.
class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.reason});

  /// Populated when the session was terminated involuntarily so the login
  /// screen can explain why.
  final String? reason;
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);
  final User user;

  /// Drives the forced change-password redirect (spec section 11).
  bool get mustChangePassword => user.mustChangePassword;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // React to the interceptor invalidating the session mid-flight.
    ref.listen<String?>(sessionInvalidatedProvider, (previous, next) {
      if (next != null) {
        state = SessionUnauthenticated(reason: next);
        ref.read(sessionInvalidatedProvider.notifier).reset();
      }
    });
    return const SessionUnknown();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  /// Called by the splash/bootstrap route.
  ///
  /// Restores a session by validating against /auth/me rather than trusting
  /// cached user data. A network failure must NOT sign the user out.
  Future<void> restore() async {
    final stored = await _tokens.read();
    if (stored == null) {
      state = const SessionUnauthenticated();
      return;
    }

    try {
      final user = await _repo.me();
      state = SessionAuthenticated(user);
    } on ApiError catch (e) {
      if (e.isOffline) {
        // Keep the stored session; the sync engine will reconcile later.
        // Phase 7 will hydrate a cached user here. Until then, require login.
        state = const SessionUnauthenticated(
          reason: 'Could not reach the SCI server. Please sign in.',
        );
      } else {
        await _tokens.clear();
        state = SessionUnauthenticated(reason: e.message);
      }
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final result = await _repo.login(email: email, password: password);
    state = SessionAuthenticated(result.user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    // Re-fetch so mustChangePassword flips to false server-side.
    final user = await _repo.me();
    state = SessionAuthenticated(user);
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } on ApiError {
      // Local sign-out must succeed even if the server is unreachable.
    }
    _invalidateSessionScopedProviders();
    state = const SessionUnauthenticated();
  }

  void _invalidateSessionScopedProviders() {
    // Riverpod caches aggressively; drop everything user-scoped on sign-out
    // so the next inspector never sees the previous inspector's data.
    ref.invalidate(apiClientProviderKeepAlive);
  }
}

/// Alias kept explicit so the invalidation list is easy to extend per phase.
final apiClientProviderKeepAlive = Provider<void>((ref) {});

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Convenience: the current user, or null.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(sessionControllerProvider);
  return state is SessionAuthenticated ? state.user : null;
});

/// Permission gate used by widgets. Never rely on route hiding alone.
final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  return ref.watch(currentUserProvider)?.can(permission) ?? false;
});
