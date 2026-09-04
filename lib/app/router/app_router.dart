import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/inspections/presentation/inspection_screens.dart';
import '../../features/inspections/presentation/workspace/inspection_workspace_screen.dart';
import '../../features/notifications/notifications.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/properties/presentation/property_screens.dart';
import '../../features/splash/splash_screen.dart';
import '../shell/app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<SessionState>(
        sessionControllerProvider, (_, __) => notifyListeners());
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
      final loc = state.matchedLocation;

      if (session is SessionUnknown) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      final isAuthRoute = Routes.unauthenticated.contains(loc);

      if (session is SessionUnauthenticated) {
        return isAuthRoute ? null : Routes.login;
      }

      if (session is SessionAuthenticated) {
        // Force the password change before any normal app usage.
        if (session.mustChangePassword && loc != Routes.changePassword) {
          return Routes.changePassword;
        }
        if (isAuthRoute || loc == Routes.splash) return Routes.home;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (c, s) =>
            ResetPasswordScreen(token: s.uri.queryParameters['token']),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, __) => const ChangePasswordScreen(),
      ),

      // Full-screen routes outside the shell so they cover the bottom nav.
      GoRoute(
        path: Routes.propertyNew,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const CreatePropertyScreen(),
      ),
      GoRoute(
        path: Routes.propertyDetailPattern,
        parentNavigatorKey: _rootKey,
        builder: (c, s) =>
            PropertyDetailScreen(propertyId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.inspectionNewPattern,
        parentNavigatorKey: _rootKey,
        builder: (c, s) => CreateInspectionScreen(
            propertyId: s.pathParameters['propertyId']!),
      ),
      GoRoute(
        path: Routes.inspectionWorkspacePattern,
        parentNavigatorKey: _rootKey,
        builder: (c, s) => InspectionWorkspaceScreen(
          inspectionId: s.pathParameters['id']!,
          initialSection: s.uri.queryParameters['section'],
        ),
      ),
      GoRoute(
        path: Routes.inspectionDetailPattern,
        parentNavigatorKey: _rootKey,
        builder: (c, s) =>
            InspectionDetailScreen(inspectionId: s.pathParameters['id']!),
      ),

      ShellRoute(
        navigatorKey: _shellKey,
        builder: (c, s, child) =>
            AppShell(location: s.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
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
