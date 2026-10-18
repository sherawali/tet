import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_strings.dart';
import '../services/premium_service.dart';

class PremiumPaywallModal extends StatefulWidget {
  const PremiumPaywallModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PremiumPaywallModal(),
    );
  }

  @override
  State<PremiumPaywallModal> createState() => _PremiumPaywallModalState();
}

class _PremiumPaywallModalState extends State<PremiumPaywallModal> {
  final PremiumService _premiumService = PremiumService.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
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
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Crown Badge & Title
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
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
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  AppStrings.premiumPassTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.premiumPassSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Features Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        Icons.check_circle_rounded,
                        AppColors.correctGreen,
                        'SET-P ${AppStrings.currentExamYear} मुख्य पेपर — 100% मुफ़्त (Free)',
                        isBold: true,
                        isDark: isDark,
                      ),
                      const Divider(height: 14, thickness: 0.5),
                      _buildFeatureRow(
                        Icons.lock_open_rounded,
                        AppColors.sealGold,
                        'SET-Q, R, S, T के सभी 4 सम्पूर्ण 150Q मॉडल पेपर्स',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        Icons.menu_book_rounded,
                        AppColors.sealGold,
                        '10 सम्पूर्ण मॉडल प्रश्न-पुस्तिकाएं (SET-01 से SET-10)',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        Icons.history_edu_rounded,
                        AppColors.sealGold,
                        'विगत वर्ष प्रश्न (PYQ): सभी प्रामाणिक बोर्ड प्रश्न-पत्र',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        Icons.category_rounded,
                        AppColors.sealGold,
                        '35+ विषय-वार अभ्यास सेट्स और टॉपिक-वार केंद्रित ड्रिल्स',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        Icons.offline_pin_rounded,
                        AppColors.sealGold,
                        '100% विज्ञापन-मुक्त · बिना इंटरनेट आजीवन पूर्ण एक्सेस',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Price Tag
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.sealGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.sealGold, width: 1),
                    ),
                    child: Text(
                      AppStrings.premiumPriceBadge,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sealGold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Unlock Button
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
                              final success = await _premiumService.buyAllAccessPass();
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppStrings.premiumSuccessToast),
                                    backgroundColor: AppColors.sealGold,
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sealGold,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
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
                const SizedBox(height: 10),

                // Restore Purchases & Cancel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final restored = await _premiumService.restorePurchases();
                        if (context.mounted) {
                          if (restored) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.premiumSuccessToast),
                                backgroundColor: AppColors.sealGold,
                              ),
                            );
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('कोई पूर्व खरीद नहीं मिली (No previous purchase found).'),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        AppStrings.premiumRestoreBtn,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'बंद करें (Close)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
