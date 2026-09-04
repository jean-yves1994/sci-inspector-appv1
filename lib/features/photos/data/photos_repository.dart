import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../domain/photo.dart';

class PhotosRepository {
  const PhotosRepository(this._api);
  final ApiClient _api;

  Future<List<InspectionPhoto>> list(String inspectionId) async {
    final d =
        await _api.get<dynamic>('/inspections/$inspectionId/photos');
    final raw = d is Map<String, dynamic> ? (d['items'] ?? d['data']) : d;
    return raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(InspectionPhoto.fromJson)
            .toList()
        : <InspectionPhoto>[];
  }

  /// Uploads one photograph.
  ///
  /// [clientRequestId] MUST be reused when retrying after a timeout: the
  /// backend uses it for idempotency, so a retry cannot create a duplicate.
  Future<InspectionPhoto> upload({
    required String inspectionId,
    required EvidenceFile file,
    required PhotoCategory category,
    required String clientRequestId,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? caption,
    void Function(int, int)? onProgress,
  }) async {
    final subtype = file.mimeType.split('/').last;

    final form = FormData.fromMap(<String, dynamic>{
      // fromBytes works on both web and native; fromFile does not exist on web.
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.filename,
        contentType: MediaType('image', subtype),
      ),
      'category': category.wire,
      'clientRequestId': clientRequestId,
      'capturedAt': (capturedAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracyM': accuracyM,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
    });

    final d = await _api.uploadMultipart<Map<String, dynamic>>(
      '/inspections/$inspectionId/photos',
      form: form,
      onProgress: onProgress,
    );
    return InspectionPhoto.fromJson(
        d['data'] is Map<String, dynamic> ? d['data'] as Map<String, dynamic> : d);
  }

  Future<void> delete(String photoId) => _api.delete<dynamic>('/photos/$photoId');
}

final photosRepositoryProvider = Provider<PhotosRepository>(
    (ref) => PhotosRepository(ref.watch(apiClientProvider)));
