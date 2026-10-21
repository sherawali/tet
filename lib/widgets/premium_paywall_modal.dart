import 'dart:async';
import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
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

  static void _showCongratulationsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.primary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.sealGold, width: 2),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 14),
            Text(
              AppStrings.congratulationsTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryLight : AppColors.successSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.correctGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.correctGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.premiumFeature4,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                AppStrings.startPreparingBtn,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.sealGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            18,
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
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Crown Badge & Title
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 10),

                Text(
                  AppStrings.premiumPassTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.premiumPassSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

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
                  const SizedBox(height: 10),

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
                  const SizedBox(height: 14),
                ],

                // Features Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryLight : AppColors.darkTextPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
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
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        Icons.history_edu_rounded,
                        AppColors.sealGold,
                        AppStrings.premiumFeature2,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        Icons.insights_rounded,
                        AppColors.sealGold,
                        AppStrings.premiumFeature3,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
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
                const SizedBox(height: 14),

                // Action / Unlock Button
                ValueListenableBuilder<bool>(
                  valueListenable: _premiumService.isLoading,
                  builder: (context, isLoading, _) {
                    if (isUnlocked) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.correctGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.correctGreen),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.correctGreen),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.premiumActiveStatus,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.correctGreen,
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 8),

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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.sealGold.withValues(alpha: 0.15)
                  : AppColors.goldSoft)
              : (isDark ? AppColors.primaryLight : AppColors.darkTextPrimary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.sealGold
                : (isDark ? Colors.white12 : Colors.black12),
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
              color: isSelected ? AppColors.sealGold : (isDark ? Colors.white38 : Colors.black26),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The title and the tag share one wrap, so a long title
                  // never gets squeezed into a single letter per line.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPopular
                              ? AppColors.sealGold.withValues(alpha: 0.2)
                              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPopular ? AppColors.sealGold : Colors.transparent,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isPopular
                                ? AppColors.sealGold
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // The price may be long, so it wraps instead of running out of
            // the card.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Text(
                price,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? AppColors.sealGold : (isDark ? Colors.white70 : Colors.black87),
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
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
