import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import '../database/db_helper.dart';

/// Service managing In-App Reviews (IAR) for Google Play Store ratings
class InAppReviewService {
  InAppReviewService._();
  static final InAppReviewService instance = InAppReviewService._();

  final InAppReview _inAppReview = InAppReview.instance;

  /// Check if review dialog can be shown and trigger review after test milestones
  Future<bool> checkAndPromptReview({bool force = false}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }

    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) return false;

      // Check if already reviewed
      final reviewed = await DbHelper.instance.getMeta('has_reviewed_app');
      if (reviewed == '1' && !force) return false;

      // Increment test completion count
      final countStr = await DbHelper.instance.getMeta('tests_completed_count') ?? '0';
      final count = (int.tryParse(countStr) ?? 0) + 1;
      await DbHelper.instance.setMeta('tests_completed_count', count.toString());

      // Trigger after at least 1-2 tests or on force
      if (force || count >= 2) {
        await _inAppReview.requestReview();
        await DbHelper.instance.setMeta('has_reviewed_app', '1');
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Direct link to Play Store listing for manual rating
  Future<void> openStoreListing() async {
    if (kIsWeb) return;
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.openStoreListing();
      }
    } catch (_) {}
  }
}
