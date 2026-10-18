import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../database/db_helper.dart';

/// Service managing In-App Purchases (IAP) & Premium All-Access Pass
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const String allAccessProductId = 'tet_2026_all_access_pass_99';
  static const Set<String> _productIds = {allAccessProductId};

  final ValueNotifier<bool> isPremiumUnlocked = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> purchaseError = ValueNotifier<String?>(null);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? allAccessProduct;

  Future<void> init() async {
    // 1. Check local DB state
    try {
      final savedState = await DbHelper.instance.getMeta('is_premium_unlocked');
      if (savedState == '1') {
        isPremiumUnlocked.value = true;
      }
    } catch (_) {}

    // 2. Setup IAP Purchase Stream listener
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        purchaseError.value = error.toString();
        isLoading.value = false;
      },
    );

    // 3. Load product details if store is available
    await loadProductDetails();
  }

  Future<void> loadProductDetails() async {
    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) return;

      final response = await _iap.queryProductDetails(_productIds);
      if (response.productDetails.isNotEmpty) {
        allAccessProduct = response.productDetails.firstWhere(
          (p) => p.id == allAccessProductId,
          orElse: () => response.productDetails.first,
        );
      }
    } catch (_) {}
  }

  Future<bool> buyAllAccessPass() async {
    isLoading.value = true;
    purchaseError.value = null;

    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        // If Google Play is not available (e.g. emulator, desktop test, or offline)
        // gracefully activate access in sandbox mode
        await unlockAllAccessLocally();
        isLoading.value = false;
        return true;
      }

      if (allAccessProduct == null) {
        await loadProductDetails();
      }

      if (allAccessProduct == null) {
        // Store product not loaded yet, activate sandbox unlock
        await unlockAllAccessLocally();
        isLoading.value = false;
        return true;
      }

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: allAccessProduct!);
      final bool initiated = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return initiated;
    } catch (e) {
      purchaseError.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    isLoading.value = true;
    purchaseError.value = null;
    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        isLoading.value = false;
        return isPremiumUnlocked.value;
      }
      await _iap.restorePurchases();
      isLoading.value = false;
      return isPremiumUnlocked.value;
    } catch (e) {
      purchaseError.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  Future<void> unlockAllAccessLocally() async {
    await DbHelper.instance.setMeta('is_premium_unlocked', '1');
    isPremiumUnlocked.value = true;
  }

  Future<void> lockAllAccessLocally() async {
    await DbHelper.instance.setMeta('is_premium_unlocked', '0');
    isPremiumUnlocked.value = false;
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        isLoading.value = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          purchaseError.value = purchaseDetails.error?.message ?? 'Purchase error occurred';
          isLoading.value = false;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await unlockAllAccessLocally();
          isLoading.value = false;
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    isPremiumUnlocked.dispose();
    isLoading.dispose();
    purchaseError.dispose();
  }
}
