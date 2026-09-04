/// Centralised spacing / radius tokens. Never inline raw numbers in widgets.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Minimum accessible touch target (spec section 92).
  static const double touchTarget = 48;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Slide-up auth card top radius.
  static const double authCard = 32;
}
