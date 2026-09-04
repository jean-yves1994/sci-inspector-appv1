import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'SCI_API_URL',
    defaultValue: 'https://sci-server.vercel.app/api/v1',
  );

  static const String environment =
      String.fromEnvironment('SCI_ENV', defaultValue: 'development');

  static bool get isProduction => environment == 'production';
  static bool get isInsecureWebSession => kIsWeb && !isProduction;

  /// Backend accepts exactly: android | ios | web.
  /// kIsWeb MUST be checked before Platform, or the web build throws.
  static String get platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }
}
