import 'dart:async';
import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../models/flash_message.dart';
import '../services/flash_message_service.dart';

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
        duration: const Duration(milliseconds: 600),
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

  Future<void> _dismissBanner() async {
    final ids = _messages.map((m) => m.id).toList();
    await _service.dismissAll(ids);

    if (!mounted) return;
    setState(() {
      _messages.clear();
    });

    _autoSlideTimer?.cancel();
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
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
            height: 126,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) {
                setState(() => _currentPage = idx);
              },
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notice Icon Badge
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.sealGold.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.sealGold, width: 1.2),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: AppColors.sealGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Full Text Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msg.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  height: 1.25,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg.message,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                              if (msg.actionLabel != null && widget.onActionTap != null) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: widget.onActionTap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.sealGold.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.sealGold, width: 1),
                                    ),
                                    child: Text(
                                      '👉 ${msg.actionLabel!}',
                                      style: const TextStyle(
                                        color: AppColors.sealGoldLight,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Dismiss 'X' Button
                      if (msg.isDismissible)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'हटाएं (Dismiss)',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                          onPressed: _dismissBanner,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Multi-message Dots Indicator
          if (_messages.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_messages.length, (idx) {
                  final isActive = idx == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16 : 6,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.sealGold : const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
