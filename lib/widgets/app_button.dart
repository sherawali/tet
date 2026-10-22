import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_shadows.dart';
import '../design_system/app_motion.dart';

enum AppButtonVariant { primary, secondary, outline, danger, success }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;
  final double? width;

  /// The minimum height of the button.  A long label wraps to as many lines
  /// as it needs and the button grows with it, so a label is never cut.
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.height = 48.0,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BoxBorder? border;
    List<BoxShadow> shadows = [];

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = AppColors.primary;
        fg = AppColors.darkTextPrimary;
        shadows = AppShadows.primaryGlow;
        break;
      case AppButtonVariant.secondary:
        bg = isDark ? AppColors.darkCardElevated : AppColors.primarySubtle;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.primary;
        break;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        border = Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        );
        break;
      case AppButtonVariant.danger:
        bg = AppColors.danger;
        fg = AppColors.darkTextPrimary;
        break;
      case AppButtonVariant.success:
        bg = AppColors.success;
        fg = AppColors.darkTextPrimary;
        break;
    }

    final isInteractive = widget.onPressed != null && !widget.isLoading;

    return AnimatedScale(
      scale: _isPressed && isInteractive ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      child: Container(
        width: widget.width,
        constraints: BoxConstraints(minHeight: widget.height),
        decoration: BoxDecoration(
          color: isInteractive
              ? bg
              : (isDark ? AppColors.darkCardElevated : AppColors.borderStrong),
          borderRadius: AppRadius.roundedBase,
          border: border,
          boxShadow: isInteractive ? shadows : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.roundedBase,
            onTap: isInteractive ? widget.onPressed : null,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm,
              ),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.darkTextPrimary,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 18, color: fg),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: AppTypography.titleSmall(color: fg),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
