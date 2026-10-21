import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_strings.dart';
import '../services/language_service.dart';
import '../database/db_helper.dart';
import '../services/in_app_update_service.dart';
import 'home_screen.dart';
import '../design_system/app_motion.dart';

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
                : const [AppColors.lightCard, AppColors.darkTextPrimary, AppColors.primarySubtle],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Top Right Language Toggle Button
              Positioned(
                top: 14,
                right: 16,
                child: InkWell(
                  onTap: () {
                    LanguageService.instance.toggleLanguage();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardElevated : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.translate_rounded,
                          size: 18,
                          color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          AppStrings.langToggleLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24),
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
                      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 22),

                      // App Title
                      Text(
                        AppStrings.splashTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.displayLarge(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ).copyWith(fontSize: 25, letterSpacing: 0.5),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 6),

                      // Subtitle
                      Text(
                        AppStrings.splashSubtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ).copyWith(fontSize: 13.5),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 36),

                      // Glassmorphic Progress Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.borderStrong,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                            const SizedBox(height: 12),
                            Text(
                              displayStatus,
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium(
                                color: _isError
                                    ? AppColors.danger
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ).copyWith(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms),

                      if (_isError) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isError = false;
                              _statusMessage = AppStrings.splashCheckingBank;
                            });
                            _checkAndStartSync();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(
                            AppStrings.splashRetryBtn,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.roundedBase,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Authority Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.sealGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.sealGold.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 14, color: AppColors.sealGold),
                            const SizedBox(width: 5),
                            Text(
                              '100% Offline Access · ${AppStrings.currentExamYear} Pattern',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.sealGold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms),
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
