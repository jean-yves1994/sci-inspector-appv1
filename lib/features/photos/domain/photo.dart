import 'dart:typed_data';

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
    this.caption,
    this.sizeBytes,
    this.latitude,
    this.longitude,
    this.capturedAt,
  });

  final String id;
  final PhotoCategory category;

  /// SHORT-LIVED signed URL. Never persisted as a permanent storage URL.
  final String? url;
  final String? caption;
  final int? sizeBytes;
  final double? latitude;
  final double? longitude;
  final DateTime? capturedAt;

  bool get hasGps => latitude != null && longitude != null;

  factory InspectionPhoto.fromJson(Map<String, dynamic> j) => InspectionPhoto(
        id: j['id'] as String,
        category: PhotoCategory.parse(j['category'] as String?),
        url: j['url'] as String? ?? j['signedUrl'] as String?,
        caption: j['caption'] as String?,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        capturedAt: j['capturedAt'] is String
            ? DateTime.tryParse(j['capturedAt'] as String)
            : null,
      );
}

/// Platform-neutral file wrapper.
///
/// dart:io File must never appear in shared code, because the web build has
/// no filesystem. Bytes are always available; path only on native.
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

  /// Backend default limit is 15 MB.
  static const int maxBytes = 15 * 1024 * 1024;
  bool get exceedsLimit => sizeBytes > maxBytes;
}
