import 'dart:async';
import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../models/flash_message.dart';
import '../services/flash_message_service.dart';
import '../services/language_service.dart';
import '../design_system/app_motion.dart';

class FlashMessageBanner extends StatefulWidget {
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
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.primary : AppColors.primaryLight,
            borderRadius: AppRadius.roundedMd,
            border: Border.all(
              color: AppColors.sealGold.withValues(alpha: 0.6),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
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
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notice Icon Badge
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(7),
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
                          const SizedBox(width: 10),

                          // Full Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    height: 1.25,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.lightBorder,
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                                if (actionLabel != null && widget.onActionTap != null) ...[
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: widget.onActionTap,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: accentColor, width: 1),
                                      ),
                                      child: Text(
                                        '👉 $actionLabel',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                      ),

                      // Right Controls: Slide Counter Badge + Dismiss Button
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_messages.length > 1) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.lightTextSecondary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${index + 1}/${_messages.length}',
                                style: const TextStyle(
                                  color: AppColors.darkTextSecondary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
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
              padding: const EdgeInsets.only(bottom: 7),
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
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 18 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.sealGold : AppColors.deskGray,
                        borderRadius: BorderRadius.circular(3),
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
