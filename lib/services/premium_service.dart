import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../database/db_helper.dart';
import '../design_system/app_motion.dart';
import 'bank_facts.dart';
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

  // Exactly ONE designated free flagship mock per exam.  Both exams carry
  // their own, so the candidate of either exam always sees exactly one
  // free paper - never the whole paper list, and never a Paper-2 second
  // free one.  The remote config (free_form_ids) can override this list
  // from Git without an app release.
  static const Set<String> defaultFreePaperIds = {
    'utet-p1-fullmock',    // UTET Paper 1 Flagship (official board 2023)
    'ctet-p1-2026-pyq',    // CTET Paper 1 Flagship (2026 board solved)
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

  // Lazy: touching InAppPurchase.instance registers the platform plugin,
  // so the getter keeps a desktop test runner without the store alive.
  // A real session always ends up touching it once, in init().
  InAppPurchase? _iapInstance;
  InAppPurchase get _iap => _iapInstance ??= InAppPurchase.instance;
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

  /// The paper a single paper pass was bought for (a direction like
  /// `utet-p1` or a whole form id).  Persisted, so it survives a restart.
  String? _singlePaperScope;

  /// The product of the single paper pass lives under its own meta key,
  /// because it is the only scope the store does not carry.
  static const String singleScopeMetaKey = 'is_premium_single_scope';

  /// The product a pending single purchase belongs to (the scope is chosen
  /// in the paywall money a moment before the buy button is pressed and
  /// handed to the purchase stream later).
  String? _pendingSingleScope;

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
    // The fallback is formatted with the thousands separator too, so a
    // 2,499 never prints as "2499" while the store is away.
    return '₹${BankFacts.format(PassPlan.priceOf(productId))}';
  }

  /// Does the app know this product?
  bool isKnownProduct(String productId) => _productIds.contains(productId);

  /// Check if a specific paper form or index is Free
  ///
  /// The pass of the candidate decides: a UTET pass opens the UTET papers
  /// only, a CTET pass the CTET papers only and the full access pass
  /// everything.  A pass that has run out opens nothing.
  bool isPaperFree({String? formId, int index = 0, String? exam}) {
    if (remoteAllMocksFree) return true;

    final passValid = isPremiumUnlocked.value && _passIsValid;
    final tier = PassPlan.tierOf(_activeProductId ?? '');

    if (formId != null) {
      // The pass of the candidate decides per paper.
      final productId = _activeProductId;
      if (productId != null && _passIsValid) {
        if (PassPlan.unlocksPaper(
          productId,
          formId,
          singlePaperScope: _singlePaperScope,
        )) {
          return true;
        }
      }
      // The free papers are free for everybody, also with a pass.
      if (remoteFreeFormIds.contains(formId)) return true;
      if (defaultFreePaperIds.contains(formId)) return true;
      if (remotePaidFormIds.contains(formId)) return false;
      // Unknown paper: only a full pass opens it; an exam pass opens its
      // own exam (the id prefix tells), a single paper pass never.
      if (passValid && tier == 'full') return true;
      // A named paper that no free list carries is never free because of
      // its position in a list - the flagship papers are the only free
      // mocks.  The position fallback below belongs to the subject
      // drills (the set-1 rule) alone.
      return false;
    } else if (passValid && tier != 'single') {
      // Without a paper id (the sets and drills) the caller names the exam
      // the content belongs to, so an exam pass opens only its own exam's
      // sets - ₹999 buys one direction, an exam pass one exam, never the
      // other exam's content.
      final passExam = PassPlan.examOf(_activeProductId ?? '');
      if (tier == 'full' || exam == null) return true;
      final base = exam.toLowerCase();
      return passExam == (base.startsWith('utet') ? 'utet' : 'ctet');
    }

    return index == 0;
  }

  /// Is the pass still running?
  bool get _passIsValid {
    final expiry = _activeExpiry;
    if (expiry == null) return true;
    return expiry.isAfter(DateTime.now());
  }

  /// Does a full pass (single, exam or full) still run?
  ///
  /// The screens use this getter as the gate instead of reading
  /// `isPremiumUnlocked` directly, so a pass that runs out while the app is
  /// open locks the screens at once, and the caller of a single paper pass
  /// (which opens only its direction) is treated as not fully unlocked.
  bool get hasUnlockedAccess =>
      isPremiumUnlocked.value &&
      _passIsValid &&
      PassPlan.tierOf(_activeProductId ?? '') != 'single';

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
    //    In a release build the reconciliation runs even when the local
    //    state says unlocked: if the store no longer returns the pass
    //    (a refunded or cancelled purchase, a Play account switch), the
    //    local lock is taken off, so the validity can never drift away
    //    from the store.  A debug build keeps its mock entitlement.
    if (kDebugMode) {
      if (!isPremiumUnlocked.value) {
        unawaited(_reconcileWithStoreInBackground());
      }
    } else {
      unawaited(_reconcileWithStoreInBackground());
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
        final scope = await DbHelper.instance.getMeta(singleScopeMetaKey);
        _singlePaperScope =
            (scope != null && scope.isNotEmpty) ? scope : null;
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

  /// Asks the store for the purchases of this app.
  ///
  /// Two jobs, both honest:
  /// 1. A purchase that is already owned arrives as a "restored" purchase
  ///    and unlocks the pass (a reinstall, a new device, a fresh start).
  /// 2. A pass the locally stored state still claims but the store no
  ///    longer returns is locked again - the store is the single truth,
  ///    so a refunded or cancelled purchase never keeps papers open.
  Future<void> _reconcileWithStoreInBackground() async {
    if (storeStatus.value != PremiumStoreStatus.available) return;
    _storeSawOwnedPurchase = false;
    try {
      await _iap.restorePurchases();
      // The restore answers through the purchase stream.  An empty answer
      // with a locally unlocked state means the entitlement is gone at
      // Play - lock the papers back.
      if (isPremiumUnlocked.value &&
          _passIsValid &&
          !_storeSawOwnedPurchase) {
        await lockAllAccessLocally();
      }
    } catch (_) {
      // The store could not be reached - the app keeps the locally stored
      // state and the next start reconciles again.
    }
  }

  /// Whether the purchase stream reported an owned product of this app
  /// during the last restore.  The store reconciliation reads it.
  bool _storeSawOwnedPurchase = false;

  /// Re-reads the stored entitlement from the database.
  ///
  /// The tests use it to replay a fresh start of the app (restart, update,
  /// reinstall); a session may also call it to notice a pass that ran out
  /// while the app stayed open.
  Future<void> reloadFromDatabase() async {
    await _restoreLocalState();
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
  /// one.  Nothing is unlocked unless the store confirmed a purchase.  A
  /// single paper purchase carries the direction it was bought for, because
  /// the store only knows the product id.
  Future<PremiumPurchaseResult> buyProduct(
    String productId, {
    String? singlePaperScope,
  }) async {
    // A debug build cannot talk to Play Billing (a release install is
    // needed for that), so the tester presses the same buy button and the
    // mock buy runs the very same unlock code a real purchase would run.
    if (kDebugMode) {
      return mockBuyForDebug(productId, singlePaperScope: singlePaperScope);
    }

    if (isPremiumUnlocked.value && _passIsValid) {
      return PremiumPurchaseResult.unlocked;
    }

    isLoading.value = true;
    purchaseError.value = null;

    // The scope of a single paper purchase rides on the service, because it
    // arrives in the purchase stream a moment later without any context.
    _pendingSingleScope =
        PassPlan.tierOf(productId) == 'single' ? singlePaperScope : null;

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
    if (isPremiumUnlocked.value && _passIsValid) {
      return PremiumPurchaseResult.unlocked;
    }

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
      // A failed (not pending) round trip drops the scope it was holding,
      // otherwise an aborted single-paper intent could leak into a later
      // restore of an older purchase.
      if (result != PremiumPurchaseResult.pending) {
        _pendingSingleScope = null;
      }
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
  ///
  /// [forceReplace] is a fresh payment's word: a bought pass always starts
  /// its term now and its product replaces an older one (an upgrade from a
  /// single paper to an exam pass, a leap from the 6-month pack to the
  /// yearly one).  A store re-delivery of an owned purchase
  /// (restore, restart, reconciliation) must stay quiet: it can never
  /// stretch the expiry and never relabel a longer pass with a shorter one.
  Future<void> unlockAllAccessLocally({
    String? productId,
    String? singlePaperScope,
    bool forceReplace = false,
  }) async {
    if (productId != null) {
      final newExpiry = DateTime.now().add(
        Duration(days: PassPlan.daysOf(productId)),
      );
      // A pass never stretches AND never shrinks, and the stored product
      // id always belongs to the expiry that is kept.  The store
      // re-delivers every owned purchase on every start - if a buyer owns
      // the yearly pack and the store later hands over the six-month one
      // too, the six-month delivery must not relabel the pass while the
      // yearly expiry stays.  Only a genuine renewal (a delivery at least
      // a day beyond the stored expiry) or a fresh payment moves the date
      // and the product together; anything else keeps the longer
      // entitlement.
      final isRealRenewal = forceReplace ||
          _activeExpiry == null ||
          newExpiry.isAfter(
            _activeExpiry!.add(const Duration(days: 1)),
          );
      if (isRealRenewal) {
        _activeProductId = productId;
        _activeExpiry = newExpiry;
        try {
          await DbHelper.instance.setMeta(productMetaKey, productId);
          await DbHelper.instance.setMeta(
            expiryMetaKey,
            _activeExpiry!.toIso8601String(),
          );
        } catch (_) {}
      }
      // The scope only matters while the pass is a single paper pass; any
      // wider pass (one exam or everything) swallows the scope again, so a
      // later upgrade never leaves a stale single direction behind.
      if (PassPlan.tierOf(productId) == 'single') {
        _singlePaperScope = singlePaperScope ?? _singlePaperScope;
        try {
          await DbHelper.instance.setMeta(
            singleScopeMetaKey,
            _singlePaperScope ?? '',
          );
        } catch (_) {}
      } else {
        _singlePaperScope = null;
        try {
          await DbHelper.instance.setMeta(singleScopeMetaKey, '');
        } catch (_) {}
      }
    } else if (singlePaperScope != null) {
      _singlePaperScope = singlePaperScope;
      try {
        await DbHelper.instance.setMeta(singleScopeMetaKey, singlePaperScope);
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
    _singlePaperScope = null;
    try {
      await DbHelper.instance.setMeta(singleScopeMetaKey, '');
    } catch (_) {}
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
    // The switch decides what the tester sees right now, in this session:
    // ON = the paid app (full access pass), OFF = the free app.  The real
    // entitlement stays untouched in the database and comes back on the
    // next start of the app.
    if (enabled) {
      _activeProductId = PassPlan.fullAccessProductId;
      _activeExpiry = null;
      isPremiumUnlocked.value = true;
      return;
    }
    _activeProductId = null;
    _activeExpiry = null;
    isPremiumUnlocked.value = false;
  }

  /// Debug only: a mock buy that unlocks the chosen pack without the store.
  ///
  /// Play Billing cannot run in a debug build, so the tester buys through
  /// this door instead - and it writes exactly what a real purchase would
  /// write: the product, the absolute expiry of 365 days, the direction
  /// scope and the unlock flag, all in the database.  A restart keeps it,
  /// the expiry test rules apply, the packed papers open and nothing else.
  Future<PremiumPurchaseResult> mockBuyForDebug(
    String productId, {
    String? singlePaperScope,
  }) async {
    if (!kDebugMode) return PremiumPurchaseResult.failed;
    // A direction choice without a scope must fail loudly, the way a
    // store buys nothing without a product.
    if (PassPlan.tierOf(productId) == 'single' &&
        (singlePaperScope == null || singlePaperScope.isEmpty)) {
      purchaseError.value = 'failed';
      return PremiumPurchaseResult.failed;
    }
    if (isPremiumUnlocked.value) return PremiumPurchaseResult.unlocked;

    isLoading.value = true;
    purchaseError.value = null;
    // A moment of the same working state the Play sheet gives, so the
    // tester sees the loader of the real flow too.
    await Future<void>.delayed(AppMotion.mockBuyLoader);
    await unlockAllAccessLocally(
      productId: productId,
      singlePaperScope: singlePaperScope,
      forceReplace: true,
    );
    isLoading.value = false;
    _purchaseSuccessController.add(true);
    return PremiumPurchaseResult.unlocked;
  }

  /// Debug only: clears every trace of a pass, so another pack can be
  /// tried from a clean state.
  Future<void> resetPurchasesForTesting() async {
    if (!kDebugMode) return;
    await setDebugPremiumOverride(false);
    await lockAllAccessLocally();
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
          _pendingSingleScope = null;
          isLoading.value = false;
          _finishRequest(PremiumPurchaseResult.pending);
          break;

        case PurchaseStatus.canceled:
          // The candidate backed out - nothing is unlocked.
          _pendingSingleScope = null;
          await _completePurchase(purchaseDetails);
          isLoading.value = false;
          _finishRequest(PremiumPurchaseResult.cancelled);
          break;

        case PurchaseStatus.error:
          // The store refused the payment - nothing is unlocked.
          _pendingSingleScope = null;
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
          // The store itself sang the pass is owned - the reconciliation
          // reads this flag at the next start.
          _storeSawOwnedPurchase = true;
          // The purchase is owned - bought now or restored from the store -
          // so the pass is activated and stored in the local database.
          // A fresh payment always starts its term now (and may upgrade
          // the product); a restore only fills a gap, it never stretches
          // a longer pass or relabels it with a shorter product.
          await _completePurchase(purchaseDetails);
          await unlockAllAccessLocally(
            productId: purchaseDetails.productID,
            singlePaperScope: _pendingSingleScope,
            forceReplace:
                purchaseDetails.status == PurchaseStatus.purchased,
          );
          _pendingSingleScope = null;
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

