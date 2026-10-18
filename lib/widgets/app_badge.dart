import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_typography.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isSolid;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isSolid = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = (isDark && (color == AppColors.primary || color == AppColors.primaryLight || color == AppColors.primaryDark))
        ? const Color(0xFF38BDF8)
        : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isSolid ? effectiveColor : effectiveColor.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: AppRadius.roundedFull,
        border: isSolid ? null : Border.all(color: effectiveColor.withValues(alpha: isDark ? 0.45 : 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: isSolid ? Colors.white : effectiveColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelSmall(
              color: isSolid ? Colors.white : effectiveColor,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
