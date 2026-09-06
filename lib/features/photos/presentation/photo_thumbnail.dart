import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/photo.dart';

/// Thumbnail for an uploaded photograph.
///
/// Shows an explicit failure state rather than a bare refresh glyph: when the
/// signed URL is wrong, a silent grey square gives the inspector no way to
/// tell a broken link from a slow network. Tapping a failed tile reveals the
/// URL in debug builds, which is what identified the `/files` 404.
class PhotoThumbnail extends StatefulWidget {
  const PhotoThumbnail({
    required this.photo,
    required this.enabled,
    required this.onDelete,
    this.size = 92,
    super.key,
  });

  final InspectionPhoto photo;
  final bool enabled;
  final VoidCallback onDelete;
  final double size;

  @override
  State<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final url = widget.photo.url;

    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: widget.size,
            width: widget.size,
            child: url == null || _failed
                ? _Unavailable(
                    photo: widget.photo,
                    onTap: () => _showDetail(context),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const ColoredBox(
                        color: Color(0xFFE9ECF4),
                        child: Center(
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      // Rebuild into the explicit failure state.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_failed) {
                          setState(() => _failed = true);
                        }
                      });
                      return const ColoredBox(color: Color(0xFFE9ECF4));
                    },
                  ),
          ),
        ),

        if (widget.photo.hasGps)
          const Positioned(
            left: 4,
            bottom: 4,
            child: Icon(Icons.gps_fixed_rounded,
                size: 14, color: Colors.white),
          ),

        if (widget.enabled)
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              onTap: widget.onDelete,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  borderRadius:
                      BorderRadius.only(bottomLeft: Radius.circular(8)),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 13, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Image could not be loaded'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'The photograph is stored, but its link did not load. This is '
              'usually a server configuration problem, not a lost file.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Category: ${widget.photo.category.label}',
              style: const TextStyle(fontSize: 12),
            ),
            if (widget.photo.sizeLabel.isNotEmpty)
              Text(
                'Size: ${widget.photo.sizeLabel}',
                style: const TextStyle(fontSize: 12),
              ),
            if (kDebugMode) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'URL (debug only):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              SelectableText(
                widget.photo.url ?? '(none returned by the server)',
                style: const TextStyle(fontSize: 10, height: 1.3),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.photo, required this.onTap});

  final InspectionPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: const Color(0xFFE9ECF4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.broken_image_outlined,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(
              'Stored\nno preview',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8.5,
                height: 1.15,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
