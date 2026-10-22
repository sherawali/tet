import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_typography.dart';

/// A small pill shaped tag.
///
/// The pill is the one place where a long text is allowed to be cut, because
/// the badge has to stay a badge.  Set [wrap] to true when the label is a
/// topic name that must be readable in full.
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isSolid;

  /// When true the label wraps to as many lines as it needs.
  final bool wrap;

  /// The widest a wrapping badge is allowed to become.
  static const double _wrapMaxWidth = 240;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isSolid = false,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = (isDark && (color == AppColors.primary || color == AppColors.primaryLight || color == AppColors.primaryDark))
        ? AppColors.accentBright
        : color;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: wrap ? _wrapMaxWidth : double.infinity,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSolid ? effectiveColor : effectiveColor.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: AppRadius.roundedFull,
          border: isSolid ? null : Border.all(color: effectiveColor.withValues(alpha: isDark ? 0.45 : 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSolid ? AppColors.darkTextPrimary : effectiveColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (wrap)
              // A wrapping badge never cuts its label: the text flows into
              // as many lines as it needs.
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.start,
                  style: AppTypography.labelSmall(
                    color: isSolid ? AppColors.darkTextPrimary : effectiveColor,
                  ),
                ),
              )
            else
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall(
                  color: isSolid ? AppColors.darkTextPrimary : effectiveColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
