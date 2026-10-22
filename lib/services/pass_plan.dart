/// The pass plan of the app.
///
/// The prices live in the Play Store (the app reads them from the store, so a
/// price can be changed without a new app release).  The values here are only
/// the fallback that is shown when the store cannot be reached.
///
/// The plan has no lifetime pass.  Every pass runs for one year, which keeps
/// the price free to change every season and gives the user a reason to come
/// back.
///
/// | tier          | price  | what it opens                    |
/// |---------------|--------|----------------------------------|
/// | single paper  | ₹399   | one paper, 60 days               |
/// | utet pass     | ₹1,499 | every UTET paper, 365 days       |
/// | ctet pass     | ₹1,499 | every CTET paper, 365 days       |
/// | full access   | ₹2,499 | everything, 365 days             |
class PassPlan {
  const PassPlan._();

  /// The product ids of the Play Console.
  static const String fullAccessProductId = 'tet_all_access_1y';
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
    utetProductId,
    ctetProductId,
    singlePaperProductId,
    legacyMasterProductId,
    legacySingleProductId,
    legacyFallbackProductId,
  ];

  /// The price that is shown when the store cannot be reached.
  static const Map<String, int> fallbackPrices = <String, int>{
    fullAccessProductId: 2499,
    utetProductId: 1499,
    ctetProductId: 1499,
    singlePaperProductId: 399,
    legacyMasterProductId: 599,
    legacySingleProductId: 299,
    legacyFallbackProductId: 99,
  };

  /// How long a pass runs, in days.
  static const Map<String, int> validDays = <String, int>{
    fullAccessProductId: 365,
    utetProductId: 365,
    ctetProductId: 365,
    singlePaperProductId: 60,
    legacyMasterProductId: 365,
    legacySingleProductId: 60,
    legacyFallbackProductId: 365,
  };

  /// The tier of a product.
  static String tierOf(String productId) {
    switch (productId) {
      case fullAccessProductId:
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

  /// Does a pass open a paper?
  ///
  /// A single paper pass opens only the paper it was bought for, an exam pass
  /// opens every paper of that exam, and the full access pass opens
  /// everything.
  static bool unlocksPaper(
    String productId,
    String formId, {
    String? singlePaperFormId,
  }) {
    final tier = tierOf(productId);
    if (tier == 'single') {
      return singlePaperFormId != null && singlePaperFormId == formId;
    }
    if (tier == 'full') return true;
    return examOfPaper(formId) == examOf(productId);
  }
}
