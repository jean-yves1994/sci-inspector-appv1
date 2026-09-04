import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../network/api_error.dart';
import '../theme/app_theme.dart';

/// Pill severity badge — cybersecurity UI reference. Never shows raw enums.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2x2 dashboard stat card.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alert-style tile — reused for requirements, notifications, history.
class AlertTile extends StatelessWidget {
  const AlertTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        leading: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: trailing ??
            (onTap == null
                ? null
                : const Icon(Icons.chevron_right_rounded, size: 20)),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Distinguishes offline from server failure so the inspector knows whether
/// to move location or simply wait.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiError ? error as ApiError : null;
    final offline = api?.isOffline ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 44,
              color: offline ? AppColors.offline : AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              offline ? 'No connection' : 'Something went wrong',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              api?.message ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.itemCount = 6, this.height = 96, super.key});

  final int itemCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.06);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

/// Circular arc gauge from the cybersecurity reference, reused as the
/// inspection completeness gauge.
class ProgressGauge extends StatelessWidget {
  const ProgressGauge({
    required this.percentage,
    this.size = 150,
    this.label,
    this.caption,
    super.key,
  });

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
                    fontSize: size * 0.21,
                    fontWeight: FontWeight.w800,
                    color: _color,
                    height: 1,
                  ),
                ),
                if (label != null)
                  Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (caption != null)
                  Text(
                    caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
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

  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect =
        Rect.fromLTWH(0, 0, size.width, size.height).deflate(stroke / 2 + 2);

    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.14),
    );

    canvas.drawArc(
      rect,
      _start,
      _sweep * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: _start,
          endAngle: _start + _sweep,
          colors: <Color>[color.withValues(alpha: 0.55), color],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}

/// Soft-filled labelled text field used across auth and forms.
class SciTextField extends StatelessWidget {
  const SciTextField({
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleObscure,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.autofillHints,
    this.helper,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,
          autofillHints: autofillHints,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 20, color: AppColors.textSecondary),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    tooltip: obscureText ? 'Show password' : 'Hide password',
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Inline banner for form-level errors and warnings.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    required this.message,
    this.color = AppColors.danger,
    this.icon = Icons.error_outline_rounded,
    this.action,
    super.key,
  });

  final String message;
  final Color color;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 12.5, color: color, height: 1.35),
                ),
              ),
            ],
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
}
