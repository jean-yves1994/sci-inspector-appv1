import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Compile-time configuration.
///
/// Nothing here may be hard-coded to a production URL. Supply values with:
///   flutter run -d chrome --dart-define-from-file=dart_define.development.json
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'SCI_API_URL',
    defaultValue: 'https://sci-server.vercel.app/api/v1',
  );

  static const String environment = String.fromEnvironment(
    'SCI_ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';

  /// True when running the browser build outside production. Used to show the
  /// "development web session" notice, because flutter_secure_storage on web is
  /// NOT equivalent to a native keystore (see spec section 7).
  static bool get isInsecureWebSession => kIsWeb && !isProduction;

  /// Backend accepts exactly: android | ios | web.
  ///
  /// `kIsWeb` MUST be evaluated before touching `Platform`, otherwise the web
  /// build throws at runtime.
  static String get platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }
}
