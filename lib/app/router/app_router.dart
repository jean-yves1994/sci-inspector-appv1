import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/inspections/presentation/inspection_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/properties/presentation/property_list_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../shell/app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Bridges Riverpod state changes into go_router's refresh mechanism.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<SessionState>(
      sessionControllerProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;

      // Bootstrap has not finished — stay on the splash screen.
      if (session is SessionUnknown) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final isUnauthRoute = Routes.unauthenticated.contains(location);

      if (session is SessionUnauthenticated) {
        return isUnauthRoute ? null : Routes.login;
      }

      if (session is SessionAuthenticated) {
        // Force the change-password flow before any normal app usage.
        if (session.mustChangePassword &&
            location != Routes.changePassword) {
          return Routes.changePassword;
        }
        if (isUnauthRoute || location == Routes.splash) {
          return Routes.home;
        }
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, __) => const ChangePasswordScreen(),
      ),

      // Authenticated shell: each tab keeps its own navigation stack.
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.inspections,
            builder: (_, __) => const InspectionListScreen(),
          ),
          GoRoute(
            path: Routes.properties,
            builder: (_, __) => const PropertyListScreen(),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
