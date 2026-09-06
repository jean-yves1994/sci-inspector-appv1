import 'dart:typed_data';

import '../../../core/config/app_config.dart';
import '../../../core/utils/json_read.dart';

/// Backend photo categories.
enum PhotoCategory {
  frontView('FRONT_VIEW', 'Front view'),
  rearView('REAR_VIEW', 'Rear view'),
  leftSide('LEFT_SIDE', 'Left side'),
  rightSide('RIGHT_SIDE', 'Right side'),
  interior('INTERIOR', 'Interior'),
  roof('ROOF', 'Roof'),
  foundation('FOUNDATION', 'Foundation'),
  roadAccess('ROAD_ACCESS', 'Road access'),
  utilities('UTILITIES', 'Utilities'),
  surroundings('SURROUNDINGS', 'Surroundings'),
  document('DOCUMENT', 'Document'),
  other('OTHER', 'Other');

  const PhotoCategory(this.wire, this.label);

  final String wire;
  final String label;

  static PhotoCategory parse(String? v) {
    if (v == null) return PhotoCategory.other;
    for (final c in PhotoCategory.values) {
      if (c.wire == v.toUpperCase()) return c;
    }
    return PhotoCategory.other;
  }
}

class InspectionPhoto {
  const InspectionPhoto({
    required this.id,
    required this.category,
    this.url,
    this.storageKey,
    this.caption,
    this.mimeType,
    this.sizeBytes,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.capturedAt,
    this.capturedByName,
    this.checksumSha256,
  });

  final String id;
  final PhotoCategory category;

  /// Absolute URL, normalised from whatever the server returned.
  final String? url;

  final String? storageKey;
  final String? caption;
  final String? mimeType;
  final int? sizeBytes;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final DateTime? capturedAt;
  final String? capturedByName;
  final String? checksumSha256;

  bool get hasGps => latitude != null && longitude != null;

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Origin of the API, derived from the configured base URL.
  ///
  /// `AppConfig.apiBaseUrl` is e.g. https://sci-server.vercel.app/api/v1 —
  /// a path-only file URL must be joined to the ORIGIN, not to that full path
  /// and not to the page origin.
  static String get _apiOrigin {
    final parsed = Uri.tryParse(AppConfig.apiBaseUrl);
    if (parsed == null || !parsed.hasScheme) return '';
    return '${parsed.scheme}://${parsed.authority}';
  }

  /// Normalises a server-supplied URL to something [Image.network] can load.
  ///
  /// Observed forms, both from this backend at different times:
  ///
  ///   "server.realcovenants.com/files?key=..."   host, no scheme
  ///   "/files?key=..."                           path only
  ///
  /// The second is the dangerous one on web: a leading-slash URL resolves
  /// against the PAGE origin (http://localhost:5555), not the API, producing
  /// a request the Flutter dev server answers with a 404. Joining it to the
  /// API origin is what fixes that.
  static String? normaliseUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    // Already absolute.
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    // Protocol-relative: adopt https.
    if (value.startsWith('//')) return 'https:$value';

    // Path-only: join to the API origin, NOT the page origin.
    if (value.startsWith('/')) {
      final origin = _apiOrigin;
      return origin.isEmpty ? value : '$origin$value';
    }

    // "host/path?query" with no scheme.
    return 'https://$value';
  }

  /// Numeric reads go through the tolerant helpers: `latitude` and
  /// `longitude` are Prisma Decimals and arrive as JSON strings ("51.5077"),
  /// while `accuracyM` and `sizeBytes` arrive as numbers. Casting either with
  /// `as num?` threw and killed the whole list parse.
  factory InspectionPhoto.fromJson(Map<String, dynamic> j) {
    final capturedBy = J.asMap(j['capturedBy']);

    return InspectionPhoto(
      id: J.asString(j['id']) ?? '',
      category: PhotoCategory.parse(J.asString(j['category'])),
      url: normaliseUrl(
        J.asString(j['url']) ??
            J.asString(j['signedUrl']) ??
            J.asString(j['downloadUrl']) ??
            J.asString(j['publicUrl']),
      ),
      storageKey: J.asString(j['storageKey']) ?? J.asString(j['key']),
      caption: J.asString(j['caption']),
      mimeType: J.asString(j['mimeType']) ?? J.asString(j['contentType']),
      sizeBytes: J.asInt(j['sizeBytes']),
      latitude: J.asDouble(j['latitude']),
      longitude: J.asDouble(j['longitude']),
      accuracyM: J.asDouble(j['accuracyM']),
      capturedAt: J.asDate(j['capturedAt']),
      capturedByName: capturedBy != null
          ? '${J.asString(capturedBy['firstName']) ?? ''} '
                  '${J.asString(capturedBy['lastName']) ?? ''}'
              .trim()
          : null,
      checksumSha256: J.asString(j['checksumSha256']),
    );
  }
}

/// Platform-neutral file wrapper. `dart:io File` must never appear in shared
/// code — the web build has no filesystem.
class EvidenceFile {
  const EvidenceFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    this.path,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final String? path;

  int get sizeBytes => bytes.lengthInBytes;

  /// Vercel caps a serverless request body at 4.5 MB, applied before the
  /// handler runs — tighter than the backend's own 15 MB rule.
  static const int maxBytes = 4 * 1024 * 1024;

  bool get exceedsLimit => sizeBytes > maxBytes;
}
