import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/photo.dart';

/// Picks an image and returns platform-neutral bytes.
///
/// readAsBytes() works identically on web and native, so no dart:io File ever
/// enters shared code. On Chrome, ImageSource.camera falls back to the
/// browser file picker, which is expected in web dev mode.
Future<EvidenceFile?> pickEvidence({required bool fromCamera}) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    // Compress on capture while keeping enough quality for collateral
    // evidence. Do not reduce quality excessively.
    imageQuality: 82,
    maxWidth: 1920,
    maxHeight: 1920,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  final name = picked.name.isEmpty ? 'evidence.jpg' : picked.name;

  return EvidenceFile(
    bytes: bytes,
    filename: name,
    mimeType: picked.mimeType ?? _guessMime(name),
    path: kIsWeb ? null : picked.path,
  );
}

String _guessMime(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
