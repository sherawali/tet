import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_motion.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_typography.dart';
import 'app_button.dart';
import 'app_card.dart';

/// The designed loading state of the app.
///
/// A bare spinner tells the candidate nothing.  This skeleton shows the
/// shape of the list that is coming, so the screen already looks finished
/// while the data is on its way.
class AppLoadingState extends StatefulWidget {
  /// How many placeholder cards are drawn.
  final int itemCount;

  const AppLoadingState({super.key, this.itemCount = 2});

  @override
  State<AppLoadingState> createState() => _AppLoadingStateState();
}

class _AppLoadingStateState extends State<AppLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkCardElevated : AppColors.borderStrong;
    final highlight = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.base,
          ),
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(widget.itemCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _shimmer(
                t,
                base,
                highlight,
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _block(base, 48, 48),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _block(base, double.infinity, 16),
                                const SizedBox(height: AppSpacing.sm),
                                _block(base, 120, 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _block(base, double.infinity, 44),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _block(Color base, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: AppRadius.roundedSm,
      ),
    );
  }

  /// The travelling highlight that makes the skeleton feel alive.
  Widget _shimmer(double t, Color base, Color highlight, Widget child) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-2 + 4 * t, 0),
        end: Alignment(0 + 4 * t, 0),
        colors: [base, highlight, base],
        stops: const [0.25, 0.5, 0.75],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// The designed empty state of the app.
///
/// One quiet card with an icon, a headline and - when there is something to
/// do - a single call to action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.accent = AppColors.sealGold,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: accent),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.titleSmall(color: textColor),
              ),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: actionLabel!,
                  variant: AppButtonVariant.primary,
                  width: double.infinity,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
