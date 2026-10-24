/// The pass plan of the app.
///
/// The prices live in the Play Store (the app reads them from the store, so a
/// price can be changed without a new app release).  The values here are only
/// the fallback that is shown when the store cannot be reached.
///
/// The plan has no lifetime pass.  Every pass runs for a fixed term, which
/// keeps the price free to change every season and gives the user a reason
/// to come back.
///
/// | tier          | price  | what it opens                    |
/// |---------------|--------|----------------------------------|
/// | 6-month combo | ₹1,499 | everything, 182 days             |
/// | yearly combo  | ₹2,500 | everything, 365 days             |
///
/// The paywall shows exactly two packs and both are the same combo - UTET
/// AND CTET, every paper of both exams - so the buyer can never pick "the
/// wrong exam" and no pack-vs-pack confusion remains.  The six-month pack
/// anchors the price (₹250 a month); next to it the yearly pack at ₹2,500
/// reads as the gift (~₹498 saved against two six-month passes).  The old
/// exam and single-paper products are no longer sold; an earlier buyer's
/// restored purchase keeps opening exactly what was bought.  Every product
/// id keeps its old name because Play Console ids cannot be renamed, its
/// meaning and its price are decided by
/// the app and the store, not by the id.
class PassPlan {
  const PassPlan._();

  /// The product ids of the Play Console.
  ///
  /// The wall sells exactly two packs and both are the same combo - UTET
  /// AND CTET, every paper of both exams.  Only the term differs, so there
  /// is no pack-vs-pack scatter any more: nobody can buy "the wrong exam".
  static const String fullAccessProductId = 'tet_all_access_1y';
  static const String halfYearProductId = 'tet_all_access_6m';
  static const String utetProductId = 'tet_utet_pass_1y';
  static const String ctetProductId = 'tet_ctet_pass_1y';
  static const String singlePaperProductId = 'tet_single_paper_399';

  /// The ids of the earlier passes.  They keep working while the new
  /// products are being created, so a buyer is never locked out.
  static const String legacyMasterProductId = 'tet_master_all_access_599';
  static const String legacySingleProductId = 'tet_single_paper_299';
  static const String legacyFallbackProductId = 'tet_2026_all_access_pass_99';

  /// Every product the app knows.
  static const List<String> allProductIds = <String>[
    fullAccessProductId,
    halfYearProductId,
    utetProductId,
    ctetProductId,
    singlePaperProductId,
    legacyMasterProductId,
    legacySingleProductId,
    legacyFallbackProductId,
  ];

  /// The price that is shown when the store cannot be reached.
  ///
  /// ₹1,499 anchors the six-month pack, ₹2,500 the yearly one: two
  /// six-month passes cost ₹2,998, so the yearly pack itself reads as a
  /// ₹498 gift.  The store decides the real price, this is only the plan.
  static const Map<String, int> fallbackPrices = <String, int>{
    fullAccessProductId: 2500,
    halfYearProductId: 1499,
    utetProductId: 1499,
    ctetProductId: 1499,
    singlePaperProductId: 999,
    legacyMasterProductId: 599,
    legacySingleProductId: 299,
    legacyFallbackProductId: 99,
  };

  /// How long a pass runs, in days.
  static const Map<String, int> validDays = <String, int>{
    fullAccessProductId: 365,
    halfYearProductId: 182,
    utetProductId: 365,
    ctetProductId: 365,
    singlePaperProductId: 365,
    legacyMasterProductId: 365,
    legacySingleProductId: 60,
    legacyFallbackProductId: 365,
  };

  /// The tier of a product.
  static String tierOf(String productId) {
    switch (productId) {
      case fullAccessProductId:
      case halfYearProductId:
      case legacyMasterProductId:
      case legacyFallbackProductId:
        return 'full';
      case utetProductId:
        return 'utet';
      case ctetProductId:
        return 'ctet';
      default:
        return 'single';
    }
  }

  /// The exam a tier belongs to: 'all', 'utet' or 'ctet'.
  static String examOf(String productId) {
    switch (tierOf(productId)) {
      case 'utet':
        return 'utet';
      case 'ctet':
        return 'ctet';
      default:
        return 'all';
    }
  }

  /// The number of days the pass of a product runs.
  static int daysOf(String productId) => validDays[productId] ?? 365;

  /// The fallback price of a product.
  static int priceOf(String productId) => fallbackPrices[productId] ?? 1499;

  /// The exam a paper belongs to, taken from its form id.
  static String examOfPaper(String formId) {
    final id = formId.toLowerCase();
    if (id.startsWith('ctet')) return 'ctet';
    if (id.startsWith('utet')) return 'utet';
    return 'all';
  }

  /// The paper (p1 or p2) a form belongs to, taken from its form id.
  ///
  /// Every id of the vault follows `utet-p1-…` / `ctet-p2-…`, so the paper
  /// is always readable.  Null for strange ids.
  static String? paperOf(String formId) {
    final id = formId.toLowerCase();
    if (RegExp(r'-p1-').hasMatch(id)) return 'p1';
    if (RegExp(r'-p2-').hasMatch(id)) return 'p2';
    return null;
  }

  /// Does a single pass open this paper?
  ///
  /// The scope is either a full form id (`utet-p1-fullmock`, opens exactly
  /// that paper) or a direction (`utet-p1`, opens every paper of that
  /// direction).  The paywall no longer sells this tier - the one-exam
  /// pack carries both papers, the second as a gift - but an earlier
  /// buyer's restored purchase keeps opening exactly what was bought.
  static bool singleScopeMatches(String? scope, String formId) {
    if (scope == null || scope.isEmpty) return false;
    if (scope == formId) return true;
    final parts = scope.split('-');
    if (parts.length != 2) return false;
    return examOfPaper(formId) == parts[0] && paperOf(formId) == parts[1];
  }

  /// Does a pass open a paper?
  ///
  /// A single paper pass opens only the paper or the direction it was
  /// bought for, an exam pass opens every paper of that exam, and the full
  /// access pass opens everything.
  static bool unlocksPaper(
    String productId,
    String formId, {
    String? singlePaperScope,
  }) {
    final tier = tierOf(productId);
    if (tier == 'single') {
      return singleScopeMatches(singlePaperScope, formId);
    }
    if (tier == 'full') return true;
    return examOfPaper(formId) == examOf(productId);
  }
}
