import 'dart:async';
import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_shadows.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_strings.dart';
import '../services/premium_service.dart';
import '../design_system/app_sheet.dart';

class PremiumPaywallModal extends StatefulWidget {
  const PremiumPaywallModal({super.key});

  static Future<void> show(BuildContext context) {
    return AppSheet.show(
      context,
      builder: (_) => const PremiumPaywallModal(),
    );
  }

  @override
  State<PremiumPaywallModal> createState() => _PremiumPaywallModalState();
}

class _PremiumPaywallModalState extends State<PremiumPaywallModal> {
  final PremiumService _premiumService = PremiumService.instance;
  String _selectedTier = PremiumService.masterProductId;
  StreamSubscription<bool>? _successSubscription;

  @override
  void initState() {
    super.initState();
    _successSubscription = _premiumService.onPurchaseSuccess.listen((_) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss paywall modal
        _showCongratulationsDialog(context);
      }
    });
  }

  @override
  void dispose() {
    _successSubscription?.cancel();
    super.dispose();
  }

  /// The one border of this file.
  Border _cardBorder({Color? color, double width = 1.2}) => Border.all(
        color: color ?? AppColors.borderStrong,
        width: width,
      );

  static void _showCongratulationsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.primary : AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.roundedXl,
          side: const BorderSide(color: AppColors.sealGold, width: 2),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.sealGold.withValues(alpha: 0.3),
                    AppColors.sealGoldLight.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.sealGold, width: 2),
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: AppColors.sealGold,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.congratulationsTitle,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.congratulationsSub,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryLight : AppColors.successSubtle,
                borderRadius: AppRadius.roundedMd,
                border: Border.all(color: AppColors.correctGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.correctGreen, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.premiumFeature4,
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sealGold,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedBase),
                textStyle: AppTypography.titleSmall(color: AppColors.primary),
              ),
              child: Text(
                AppStrings.startPreparingBtn,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(
          color: AppColors.sealGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: AppShadows.darkCard,
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.lg,
      ),
      child: ConstrainedBox(
        // The sheet never grows past the screen, the rest scrolls.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: ValueListenableBuilder<bool>(
        valueListenable: _premiumService.isPremiumUnlocked,
        builder: (context, isUnlocked, _) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.borderStrong,
                      borderRadius: AppRadius.roundedFull,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Crown Badge & Title
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.sealGold.withValues(alpha: 0.25),
                          AppColors.sealGoldLight.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: AppColors.sealGold, width: 2),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.sealGold,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                Text(
                  AppStrings.premiumPassTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.premiumPassSubtitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Tier Selection Cards
                if (!isUnlocked) ...[
                  // Tier 1: Master All-Access Pass (Best Value - ₹599)
                  _buildTierCard(
                    tierId: PremiumService.masterProductId,
                    title: AppStrings.proPackMasterTitle,
                    subtitle: AppStrings.proPackMasterSub,
                    price: AppStrings.proPackMasterPrice,
                    badgeText: AppStrings.proPackMasterTag,
                    isPopular: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Tier 2: Single Paper Pass (₹299)
                  _buildTierCard(
                    tierId: PremiumService.singlePaperProductId,
                    title: AppStrings.proPackSingleTitle,
                    subtitle: AppStrings.proPackSingleSub,
                    price: AppStrings.proPackSinglePrice,
                    badgeText: AppStrings.proPackSingleTag,
                    isPopular: false,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Features Box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryLight : AppColors.darkTextPrimary,
                    borderRadius: AppRadius.roundedBase,
                    border: _cardBorder(
                      color: isDark ? AppColors.darkBorder : AppColors.borderStrong,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        Icons.library_books_rounded,
                        AppColors.sealGold,
                        AppStrings.premiumFeature1,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildFeatureRow(
                        Icons.history_edu_rounded,
                        AppColors.sealGold,
                        AppStrings.premiumFeature2,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildFeatureRow(
                        Icons.insights_rounded,
                        AppColors.sealGold,
                        AppStrings.premiumFeature3,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildFeatureRow(
                        Icons.offline_pin_rounded,
                        AppColors.correctGreen,
                        AppStrings.premiumFeature4,
                        isBold: true,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Action / Unlock Button
                ValueListenableBuilder<bool>(
                  valueListenable: _premiumService.isLoading,
                  builder: (context, isLoading, _) {
                    if (isUnlocked) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.correctGreen.withValues(alpha: 0.15),
                          borderRadius: AppRadius.roundedBase,
                          border: Border.all(color: AppColors.correctGreen),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.correctGreen),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                AppStrings.premiumActiveStatus,
                                textAlign: TextAlign.center,
                                style: AppTypography.titleMedium(
                                  color: AppColors.correctGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final success = await _premiumService.buyProduct(_selectedTier);
                              if (!context.mounted) return;

                              if (_premiumService.purchaseError.value != null) {
                                final err = _premiumService.purchaseError.value!;
                                String displayMsg;
                                if (err == 'canceled') {
                                  displayMsg = AppStrings.premiumCancelledToast;
                                } else if (err == 'pending') {
                                  displayMsg = AppStrings.premiumPendingToast;
                                } else {
                                  displayMsg = AppStrings.premiumErrorToast;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(displayMsg)),
                                );
                              } else if (success) {
                                Navigator.of(context).pop();
                                _showCongratulationsDialog(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sealGold,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.roundedBase,
                        ),
                        textStyle: AppTypography.titleSmall(color: AppColors.primary),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            )
                          : Text(
                              AppStrings.premiumUnlockBtn,
                              textAlign: TextAlign.center,
                            ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Restore Purchases & Close Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: () async {
                          final restored = await _premiumService.restorePurchases();
                          if (context.mounted) {
                            if (restored) {
                              Navigator.of(context).pop();
                              _showCongratulationsDialog(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppStrings.premiumNoPurchasesFound),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          AppStrings.premiumRestoreBtn,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          AppStrings.premiumCloseBtn,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required String tierId,
    required String title,
    required String subtitle,
    required String price,
    required String badgeText,
    required bool isPopular,
    required bool isDark,
  }) {
    final isSelected = _selectedTier == tierId;

    return InkWell(
      onTap: () => setState(() => _selectedTier = tierId),
      borderRadius: AppRadius.roundedBase,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.sealGold.withValues(alpha: 0.15)
                  : AppColors.goldSoft)
              : (isDark ? AppColors.primaryLight : AppColors.darkTextPrimary),
          borderRadius: AppRadius.roundedBase,
          border: Border.all(
            color: isSelected
                ? AppColors.sealGold
                : (isDark ? AppColors.darkBorder : AppColors.borderStrong),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.sealGold : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The title and the tag share one wrap, so a long title
                  // never gets squeezed into a single letter per line.
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleSmall(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isPopular
                              ? AppColors.sealGold.withValues(alpha: 0.2)
                              : (isDark ? AppColors.darkBorder : AppColors.borderStrong),
                          borderRadius: AppRadius.roundedSm,
                          border: Border.all(
                            color: isPopular ? AppColors.sealGold : Colors.transparent,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: AppTypography.labelSmall(
                            color: isPopular
                                ? AppColors.sealGold
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTypography.labelSmall(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // The price may be long, so it wraps instead of running out of
            // the card.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Text(
                price,
                textAlign: TextAlign.right,
                style: AppTypography.titleSmall(
                  color: isSelected ? AppColors.sealGold : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    IconData icon,
    Color iconColor,
    String text, {
    bool isBold = false,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 17),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ).copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
      ],
    );
  }
}
