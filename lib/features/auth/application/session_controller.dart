import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

sealed class SessionState {
  const SessionState();
}

/// Bootstrap has not finished — the splash screen is showing.
class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.reason});
  final String? reason;
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);
  final User user;
  bool get mustChangePassword => user.mustChangePassword;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // React to the interceptor killing the session mid-flight.
    ref.listen<String?>(sessionInvalidatedProvider, (_, next) {
      if (next != null) {
        state = SessionUnauthenticated(reason: next);
        ref.read(sessionInvalidatedProvider.notifier).reset();
      }
    });
    return const SessionUnknown();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  Future<void> restore() async {
    final stored = await _tokens.read();
    if (stored == null) {
      state = const SessionUnauthenticated();
      return;
    }
    try {
      state = SessionAuthenticated(await _repo.me());
    } on ApiError catch (e) {
      if (e.isOffline) {
        state = const SessionUnauthenticated(
            reason: 'Could not reach the SCI server. Please sign in.');
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
    final r = await _repo.login(email: email, password: password);
    state = SessionAuthenticated(r.user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _repo.changePassword(
        currentPassword: currentPassword, newPassword: newPassword);
    state = SessionAuthenticated(await _repo.me());
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } on ApiError {
      // Signing out locally must always succeed.
    }
    state = const SessionUnauthenticated();
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final currentUserProvider = Provider<User?>((ref) {
  final s = ref.watch(sessionControllerProvider);
  return s is SessionAuthenticated ? s.user : null;
});

/// Permission gate. Never rely on route hiding alone.
final hasPermissionProvider = Provider.family<bool, String>(
    (ref, p) => ref.watch(currentUserProvider)?.can(p) ?? false);
