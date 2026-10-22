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
}
