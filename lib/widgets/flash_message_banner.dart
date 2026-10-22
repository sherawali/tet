import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_shadows.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_strings.dart';
import '../design_system/app_snack_bar.dart';
import '../models/flash_message.dart';
import '../models/mock_config.dart';
import '../models/test_session.dart';
import '../services/flash_message_service.dart';
import '../services/language_service.dart';
import '../services/exam_service.dart';
import '../services/mock_engine.dart';
import '../services/premium_service.dart';
import '../screens/mock_series_screen.dart';
import '../screens/pyq_vault_screen.dart';
import '../widgets/premium_paywall_modal.dart';
import '../design_system/app_motion.dart';

class FlashMessageBanner extends StatefulWidget {
  /// Used only when a message names no destination at all.
  final VoidCallback? onActionTap;

  const FlashMessageBanner({super.key, this.onActionTap});

  @override
  State<FlashMessageBanner> createState() => _FlashMessageBannerState();
}

class _FlashMessageBannerState extends State<FlashMessageBanner> {
  final FlashMessageService _service = FlashMessageService();
  List<FlashMessage> _messages = [];
  bool _isLoading = true;
  int _currentPage = 0;
  late final PageController _pageController;
  Timer? _autoSlideTimer;

  /// Guards against a double tap that would open two screens.
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final msgs = await _service.getActiveMessages();
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _isLoading = false;
    });

    if (_messages.length > 1) {
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _messages.length <= 1) return;
      if (!_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _messages.length;
      _pageController.animateToPage(
        nextPage,
        duration: AppMotion.page,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _dismissCurrent(int index) async {
    if (index >= 0 && index < _messages.length) {
      final msg = _messages[index];
      await _service.dismissMessage(msg.id);

      if (!mounted) return;
      setState(() {
        _messages.removeAt(index);
        if (_currentPage >= _messages.length && _currentPage > 0) {
          _currentPage = _messages.length - 1;
        }
      });

      if (_messages.length <= 1) {
        _autoSlideTimer?.cancel();
      }
    }
  }

  // -------------------------------------------------------------------
  // The destination of the message
  // -------------------------------------------------------------------

  /// Opens whatever the message names: a screen of the app, a paper of the
  /// vault or a link in the browser.
  Future<void> _handleMessageTap(FlashMessage msg) async {
    if (_isOpening) return;
    _isOpening = true;
    try {
      final target = await _service.resolveTargetOf(msg);
      if (!mounted) return;
      await _openTarget(target);
    } catch (e) {
      debugPrint('Flash message could not be opened: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          title: LanguageService.instance.isHindi
              ? 'यह संदेश अभी नहीं खुल सका'
              : 'This message could not be opened',
        );
      }
    } finally {
      _isOpening = false;
    }
  }

  Future<void> _openTarget(FlashTarget target) async {
    switch (target.type) {
      case FlashTargetType.route:
        _openRoute(target.route ?? FlashRoutes.mockSeries);
        break;
      case FlashTargetType.paper:
        await _openPaper(target.paperId ?? '');
        break;
      case FlashTargetType.external:
        await _openExternal(target.url ?? '');
        break;
      case FlashTargetType.none:
        widget.onActionTap?.call();
    }
  }

  /// Opens a screen of the app.
  void _openRoute(String route) {
    final nav = Navigator.of(context);
    final Widget screen = switch (route) {
      FlashRoutes.pyqVault => const PyqVaultScreen(),
      _ => const MockSeriesScreen(),
    };
    nav.push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Opens the booklet of a paper of the vault.
  Future<void> _openPaper(String formId) async {
    if (formId.isEmpty) {
      widget.onActionTap?.call();
      return;
    }

    // A locked paper may not be opened for free.
    final premium = PremiumService.instance;
    if (!premium.hasUnlockedAccess && !premium.isPaperFree(formId: formId)) {
      PremiumPaywallModal.show(context);
      return;
    }

    final form = await _service.findPaperForm(formId);
    final data = await MockEngine().loadPrebuiltPaper(paperFormId: formId);
    if (!mounted) return;

    if (data.questions.isEmpty) {
      AppSnackBar.showError(context, title: AppStrings.emptyPaperTitle);
      return;
    }

    final declared = form?['total_questions'];
    final minutes =
        declared is int && declared > 0 ? declared : data.questions.length;
    final isMock =
        (form?['exam_date'] ?? '').toString().toLowerCase().contains('mock');

    final session = TestSession(
      id: 'flash_${formId}_${DateTime.now().millisecondsSinceEpoch}',
      config: MockConfig(
        mode: isMock ? MockMode.predicted : MockMode.pyq,
        seed: 2026100 + (formId.hashCode.abs() % 997),
        totalQuestions: data.questions.length,
        timeLimitMinutes: minutes,
        exam: ExamService.instance.examCode,
      ),
      questions: data.questions,
      passages: data.passages,
      paperTitle: form != null ? AppStrings.formatPaperTitle(form) : formId,
      setCode: (form?['set_code'] ?? 'A').toString(),
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamService.instance.buildExamScreen(session: session),
      ),
    );
  }

  /// Opens a link in the browser.
  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      widget.onActionTap?.call();
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      AppSnackBar.showInfo(
        context,
        title: LanguageService.instance.isHindi
            ? 'लिंक नहीं खुल सका'
            : 'The link could not be opened',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<AppLang>(
      valueListenable: LanguageService.instance.currentLanguage,
      builder: (context, lang, _) {
        final isHi = lang == AppLang.hi;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.primary : AppColors.primaryLight,
            borderRadius: AppRadius.roundedMd,
            border: Border.all(
              color: AppColors.sealGold.withValues(alpha: 0.6),
              width: 1.4,
            ),
            boxShadow: AppShadows.darkCard,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 130,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (idx) {
                    setState(() => _currentPage = idx);
                  },
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final title = msg.getLocalizedTitle(isHi);
                    final message = msg.getLocalizedMessage(isHi);
                    final actionLabel = msg.getLocalizedActionLabel(isHi);

                    // Type-specific accent colors and icons
                    final Color accentColor;
                    final IconData typeIcon;
                    switch (msg.type) {
                      case 'update':
                        accentColor = AppColors.accentBright;
                        typeIcon = Icons.system_update_rounded;
                        break;
                      case 'success':
                        accentColor = AppColors.correctGreen;
                        typeIcon = Icons.verified_rounded;
                        break;
                      case 'alert':
                      case 'warning':
                        accentColor = AppColors.goldBright;
                        typeIcon = Icons.notification_important_rounded;
                        break;
                      default:
                        accentColor = AppColors.sealGold;
                        typeIcon = Icons.campaign_rounded;
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The whole message opens the place it names.
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _handleMessageTap(msg),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Notice Icon Badge
                                  Container(
                                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: accentColor, width: 1.2),
                                    ),
                                    child: Icon(
                                      typeIcon,
                                      color: accentColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),

                                  // Full Text Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 2,
                                          style: AppTypography.titleSmall(
                                            color: AppColors.darkTextPrimary,
                                          ).copyWith(height: 1.25, letterSpacing: 0.2),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall(
                                            color: AppColors.darkTextSecondary,
                                          ).copyWith(height: 1.35),
                                        ),
                                        if (actionLabel != null) ...[
                                          const SizedBox(height: AppSpacing.xs),
                                          _ActionButton(
                                            label: actionLabel,
                                            accent: accentColor,
                                            onTap: () => _handleMessageTap(msg),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Right Controls: Slide Counter Badge + Dismiss Button
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_messages.length > 1) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    borderRadius: AppRadius.roundedFull,
                                  ),
                                  child: Text(
                                    '${index + 1}/${_messages.length}',
                                    style: AppTypography.labelSmall(
                                      color: AppColors.darkTextSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                              ],
                              if (msg.isDismissible)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  tooltip: LanguageService.instance.isHindi ? 'हटाएं' : 'Dismiss',
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.darkTextSecondary,
                                    size: 17,
                                  ),
                                  onPressed: () => _dismissCurrent(index),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Multi-message Interactive Dots Indicator
              if (_messages.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_messages.length, (idx) {
                    final isActive = idx == _currentPage;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          idx,
                          duration: AppMotion.slow,
                          curve: Curves.easeInOutCubic,
                        );
                      },
                      child: AnimatedContainer(
                        duration: AppMotion.slow,
                        curve: AppMotion.standard,
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                        width: isActive ? 18 : 6,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.sealGold : AppColors.deskGray,
                          borderRadius: AppRadius.roundedFull,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The button of the banner - it opens the place the message names.
class _ActionButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.2),
          borderRadius: AppRadius.roundedSm,
          border: Border.all(color: accent, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.roundedSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 14, color: accent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall(color: accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
