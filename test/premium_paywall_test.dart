import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/widgets/premium_paywall_modal.dart';

/// The payment sheet has to fit on a small phone.
///
/// The tier card once squeezed a long title into one letter per line and
/// pushed the price out of the card, so the sheet is checked on the narrowest
/// common width.
void main() {
  testWidgets('the payment sheet fits on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PremiumPaywallModal()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the payment sheet fits on a very narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PremiumPaywallModal()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
