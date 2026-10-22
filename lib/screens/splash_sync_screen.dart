import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_shadows.dart';
import '../design_system/app_strings.dart';
import '../services/language_service.dart';
import '../database/db_helper.dart';
import '../services/in_app_update_service.dart';
import 'home_screen.dart';
import '../design_system/app_motion.dart';
import '../widgets/app_button.dart';

class SplashSyncScreen extends StatefulWidget {
  const SplashSyncScreen({super.key});

  @override
  State<SplashSyncScreen> createState() => _SplashSyncScreenState();
}

class _SplashSyncScreenState extends State<SplashSyncScreen> {
  final DbHelper _db = DbHelper.instance;

  double _progress = 0.0;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _checkAndStartSync();
  }

  Future<void> _checkAndStartSync() async {
    // Ensure the authentic offline bank (9,720 questions / 181 passages) is
    // loaded from the bundled asset.  This never needs a connection.
    final loaded = await _db.ensureBundledAssetLoaded();
    final count = await _db.getQuestionCount();

    if (!loaded && count == 0) {
      // The bundled bank could not be opened at all - show the retry state
      // instead of an empty exam.
      if (mounted) {
        setState(() {
          _isError = true;
          _progress = 0;
          _statusMessage = AppStrings.splashNoInternet;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _progress = 1.0;
        _statusMessage = AppStrings.splashAvailable(count > 0 ? count : 9720);
      });
    }
    await Future.delayed(AppMotion.page);
    if (!mounted) return;
    _navigateToHome();

    // Check for Google Play app update only
    InAppUpdateService.instance.checkForUpdate().then((info) {
      if (info != null && info.flexibleUpdateAllowed) {
        InAppUpdateService.instance.startFlexibleUpdate();
      }
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, _) => const HomeScreen(),
        transitionsBuilder: (context, anim, _, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        transitionDuration: AppMotion.page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayStatus = _statusMessage ?? AppStrings.splashCheckingBank;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [AppColors.primary, AppColors.primaryDark, AppColors.primaryDark]
                // The light splash stays on parchment so that the ink
                // coloured title and subtitle always have a readable ground.
                : const [AppColors.paperIvory, AppColors.lightCard, AppColors.primarySubtle],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Top Right Language Toggle Button
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.base,
                child: InkWell(
                  onTap: () {
                    LanguageService.instance.toggleLanguage();
                  },
                  borderRadius: AppRadius.roundedSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardElevated : AppColors.lightCard,
                      borderRadius: AppRadius.roundedSm,
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1.2,
                      ),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.translate_rounded,
                          size: 18,
                          color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          AppStrings.langToggleLabel,
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Luxury App Emblem / Seal
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sealGold.withValues(alpha: isDark ? 0.28 : 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.sealGold,
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppColors.primary,
                              child: const Center(
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  size: 44,
                                  color: AppColors.sealGold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                            duration: AppMotion.page,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(height: AppSpacing.lg),

                      // App Title
                      Text(
                        AppStrings.splashTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.displayLarge(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: AppMotion.base,
                            duration: AppMotion.base,
                            curve: AppMotion.enter,
                          ),
                      const SizedBox(height: AppSpacing.xs),

                      // Subtitle
                      Text(
                        AppStrings.splashSubtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: AppMotion.base,
                            duration: AppMotion.base,
                            curve: AppMotion.enter,
                          ),
                      const SizedBox(height: AppSpacing.xxl),

                      // Glassmorphic Progress Container
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.base,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard.withValues(alpha: 0.8)
                              : AppColors.lightCard.withValues(alpha: 0.9),
                          borderRadius: AppRadius.roundedBase,
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.borderStrong,
                            width: 1.0,
                          ),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.roundedFull,
                              child: LinearProgressIndicator(
                                value: _isError ? 0 : (_progress > 0 ? _progress : null),
                                minHeight: 6,
                                backgroundColor: isDark ? AppColors.darkBorder : AppColors.borderStrong,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isError ? AppColors.danger : AppColors.sealGold,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              displayStatus,
                              textAlign: TextAlign.center,
                              style: AppTypography.caption(
                                color: _isError
                                    ? AppColors.danger
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: AppMotion.base,
                            duration: AppMotion.base,
                            curve: AppMotion.enter,
                          ),

                      if (_isError) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: AppStrings.splashRetryBtn,
                          variant: AppButtonVariant.primary,
                          icon: Icons.refresh_rounded,
                          width: double.infinity,
                          onPressed: () {
                            setState(() {
                              _isError = false;
                              _statusMessage = AppStrings.splashCheckingBank;
                            });
                            _checkAndStartSync();
                          },
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xxl),

                      // Authority Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sealGold.withValues(alpha: 0.1),
                          borderRadius: AppRadius.roundedFull,
                          border: Border.all(
                            color: AppColors.sealGold.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 14, color: AppColors.sealGold),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '100% Offline Access · ${AppStrings.currentExamYear} Pattern',
                              style: AppTypography.labelSmall(color: AppColors.sealGold),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: AppMotion.base,
                            duration: AppMotion.base,
                            curve: AppMotion.enter,
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
