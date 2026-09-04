import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    required this.source,
    required this.isMocked,
    this.accuracyM,
    this.altitudeM,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? altitudeM;
  final DateTime capturedAt;

  /// GPS | NETWORK | FUSED | MANUAL
  final String source;
  final bool isMocked;
}

class LocationDenied implements Exception {
  const LocationDenied(this.message, {this.permanent = false});
  final String message;
  final bool permanent;
}

class LocationService {
  const LocationService();

  Future<LocationFix> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationDenied(
          'Location services are turned off. Enable them and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationDenied(
        'Location permission is permanently denied. Enable it in settings.',
        permanent: true,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationDenied('Location permission was denied.');
    }

    // geolocator 12.x API: desiredAccuracy + timeLimit.
    // (`locationSettings:` only exists from geolocator 13 onwards.)
    final p = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
      timeLimit: const Duration(seconds: 25),
    );

    return LocationFix(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracyM: p.accuracy,
      altitudeM: p.altitude,
      capturedAt: p.timestamp,
      // The browser Geolocation API is network-assisted, not a raw GPS fix.
      source: kIsWeb ? 'NETWORK' : 'GPS',
      isMocked: kIsWeb ? false : p.isMocked,
    );
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());
