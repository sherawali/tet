import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_typography.dart';

/// Ultra-Premium Toast & SnackBar System
/// Matches the app's authentic Examination Authority & Obsidian Gold / Sapphire theme.
class AppSnackBar {
  static void showReportSuccess(
    BuildContext context, {
    required int questionNumber,
    required String reportCode,
    String? title,
    String? message,
  }) {
    show(
      context,
      title: title ?? 'रिपोर्ट दर्ज कर ली गई है',
      message: message ?? 'प्रश्न $questionNumber · संदर्भ कोड: $reportCode · विशेषज्ञ दल जांच करेगा',
      icon: Icons.verified_rounded,
      accentColor: const Color(0xFFF59E0B), // Seal Amber Gold
      backgroundColor: const Color(0xFF0F172A), // Obsidian Slate
      duration: const Duration(seconds: 4),
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      accentColor: const Color(0xFF10B981), // Emerald Green
      backgroundColor: const Color(0xFF0F172A),
      duration: duration,
    );
  }

  static void showError(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      message: message,
      icon: Icons.error_rounded,
      accentColor: const Color(0xFFEF4444), // Crimson
      backgroundColor: const Color(0xFF0F172A),
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      title: title,
      message: message,
      icon: Icons.info_rounded,
      accentColor: const Color(0xFF38BDF8), // Sky Blue
      backgroundColor: const Color(0xFF0F172A),
      duration: duration,
    );
  }

  static void show(
    BuildContext context, {
    required String title,
    String? message,
    required IconData icon,
    required Color accentColor,
    Color backgroundColor = const Color(0xFF0F172A),
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    HapticFeedback.lightImpact();

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        duration: duration,
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Subtle top gradient accent glow line
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 2.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.2),
                          accentColor,
                          accentColor.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Glowing icon badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.16),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text column
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                            if (message != null && message.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.notoSansDevanagari(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFCBD5E1),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Optional Action or Dismiss
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: accentColor.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: AppTypography.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
