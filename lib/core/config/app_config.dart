import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'SCI_API_URL',
    defaultValue: 'https://server.realcovenants.com/api/v1',
  );

  static const String environment = String.fromEnvironment(
    'SCI_ENV',
    defaultValue: 'production',
  );

  /// Development-only platform override.
  ///
  /// SCI ships to Android and iOS. Chrome is used as a stand-in for an
  /// emulator, so the browser build should exercise the SAME auth path the
  /// real app uses: refresh token in the JSON body, no cookies.
  ///
  /// `--dart-define=SCI_PLATFORM=android` makes the backend treat the dev
  /// browser session as a mobile client. Ignored in production builds.
  static const String _platformOverride =
      String.fromEnvironment('SCI_PLATFORM');

  static bool get isProduction => environment == 'production';

  /// True when the browser build is impersonating a mobile client.
  static bool get isDevBrowserSession =>
      kIsWeb && !isProduction && _platformOverride.isNotEmpty;

  /// True when running in a browser outside production.
  ///
  /// Drives the "development web session" notice on the login card: browser
  /// storage is not a hardware keystore, and the in-memory token store is
  /// cleared on page reload.
  static bool get isInsecureWebSession => kIsWeb && !isProduction;

  /// Value sent as `platform` on login. Backend accepts: android | ios | web.
  static String get platform {
    // Honoured only in non-production builds, so a real release can never
    // claim to be a mobile client when it isn't.
    if (!isProduction && _platformOverride.isNotEmpty) {
      return _platformOverride;
    }

    // kIsWeb MUST be checked before Platform, or the web build throws.
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }
}
