import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/design_system/app_typography.dart';

/// The premium look of the exam must not depend on a network connection, so
/// the type system has to use the bundled font families.
void main() {
  group('AppTypography', () {
    test('uses the bundled font families', () {
      expect(AppTypography.displayLarge().fontFamily, 'Outfit');
      expect(AppTypography.titleLarge().fontFamily, 'Outfit');
      expect(AppTypography.titleMedium().fontFamily, 'Outfit');
      expect(AppTypography.numericTimer().fontFamily, 'Outfit');
      expect(AppTypography.questionText().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.optionText().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.passageBody().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.bodyMedium().fontFamily, 'Inter');
      expect(AppTypography.labelSmall().fontFamily, 'Inter');
    });

    test('selects the weight through the variable axis', () {
      final title = AppTypography.titleLarge();
      expect(title.fontVariations, isNotNull);
      expect(
        title.fontVariations!.any((v) => v.axis == 'wght' && v.value == 700),
        isTrue,
      );

      final question = AppTypography.questionText();
      expect(
        question.fontVariations!.any((v) => v.axis == 'wght' && v.value == 500),
        isTrue,
      );
    });

    testWidgets('renders Devanagari without a network', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'निम्नलिखित प्रश्न',
                style: AppTypography.questionText(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('निम्नलिखित प्रश्न'), findsOneWidget);
    });
  });
}
