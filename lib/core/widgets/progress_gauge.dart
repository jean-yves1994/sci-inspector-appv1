import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular arc gauge borrowed from the cybersecurity UI reference and reused
/// as the inspection completeness gauge (spec sections 49 and 65).
class ProgressGauge extends StatelessWidget {
  const ProgressGauge({
    required this.percentage,
    this.size = 160,
    this.label,
    this.caption,
    super.key,
  });

  /// 0-100, as returned by the backend completeness endpoint.
  final int percentage;
  final double size;
  final String? label;
  final String? caption;

  Color get _color {
    if (percentage >= 100) return AppColors.success;
    if (percentage >= 70) return AppColors.primary;
    if (percentage >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = percentage.clamp(0, 100);

    return SizedBox(
      height: size,
      width: size,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: clamped / 100),
        builder: (context, value, _) => CustomPaint(
          painter: _GaugePainter(progress: value, color: _color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w800,
                    color: _color,
                    height: 1,
                  ),
                ),
                if (label != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (caption != null)
                  Text(
                    caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  // Sweep an arc with a gap at the bottom, like the reference design.
  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(stroke / 2 + 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.14);

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepAngle,
        colors: <Color>[color.withValues(alpha: 0.55), color],
      ).createShader(rect);

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, track);
    canvas.drawArc(rect, _startAngle, _sweepAngle * progress, false, fill);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
