import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../database/db_helper.dart';

/// Service managing In-App Purchases (IAP) & Pro Access Passes
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  // Product IDs configured on Google Play Console
  static const String masterProductId = 'tet_master_all_access_599'; // ₹599 (Best Value - Net >₹500 to creator)
  static const String singlePaperProductId = 'tet_single_paper_299'; // ₹299 (Single Paper Tier)
  static const String legacyProductId = 'tet_2026_all_access_pass_99'; // ₹99 (Fallback)

  static const Set<String> _productIds = {
    masterProductId,
    singlePaperProductId,
    legacyProductId,
  };

  // Exactly 1 designated free flagship mock paper for each exam & paper
  static const Set<String> defaultFreePaperIds = {
    'utet-p1-fullmock',     // UTET Paper 1 Flagship PYQ
    'utet-p2-set-b',        // UTET Paper 2 Flagship PYQ (2023)
    'ctet-p1-2026-pyq',     // CTET Paper 1 Flagship Solved
    'ctet-p2-ms-mock-01',   // CTET Paper 2 Math-Science Flagship
    'ctet-p2-sst-mock-01',  // CTET Paper 2 SST Flagship
  };

  final ValueNotifier<bool> isPremiumUnlocked = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> purchaseError = ValueNotifier<String?>(null);

  // Broadcast stream to trigger Congratulations dialog anywhere in the app
  final StreamController<bool> _purchaseSuccessController = StreamController<bool>.broadcast();
  Stream<bool> get onPurchaseSuccess => _purchaseSuccessController.stream;

  // Remote GitHub-controlled Free vs Paid mock settings
  Set<String> remoteFreeFormIds = {};
  Set<String> remotePaidFormIds = {};
  int remoteFreeMockCount = 1;
  bool remoteAllMocksFree = false;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Map<String, ProductDetails> productsMap = {};
  Timer? _purchaseTimeoutTimer;

  /// Check if a specific paper form or index is Free
  bool isPaperFree({String? formId, int index = 0}) {
    if (isPremiumUnlocked.value) return true;
    if (remoteAllMocksFree) return true;
    if (formId != null) {
      if (remotePaidFormIds.contains(formId)) return false;
      if (remoteFreeFormIds.contains(formId)) return true;
      return defaultFreePaperIds.contains(formId);
    }
    return index == 0;
  }

  Future<void> updateRemoteConfig(Map<String, dynamic> config) async {
    try {
      remoteAllMocksFree = config['all_mocks_free'] == true;
      remoteFreeMockCount = (config['free_mock_count'] as num?)?.toInt() ?? 1;
      final freeList = config['free_form_ids'] as List<dynamic>? ?? [];
      remoteFreeFormIds = freeList.map((e) => e.toString()).toSet();
      final paidList = config['paid_form_ids'] as List<dynamic>? ?? [];
      remotePaidFormIds = paidList.map((e) => e.toString()).toSet();
      await DbHelper.instance.setMeta('cached_remote_config', jsonEncode(config));
    } catch (_) {}
  }

  Future<void> _loadCachedRemoteConfig() async {
    try {
      final raw = await DbHelper.instance.getMeta('cached_remote_config');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        remoteAllMocksFree = decoded['all_mocks_free'] == true;
        remoteFreeMockCount = (decoded['free_mock_count'] as num?)?.toInt() ?? 1;
        final freeList = decoded['free_form_ids'] as List<dynamic>? ?? [];
        remoteFreeFormIds = freeList.map((e) => e.toString()).toSet();
        final paidList = decoded['paid_form_ids'] as List<dynamic>? ?? [];
        remotePaidFormIds = paidList.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
  }

  Future<void> init() async {
    // 0. Load cached remote config from SQLite
    try {
      await _loadCachedRemoteConfig();
    } catch (_) {}

    // 1. Check local DB state
    try {
      final savedState = await DbHelper.instance.getMeta('is_premium_unlocked');
      if (savedState == '1') {
        isPremiumUnlocked.value = true;
      }
    } catch (_) {}

    // 2. Setup IAP Purchase Stream listener
    try {
      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          _purchaseTimeoutTimer?.cancel();
          purchaseError.value = error.toString();
          isLoading.value = false;
        },
      );
    } catch (_) {
      // Play Billing is not available on this platform - the app keeps
      // working with the locally stored premium state.
    }

    // 3. Load product details if store is available
    await loadProductDetails();
  }

  Future<void> loadProductDetails() async {
    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) return;

      final response = await _iap.queryProductDetails(_productIds);
      if (response.productDetails.isNotEmpty) {
        for (final product in response.productDetails) {
          productsMap[product.id] = product;
        }
      }
    } catch (_) {}
  }

  /// Purchase a specific tier: Master Pass (₹599) or Single Paper (₹299)
  Future<bool> buyProduct(String productId) async {
    isLoading.value = true;
    purchaseError.value = null;

    // Start a 45-second watchdog timer to guarantee loader never hangs indefinitely
    _purchaseTimeoutTimer?.cancel();
    _purchaseTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (isLoading.value) {
        isLoading.value = false;
      }
    });

    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        // If Google Play is not available (e.g. desktop sandbox or testing environment)
        // gracefully activate access locally
        await unlockAllAccessLocally();
        _purchaseTimeoutTimer?.cancel();
        isLoading.value = false;
        _purchaseSuccessController.add(true);
        return true;
      }

      if (!productsMap.containsKey(productId)) {
        await loadProductDetails();
      }

      final product = productsMap[productId] ?? productsMap[masterProductId] ?? productsMap[legacyProductId];
      if (product == null) {
        // The store is reachable but the product list could not be read -
        // this is an offline or not-signed-in situation.  Access must NOT be
        // unlocked here, otherwise a single tap while offline would grant
        // the complete premium pass for free.
        _purchaseTimeoutTimer?.cancel();
        purchaseError.value =
            'Purchase needs an internet connection. Please try again online.';
        isLoading.value = false;
        return false;
      }

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      final bool initiated = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return initiated;
    } catch (e) {
      _purchaseTimeoutTimer?.cancel();
      purchaseError.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  /// Buy Master All-Access Pass (default flagship ₹599)
  Future<bool> buyAllAccessPass() async {
    return buyProduct(masterProductId);
  }

  Future<bool> restorePurchases() async {
    isLoading.value = true;
    purchaseError.value = null;

    _purchaseTimeoutTimer?.cancel();
    _purchaseTimeoutTimer = Timer(const Duration(seconds: 25), () {
      if (isLoading.value) {
        isLoading.value = false;
      }
    });

    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        _purchaseTimeoutTimer?.cancel();
        isLoading.value = false;
        return isPremiumUnlocked.value;
      }
      await _iap.restorePurchases();
      _purchaseTimeoutTimer?.cancel();
      isLoading.value = false;
      return isPremiumUnlocked.value;
    } catch (e) {
      _purchaseTimeoutTimer?.cancel();
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

  /// Debug only: switch between the free and the paid experience.
  ///
  /// The switch is stored in the local database, so it stays until it is
  /// turned off again.  It does not exist in a release build and it never
  /// touches the store.
  Future<void> setDebugPremiumOverride(bool enabled) async {
    if (!kDebugMode) return;
    if (enabled) {
      await unlockAllAccessLocally();
    } else {
      await lockAllAccessLocally();
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    _purchaseTimeoutTimer?.cancel();

    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Purchase initiated in Google Play sheet
        isLoading.value = true;
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        // User backed out or cancelled in UPI / Google Play sheet
        isLoading.value = false;
        purchaseError.value = 'canceled';
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Error from Google Play billing
        isLoading.value = false;
        purchaseError.value = purchaseDetails.error?.message ?? 'error';
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Successfully verified purchase!
        await unlockAllAccessLocally();
        isLoading.value = false;
        purchaseError.value = null;

        // Broadcast success to trigger Congratulations dialog
        _purchaseSuccessController.add(true);

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void dispose() {
    _purchaseTimeoutTimer?.cancel();
    _subscription?.cancel();
    _purchaseSuccessController.close();
    isPremiumUnlocked.dispose();
    isLoading.dispose();
    purchaseError.dispose();
  }
}
