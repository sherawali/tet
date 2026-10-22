import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/design_system/app_colors.dart';
import 'package:tet_app/widgets/app_badge.dart';

/// A badge has to survive a long label on a small phone.
void main() {
  testWidgets('a long badge label is cut, not pushed out of the screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppBadge(
                label: 'बहुत लंबा बैज लेबल जो कभी फिट नहीं होगा',
                color: AppColors.sealGold,
                icon: Icons.star_rounded,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
