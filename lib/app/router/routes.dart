/// Central route path constants. No raw strings in widgets.
class Routes {
  const Routes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String changePassword = '/change-password';

  static const String home = '/home';
  static const String inspections = '/inspections';
  static const String properties = '/properties';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  /// Routes reachable without an authenticated session.
  static const Set<String> unauthenticated = <String>{
    login,
    forgotPassword,
    resetPassword,
  };
}
