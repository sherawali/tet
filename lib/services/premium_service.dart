import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../database/db_helper.dart';
import 'pass_plan.dart';

/// The outcome of a purchase or of a restore.
///
/// The caller gets the real result of the store round trip, so a failed or a
/// cancelled payment can never be mistaken for a successful purchase.
enum PremiumPurchaseResult {
  /// The pass is active now.
  unlocked,

  /// The candidate backed out of the Google Play sheet.
  cancelled,

  /// The payment is still being processed by the payment provider.
  pending,

  /// The device has no Play Store (emulator, desktop, sideloaded build).
  storeUnavailable,

  /// The store is there but could not be reached (offline, not signed in).
  offline,

  /// Anything else went wrong.
  failed,
}

/// How the Play Store answered the last request.
enum PremiumStoreStatus {
  /// The store has not been asked yet.
  unknown,

  /// The store answered and the products are known.
  available,

  /// There is no Play Store on this device.
  noStore,

  /// The store is there but could not be reached.
  offline,
}

/// Service managing In-App Purchases (IAP) & Pro Access Passes
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  // The products of the Play Console.  The plan (the prices, the days and
  // the tiers) lives in PassPlan, the ids live here.
  static const String masterProductId = PassPlan.fullAccessProductId;
  static const String singlePaperProductId = PassPlan.singlePaperProductId;
  static const String utetProductId = PassPlan.utetProductId;
  static const String ctetProductId = PassPlan.ctetProductId;
  static const String legacyProductId = PassPlan.legacyFallbackProductId;

  /// Every product the app knows, the old ones included.
  static const Set<String> _productIds = {
    ...PassPlan.allProductIds,
  };

  /// The database key that holds the verified entitlement.  Only a purchase
  /// that the store confirmed writes this key, so the pass survives a restart.
  static const String unlockMetaKey = 'is_premium_unlocked';

  /// The database key that holds the product of the pass.
  static const String productMetaKey = 'is_premium_product';

  /// The database key that holds the day the pass runs out.
  static const String expiryMetaKey = 'is_premium_expires_at';

  /// The database key that holds the debug only override.  A release build
  /// never reads it, so a debug session can never unlock a release build.
  static const String debugOverrideMetaKey = 'is_premium_debug_override';

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

  /// The machine readable code of the last failed purchase.  It is kept for
  /// the screens that only watch this notifier.
  final ValueNotifier<String?> purchaseError = ValueNotifier<String?>(null);

  /// The state of the Play Store connection.
  final ValueNotifier<PremiumStoreStatus> storeStatus =
      ValueNotifier<PremiumStoreStatus>(PremiumStoreStatus.unknown);

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

  /// The user action that is waiting for the store (a purchase or a restore).
  Completer<PremiumPurchaseResult>? _pendingRequest;

  /// The product of the pass that is active.
  String? _activeProductId;

  /// The day the active pass runs out.
  DateTime? _activeExpiry;

  /// The product of the active pass (null when the app is in the free mode).
  String? get activeProductId => _activeProductId;

  /// The day the active pass runs out (null when it does not run out).
  DateTime? get activeExpiry => _activeExpiry;

  /// The paper a single paper pass was bought for.
  String? _singlePaperFormId;

  /// The price of a product.
  ///
  /// The price of the store is used as soon as the store answered, so a
  /// price can be changed without a new release of the app.  The fallback of
  /// the plan is shown while the store cannot be reached.
  String priceOf(String productId) {
    final product = productsMap[productId];
    if (product != null) {
      // The price of the store is already formatted with its currency.
      return product.price;
    }
    return '₹${PassPlan.priceOf(productId)}';
  }

  /// Does the app know this product?
  bool isKnownProduct(String productId) => _productIds.contains(productId);

  /// Check if a specific paper form or index is Free
  ///
  /// The pass of the candidate decides: a UTET pass opens the UTET papers
  /// only, a CTET pass the CTET papers only and the full access pass
  /// everything.  A pass that has run out opens nothing.
  bool isPaperFree({String? formId, int index = 0}) {
    if (remoteAllMocksFree) return true;

    if (formId != null) {
      // The pass of the candidate.
      final productId = _activeProductId;
      if (productId != null && _passIsValid) {
        if (PassPlan.unlocksPaper(
          productId,
          formId,
          singlePaperFormId: _singlePaperFormId,
        )) {
          return true;
        }
      }
      // The free papers are free for everybody, also with a pass.
      if (remoteFreeFormIds.contains(formId)) return true;
      if (defaultFreePaperIds.contains(formId)) return true;
      if (remotePaidFormIds.contains(formId)) return false;
    }

    if (isPremiumUnlocked.value) return true;
    return index == 0;
  }

  /// Is the pass still running?
  bool get _passIsValid {
    final expiry = _activeExpiry;
    if (expiry == null) return true;
    return expiry.isAfter(DateTime.now());
  }

  /// The days the active pass still has, null when there is no pass.
  int? get activePassDaysLeft {
    final expiry = _activeExpiry;
    if (expiry == null || !_passIsValid) return null;
    return expiry.difference(DateTime.now()).inDays + 1;
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

    // 1. Setup IAP Purchase Stream listener.  It comes first, so a purchase
    //    that the store reports while the app starts is never missed.
    try {
      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) {
          _purchaseTimeoutTimer?.cancel();
          isLoading.value = false;
          _finishRequest(PremiumPurchaseResult.failed);
        },
      );
    } catch (_) {
      // Play Billing is not available on this platform - the app keeps
      // working with the locally stored premium state.
    }

    // 2. Check local DB state.  The entitlement lives in SQLite, so the pass
    //    is still there after the app was closed.
    await _restoreLocalState();

    // 3. Load product details if store is available
    await loadProductDetails();

    // 4. A purchase that is already owned has to unlock the app right away.
    //    The store reports it as "restored" through the purchase stream, so
    //    the pass becomes active without any interaction of the candidate.
    if (!isPremiumUnlocked.value) {
      unawaited(_restoreOwnedPurchaseInBackground());
    }
  }

  /// Reads the stored entitlement from the local database.
  Future<void> _restoreLocalState() async {
    try {
      final savedState = await DbHelper.instance.getMeta(unlockMetaKey);
      if (savedState == '1') {
        _activeProductId = await DbHelper.instance.getMeta(productMetaKey);
        final expiry = await DbHelper.instance.getMeta(expiryMetaKey);
        if (expiry != null && expiry.isNotEmpty) {
          _activeExpiry = DateTime.tryParse(expiry);
        }
        // A pass that has run out does not open the papers any more.
        if (_activeExpiry == null || _activeExpiry!.isAfter(DateTime.now())) {
          isPremiumUnlocked.value = true;
        } else {
          await lockAllAccessLocally();
        }
      }
    } catch (_) {}

    // The debug override is only honoured by a debug build.
    if (kDebugMode) {
      try {
        final debugState = await DbHelper.instance.getMeta(debugOverrideMetaKey);
        if (debugState == '1') {
          isPremiumUnlocked.value = true;
        }
      } catch (_) {}
    }
  }

  /// Asks the store for the purchases of this app.  A purchase that is
  /// already owned arrives as a "restored" purchase and unlocks the pass.
  Future<void> _restoreOwnedPurchaseInBackground() async {
    if (storeStatus.value != PremiumStoreStatus.available) return;
    try {
      await _iap.restorePurchases();
    } catch (_) {
      // The store could not be reached - the app simply stays in the free
      // mode and the candidate can try again from the payment sheet.
    }
  }

  /// Reads the product details from the Play Store.
  Future<void> loadProductDetails() async {
    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        // There is no Play Store on this device (emulator, desktop, a
        // sideloaded build).  The pass simply cannot be sold here.
        storeStatus.value = PremiumStoreStatus.noStore;
        return;
      }

      final response = await _iap.queryProductDetails(_productIds);
      if (response.error != null) {
        // The store is there but it could not be reached.
        storeStatus.value = PremiumStoreStatus.offline;
        return;
      }
      if (response.productDetails.isEmpty) {
        // The store answered, but the products are not readable (offline or
        // the Play account is not signed in).
        storeStatus.value = PremiumStoreStatus.offline;
        return;
      }
      for (final product in response.productDetails) {
        productsMap[product.id] = product;
      }
      storeStatus.value = PremiumStoreStatus.available;
    } catch (_) {
      storeStatus.value = PremiumStoreStatus.offline;
    }
  }

  /// Buys one of the passes of the plan.
  ///
  /// The future completes with the real result of the store round trip, so
  /// the caller can tell a successful purchase from a cancelled or a failed
  /// one.  Nothing is unlocked unless the store confirmed a purchase.
  Future<PremiumPurchaseResult> buyProduct(String productId) async {
    if (isPremiumUnlocked.value) return PremiumPurchaseResult.unlocked;

    isLoading.value = true;
    purchaseError.value = null;

    final completer = Completer<PremiumPurchaseResult>();
    _pendingRequest = completer;

    // A watchdog timer guarantees that the loader never hangs forever.
    _purchaseTimeoutTimer?.cancel();
    _purchaseTimeoutTimer = Timer(const Duration(seconds: 90), () {
      if (completer.isCompleted) return;
      _finishRequest(PremiumPurchaseResult.failed);
      isLoading.value = false;
    });

    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        storeStatus.value = PremiumStoreStatus.noStore;
        return _rejectRequest(PremiumPurchaseResult.storeUnavailable);
      }

      if (!productsMap.containsKey(productId)) {
        await loadProductDetails();
      }

      final product = productsMap[productId];
      if (product == null) {
        if (storeStatus.value == PremiumStoreStatus.available) {
          // The store is there, but this pass is not on sale.
          return _rejectRequest(PremiumPurchaseResult.failed);
        }
        // The store is reachable but the product could not be read - this is
        // an offline or a not-signed-in situation.  Access must NOT be
        // unlocked here, otherwise a single tap while offline would grant
        // the complete premium pass for free.
        return _rejectRequest(PremiumPurchaseResult.offline);
      }

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      final bool initiated = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!initiated) {
        return _rejectRequest(PremiumPurchaseResult.failed);
      }

      // The Google Play sheet is open.  The result arrives through the
      // purchase stream, so the caller waits for it.
      final result = await completer.future;
      return result;
    } catch (e) {
      return _rejectRequest(PremiumPurchaseResult.failed);
    }
  }

  /// Buys the pass that opens every paper of the app.
  Future<PremiumPurchaseResult> buyAllAccessPass() async {
    return buyProduct(masterProductId);
  }

  /// Looks for a purchase of this app and activates it when it is owned.
  Future<PremiumPurchaseResult> restorePurchases() async {
    if (isPremiumUnlocked.value) return PremiumPurchaseResult.unlocked;

    isLoading.value = true;
    purchaseError.value = null;

    final completer = Completer<PremiumPurchaseResult>();
    _pendingRequest = completer;

    _purchaseTimeoutTimer?.cancel();
    _purchaseTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (completer.isCompleted) return;
      _finishRequest(PremiumPurchaseResult.failed);
      isLoading.value = false;
    });

    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        storeStatus.value = PremiumStoreStatus.noStore;
        return _rejectRequest(PremiumPurchaseResult.storeUnavailable);
      }

      await _iap.restorePurchases();
      // The restored purchases arrive through the purchase stream.  An empty
      // list means that the store found nothing, so the request is finished
      // with "failed" (nothing to restore).
      final result = await completer.future;
      return result;
    } catch (e) {
      // The store refused the query - it is usually a missing connection or
      // a Play account that is not signed in.
      return _rejectRequest(PremiumPurchaseResult.offline);
    }
  }

  /// Finishes the waiting request with a failure.
  PremiumPurchaseResult _rejectRequest(PremiumPurchaseResult result) {
    _purchaseTimeoutTimer?.cancel();
    isLoading.value = false;
    _finishRequest(result);
    return result;
  }

  /// Hands the result of the store round trip to the waiting screen.
  void _finishRequest(PremiumPurchaseResult result) {
    final request = _pendingRequest;
    _pendingRequest = null;
    if (request != null && !request.isCompleted) {
      request.complete(result);
    }
    if (request != null && result != PremiumPurchaseResult.unlocked) {
      purchaseError.value = _errorCodeFor(result);
    }
  }

  /// The machine readable code of a failed purchase.
  static String _errorCodeFor(PremiumPurchaseResult result) {
    switch (result) {
      case PremiumPurchaseResult.unlocked:
        return 'unlocked';
      case PremiumPurchaseResult.cancelled:
        return 'cancelled';
      case PremiumPurchaseResult.pending:
        return 'pending';
      case PremiumPurchaseResult.storeUnavailable:
        return 'store_unavailable';
      case PremiumPurchaseResult.offline:
        return 'offline';
      case PremiumPurchaseResult.failed:
        return 'failed';
    }
  }

  /// Acknowledges the purchase with the store.
  ///
  /// A purchase that is not acknowledged is refunded by Google Play after a
  /// few days, so it is always confirmed - even when the candidate cancels
  /// the sheet.
  Future<void> _completePurchase(PurchaseDetails purchaseDetails) async {
    if (!purchaseDetails.pendingCompletePurchase) return;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _iap.completePurchase(purchaseDetails);
        return;
      } catch (_) {
        // Try once more, the purchase must be acknowledged.
      }
    }
  }

  /// Activates the pass and stores it in the local database, so it survives
  /// an app restart.
  Future<void> unlockAllAccessLocally({String? productId}) async {
    if (productId != null) {
      _activeProductId = productId;
      _activeExpiry = DateTime.now().add(
        Duration(days: PassPlan.daysOf(productId)),
      );
      try {
        await DbHelper.instance.setMeta(productMetaKey, productId);
        await DbHelper.instance.setMeta(
          expiryMetaKey,
          _activeExpiry!.toIso8601String(),
        );
      } catch (_) {}
    }
    try {
      await DbHelper.instance.setMeta(unlockMetaKey, '1');
    } catch (_) {
      // The database is not reachable - the pass stays active for this
      // session only.
    }
    isPremiumUnlocked.value = true;
  }

  Future<void> lockAllAccessLocally() async {
    try {
      await DbHelper.instance.setMeta(unlockMetaKey, '0');
      await DbHelper.instance.setMeta(productMetaKey, '');
      await DbHelper.instance.setMeta(expiryMetaKey, '');
    } catch (_) {}
    _activeProductId = null;
    _activeExpiry = null;
    isPremiumUnlocked.value = false;
  }

  /// Debug only: switch between the free and the paid experience.
  ///
  /// The switch is stored under its own key, so a release build never reads
  /// it and a debug session can never unlock a release build.  It does not
  /// touch the store.
  Future<void> setDebugPremiumOverride(bool enabled) async {
    if (!kDebugMode) return;
    try {
      await DbHelper.instance.setMeta(
        debugOverrideMetaKey,
        enabled ? '1' : '0',
      );
    } catch (_) {}
    if (enabled) {
      isPremiumUnlocked.value = true;
      return;
    }
    // The switch is off again: only a real purchase may keep the pass.
    try {
      final savedState = await DbHelper.instance.getMeta(unlockMetaKey);
      isPremiumUnlocked.value = savedState == '1';
    } catch (_) {
      isPremiumUnlocked.value = false;
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    if (purchaseDetailsList.isEmpty) {
      // The store answered a restore query and found nothing.
      _finishRequest(PremiumPurchaseResult.failed);
      return;
    }

    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          // The payment is still being processed by the payment provider.
          isLoading.value = false;
          _finishRequest(PremiumPurchaseResult.pending);
          break;

        case PurchaseStatus.canceled:
          // The candidate backed out - nothing is unlocked.
          await _completePurchase(purchaseDetails);
          isLoading.value = false;
          _finishRequest(PremiumPurchaseResult.cancelled);
          break;

        case PurchaseStatus.error:
          // The store refused the payment - nothing is unlocked.
          await _completePurchase(purchaseDetails);
          isLoading.value = false;
          _finishRequest(PremiumPurchaseResult.failed);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (!_productIds.contains(purchaseDetails.productID)) {
            // A product of another app must never unlock this pass.
            await _completePurchase(purchaseDetails);
            break;
          }
          // The purchase is owned - bought now or restored from the store -
          // so the pass is activated and stored in the local database.
          await _completePurchase(purchaseDetails);
          await unlockAllAccessLocally(productId: purchaseDetails.productID);
          isLoading.value = false;
          _finishRequest(PremiumPurchaseResult.unlocked);
          _purchaseSuccessController.add(true);
          break;
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
    storeStatus.dispose();
  }
}
