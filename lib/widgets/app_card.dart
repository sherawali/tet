import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_shadows.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderSide? border;
  final bool hasGlow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.color,
    this.border,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? (isDark ? AppColors.darkCard : AppColors.lightCard);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppRadius.roundedBase,
        border: Border.fromBorderSide(
          border ?? BorderSide(color: borderColor, width: 1.0),
        ),
        boxShadow: hasGlow
            ? AppShadows.primaryGlow
            : (isDark ? AppShadows.darkCard : AppShadows.card),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.roundedBase,
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
