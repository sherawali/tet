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
  String _selectedExam = 'utet';
  StreamSubscription<bool>? _successSubscription;
  bool _celebrationShown = false;

  /// The product of the "one exam" pass.
  String get _examProductId => _selectedExam == 'ctet'
      ? PremiumService.ctetProductId
      : PremiumService.utetProductId;

  @override
  void initState() {
    super.initState();
    _successSubscription = _premiumService.onPurchaseSuccess.listen((_) {
      _celebrate();
    });
  }

  @override
  void dispose() {
    _successSubscription?.cancel();
    super.dispose();
  }

  /// The chooser of the exam of the "one exam" pass.
  Widget _buildExamSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.proPackWhichExam,
          style: AppTypography.labelMedium(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildExamOption(
                isDark,
                label: AppStrings.proPackOnlyUtet,
                selected: _selectedExam == 'utet',
                onTap: () => setState(() {
                  _selectedExam = 'utet';
                  if (_selectedTier == PremiumService.ctetProductId) {
                    _selectedTier = PremiumService.utetProductId;
                  }
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildExamOption(
                isDark,
                label: AppStrings.proPackOnlyCtet,
                selected: _selectedExam == 'ctet',
                onTap: () => setState(() {
                  _selectedExam = 'ctet';
                  if (_selectedTier == PremiumService.utetProductId) {
                    _selectedTier = PremiumService.ctetProductId;
                  }
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.proPackSelectorHint,
          style: AppTypography.labelSmall(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }

  /// One exam of the "one exam" pass.
  Widget _buildExamOption(
    bool isDark, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.roundedSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.sealGold.withValues(alpha: 0.18)
              : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
          borderRadius: AppRadius.roundedSm,
          border: Border.all(
            color: selected
                ? AppColors.sealGold
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: selected
                  ? AppColors.sealGold
                  : (isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium(
                  color: selected
                      ? AppColors.sealGold
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the congratulations dialog once and closes the sheet afterwards.
  ///
  /// The dialog is opened before the sheet is closed, so the context is
  /// never used after the widget was popped.
  Future<void> _celebrate() async {
    if (!mounted || _celebrationShown) return;
    _celebrationShown = true;
    await _showCongratulationsDialog(context);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// The message of a failed purchase.
  ///
  /// Every failure of the store has its own wording, so the candidate always
  /// knows what happened.
  String _messageFor(PremiumPurchaseResult result) {
    switch (result) {
      case PremiumPurchaseResult.unlocked:
        return AppStrings.premiumSuccessToast;
      case PremiumPurchaseResult.cancelled:
        return AppStrings.premiumCancelledToast;
      case PremiumPurchaseResult.pending:
        return AppStrings.premiumPendingToast;
      case PremiumPurchaseResult.storeUnavailable:
        return _storeUnavailableMessage;
      case PremiumPurchaseResult.offline:
        return _offlineMessage;
      case PremiumPurchaseResult.failed:
        return AppStrings.premiumErrorToast;
    }
  }

  /// The Google Play Store is not installed on this device.
  String get _storeUnavailableTitle =>
      AppStrings.isHindi ? 'Google Play उपलब्ध नहीं है' : 'Google Play is not available';

  String get _storeUnavailableMessage => AppStrings.isHindi
      ? 'इस डिवाइस पर Google Play स्टोर नहीं है, इसलिए प्रो पास यहाँ से खरीदा नहीं जा सकता। कृपया Google Play वाले डिवाइस पर इंस्टॉल करके फिर कोशिश करें।'
      : 'This device has no Google Play Store, so the Pro Pass cannot be bought here. Install the app on a device with Google Play and try again.';

  /// The store is there, but it cannot be reached.
  String get _offlineTitle =>
      AppStrings.isHindi ? 'इंटरनेट कनेक्शन नहीं है' : 'No internet connection';

  String get _offlineMessage => AppStrings.isHindi
      ? 'Google Play तक पहुँचना संभव नहीं है। कृपया इंटरनेट चालू करके फिर कोशिश करें।'
      : 'Google Play cannot be reached right now. Please turn the internet on and try again.';

  /// The banner that explains why the pass cannot be bought right now.
  Widget? _buildStoreBanner(bool isDark) {
    final status = _premiumService.storeStatus.value;
    if (status == PremiumStoreStatus.available ||
        status == PremiumStoreStatus.unknown) {
      return null;
    }
    final isNoStore = status == PremiumStoreStatus.noStore;
    final title = isNoStore ? _storeUnavailableTitle : _offlineTitle;
    final message = isNoStore ? _storeUnavailableMessage : _offlineMessage;
    final color = isNoStore ? AppColors.warning : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.roundedBase,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isNoStore
                ? Icons.storefront_outlined
                : Icons.wifi_off_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall(color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: AppTypography.bodySmall(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The one border of this file.
  Border _cardBorder({Color? color, double width = 1.2}) => Border.all(
        color: color ?? AppColors.borderStrong,
        width: width,
      );

  static Future<void> _showCongratulationsDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
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

                // The reason why the pass cannot be bought right now.
                ValueListenableBuilder<PremiumStoreStatus>(
                  valueListenable: _premiumService.storeStatus,
                  builder: (context, status, _) {
                    final banner = _buildStoreBanner(isDark);
                    return banner ?? const SizedBox.shrink();
                  },
                ),

                // Tier Selection Cards
                if (!isUnlocked) ...[
                  // The exam of the "one exam" pass
                  _buildExamSelector(isDark),
                  const SizedBox(height: AppSpacing.sm),

                  // Tier 1: Full Access Pro Pass (every exam, every paper)
                  _buildTierCard(
                    tierId: PremiumService.masterProductId,
                    title: AppStrings.proPackFullTitle,
                    subtitle: AppStrings.proPackFullSubNew,
                    bulletLines: AppStrings.proPackFullBullets,
                    price: _premiumService.priceOf(PremiumService.masterProductId),
                    badgeText: AppStrings.proPackMostPopular,
                    isPopular: true,
                    isDark: isDark,
                    anchorText: AppStrings.proPackAnchorValue,
                    noteText: AppStrings.proPackPerMonth,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Tier 2: One Exam Pro Pass (UTET or CTET)
                  _buildTierCard(
                    tierId: _examProductId,
                    title: _selectedExam == 'ctet'
                        ? AppStrings.proPackCtetTitle
                        : AppStrings.proPackUtetTitle,
                    subtitle: _selectedExam == 'ctet'
                        ? AppStrings.proPackCtetSub
                        : AppStrings.proPackUtetSub,
                    bulletLines: _selectedExam == 'ctet'
                        ? AppStrings.proPackCtetBullets
                        : AppStrings.proPackUtetBullets,
                    price: _premiumService.priceOf(_examProductId),
                    badgeText: AppStrings.proPackValidYear,
                    isPopular: false,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Tier 3: Single Paper Pro Pass
                  _buildTierCard(
                    tierId: PremiumService.singlePaperProductId,
                    title: AppStrings.proPackSingleTitleNew,
                    subtitle: AppStrings.proPackSingleSub,
                    bulletLines: AppStrings.proPackSingleBullets,
                    price:
                        _premiumService.priceOf(PremiumService.singlePaperProductId),
                    badgeText: AppStrings.proPackValidDays,
                    isPopular: false,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // The promise of the pass
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: AppColors.correctGreen,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          AppStrings.proPackGuarantee,
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // The prices are the usual ones while the store is away.
                  if (_premiumService.storeStatus.value !=
                      PremiumStoreStatus.available) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.proPackFallbackNote,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
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
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUnlocked)
                          Container(
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
                          )
                        else
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    final result = await _premiumService
                                        .buyProduct(_selectedTier);
                                    if (!context.mounted) return;

                                    if (result == PremiumPurchaseResult.unlocked) {
                                      _celebrate();
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_messageFor(result))),
                                    );
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
                          ),
                        const SizedBox(height: AppSpacing.sm),

                        // Restore Purchases & Close Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        final result = await _premiumService
                                            .restorePurchases();
                                        if (!context.mounted) return;

                                        if (result ==
                                            PremiumPurchaseResult.unlocked) {
                                          _celebrate();
                                          return;
                                        }
                                        final message = result ==
                                                PremiumPurchaseResult
                                                    .storeUnavailable
                                            ? _storeUnavailableMessage
                                            : (result ==
                                                    PremiumPurchaseResult.offline
                                                ? _offlineMessage
                                                : AppStrings
                                                    .premiumNoPurchasesFound);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(message),
                                          ),
                                        );
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
                    );
                  },
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
    List<String> bulletLines = const [],
    String? anchorText,
    String? noteText,
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
                  // "Kya milega": the plain list of what this tier unlocks.
                  if (bulletLines.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    ...bulletLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: isPopular
                                    ? AppColors.sealGold
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                line,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // The price may be long, so it wraps instead of running out of
            // the card.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (anchorText != null)
                    Text(
                      anchorText,
                      textAlign: TextAlign.right,
                      style: AppTypography.labelSmall(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ).copyWith(
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.danger,
                      ),
                    ),
                  Text(
                    price,
                    textAlign: TextAlign.right,
                    style: AppTypography.titleSmall(
                      color: isSelected ? AppColors.sealGold : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                  if (noteText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        noteText,
                        textAlign: TextAlign.right,
                        style: AppTypography.labelSmall(
                          color: isSelected
                              ? AppColors.sealGoldLight
                              : (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted),
                        ),
                      ),
                    ),
                ],
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
