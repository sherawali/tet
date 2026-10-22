import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tet_app/database/db_helper.dart';
import 'package:tet_app/services/pass_plan.dart';
import 'package:tet_app/services/premium_service.dart';

/// The meta keys of the entitlement, spelled in one place.
const String _expiryKey = 'is_premium_expires_at';
const String _unlockKey = 'is_premium_unlocked';

void main() {
  // The helper runs plain sqlite on the desktop test runner.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // PremiumService stores its state through DbHelper; the test factory
    // keeps every write inside a temp file on the host.
    await DbHelper.instance.database;
  });

  test('a re-delivered purchase never stretches the expiry', () async {
    final service = PremiumService.instance;

    // First unlock: today + the term of the full pass.
    await service.unlockAllAccessLocally(
      productId: PassPlan.fullAccessProductId,
    );
    final firstExpiry = await DbHelper.instance.getMeta(_expiryKey);
    expect(firstExpiry, isNotNull);

    // The store re-delivers the same owned purchase on the next start.
    // The expiry must not move - an active pass ages normally.
    await service.unlockAllAccessLocally(
      productId: PassPlan.fullAccessProductId,
    );
    final secondExpiry = await DbHelper.instance.getMeta(_expiryKey);
    expect(secondExpiry, firstExpiry);

    // Locking clears everything, so a later buyer starts from nothing.
    await service.lockAllAccessLocally();
    final lockedState = await DbHelper.instance.getMeta(_unlockKey);
    expect(lockedState, '0');
  });

  test('a single paper pass opens only its direction', () async {
    final service = PremiumService.instance;

    // ₹399 buyer picks "CTET Paper-2".
    await service.unlockAllAccessLocally(
      productId: PassPlan.singlePaperProductId,
      singlePaperScope: 'ctet-p2',
    );
    expect(service.isPaperFree(formId: 'ctet-p2-ms-mock-02'), isTrue);
    expect(service.isPaperFree(formId: 'ctet-p2-sst-mock-07'), isTrue);

    // The rest of the vault stays behind the paywall (index 5, so the free
    // first-paper sample rule does not color the check; the flagship papers
    // stay free for everyone by design).
    expect(service.isPaperFree(formId: 'ctet-p1-mock-05', index: 5), isFalse);
    expect(service.isPaperFree(formId: 'utet-p1-mock-09', index: 5), isFalse);
    expect(service.isPaperFree(formId: 'utet-p2-set-d', index: 5), isFalse);
    // And the flagship free papers remain free as always.
    expect(service.isPaperFree(formId: 'utet-p2-set-b', index: 5), isTrue);

    // The direction also opens nothing for other papers of other exams.
    expect(
      PremiumService.instance.hasUnlockedAccess,
      isFalse,
      reason: 'subject drills are exam-wide, single paper pass never gets them',
    );

    // An upgrade to the exam pass swallows the scope.
    await service.unlockAllAccessLocally(productId: PassPlan.ctetProductId);
    expect(service.isPaperFree(formId: 'ctet-p1-mock-05', index: 5), isTrue);
    expect(service.isPaperFree(formId: 'utet-p1-mock-09', index: 5), isFalse);

    await service.lockAllAccessLocally();
  });

  test('the pass survives a restart, an update and runs out honestly', () async {
    final service = PremiumService.instance;

    // Buy: the expiry lands a year ahead and the scope is stored.
    // (The one-direction choice runs for the same 365 days as every pack.)
    await service.unlockAllAccessLocally(
      productId: PassPlan.singlePaperProductId,
      singlePaperScope: 'utet-p1',
    );
    expect(service.activePassDaysLeft, inInclusiveRange(364, 365));

    // Replay of a fresh start (restart / update / reinstall).
    await service.reloadFromDatabase();
    expect(service.isPaperFree(formId: 'utet-p1-mock-05'), isTrue);
    expect(service.isPaperFree(formId: 'ctet-p2-ms-mock-05', index: 5), isFalse);
    expect(service.activePassDaysLeft, inInclusiveRange(364, 365));

    // The store re-delivers the same single purchase: nothing moves.
    final expiryBefore = await DbHelper.instance.getMeta(_expiryKey);
    await service.unlockAllAccessLocally(
      productId: PassPlan.singlePaperProductId,
      singlePaperScope: 'utet-p1',
    );
    expect(await DbHelper.instance.getMeta(_expiryKey), expiryBefore);

    // The last day still shows one day and still opens the direction.
    final lastDay = DateTime.now().add(const Duration(hours: 2));
    await DbHelper.instance.setMeta(_expiryKey, lastDay.toIso8601String());
    await service.reloadFromDatabase();
    expect(service.activePassDaysLeft, 1);
    expect(service.isPaperFree(formId: 'utet-p1-mock-05'), isTrue);
    expect(service.isPaperFree(formId: 'ctet-p2-ms-mock-05', index: 5), isFalse);

    // The day after the expiry everything is locked again.
    final yesterday = DateTime.now().subtract(const Duration(hours: 2));
    await DbHelper.instance.setMeta(_expiryKey, yesterday.toIso8601String());
    await service.reloadFromDatabase();
    expect(service.isPremiumUnlocked.value, isFalse);
    expect(service.isPaperFree(formId: 'utet-p1-mock-05', index: 5), isFalse);
    expect(service.hasUnlockedAccess, isFalse);

    // And the scope is gone with the pass.
    final scope = await DbHelper.instance.getMeta('is_premium_single_scope');
    expect(scope ?? '', '');
  });
}
