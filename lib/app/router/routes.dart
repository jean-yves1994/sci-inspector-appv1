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

  // '/properties/new' MUST be declared before '/properties/:id', otherwise
  // go_router parses "new" as a property id.
  static const String propertyNew = '/properties/new';
  static const String propertyDetailPattern = '/properties/:id';
  static String propertyDetail(String id) => '/properties/$id';

  static const String inspectionNewPattern = '/inspections/new/:propertyId';
  static const String inspectionDetailPattern = '/inspections/:id';
  static const String inspectionWorkspacePattern = '/inspections/:id/workspace';
  static const String inspectionPaymentPattern = '/inspections/:id/payment';

  static String inspectionNewFor(String propertyId) =>
      '/inspections/new/$propertyId';
  static String inspectionDetail(String id) => '/inspections/$id';
  static String inspectionWorkspace(String id, {String? section}) =>
      '/inspections/$id/workspace${section == null ? '' : '?section=$section'}';
  static String inspectionPayment(String id, {String? number}) =>
      '/inspections/$id/payment${number == null ? '' : '?number=$number'}';

  static const Set<String> unauthenticated = <String>{
    login,
    forgotPassword,
    resetPassword,
  };
}
