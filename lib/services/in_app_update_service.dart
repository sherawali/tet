import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service managing In-App Updates (IAU) via Google Play Core
class InAppUpdateService {
  InAppUpdateService._();
  static final InAppUpdateService instance = InAppUpdateService._();

  AppUpdateInfo? updateInfo;
  bool isChecking = false;

  /// Check for available updates on Google Play Store
  Future<AppUpdateInfo?> checkForUpdate() async {
    // Only supported on native Android
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    if (isChecking) return updateInfo;
    isChecking = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      updateInfo = info;
      isChecking = false;
      return info;
    } catch (_) {
      isChecking = false;
      return null;
    }
  }

  /// Perform flexible background download update
  Future<bool> startFlexibleUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      final info = updateInfo ?? await checkForUpdate();
      if (info != null && info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Complete downloaded flexible update
  Future<void> completeFlexibleUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {}
  }

  /// Perform immediate blocking update for critical releases
  Future<bool> performImmediateUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      final info = updateInfo ?? await checkForUpdate();
      if (info != null && info.immediateUpdateAllowed) {
        final result = await InAppUpdate.performImmediateUpdate();
        return result == AppUpdateResult.success;
      }
    } catch (_) {}
    return false;
  }
}
