import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/design_system/app_typography.dart';

/// The premium look of the exam must not depend on a network connection, so
/// the type system has to use the bundled font families.
///
/// The chrome styles are language aware: the default test language is Hindi,
/// so the headless styles must carry the Devanagari face directly (the
/// variable axis of the primary family keeps the weight).
void main() {
  group('AppTypography', () {
    test('uses the bundled font families of the active language', () {
      // The default test environment runs in the Hindi mode.
      expect(AppTypography.displayLarge().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.titleLarge().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.titleMedium().fontFamily, 'Noto Sans Devanagari');
      // Numerals stay on Outfit - they are read the same in both languages.
      expect(AppTypography.numericTimer().fontFamily, 'Outfit');
      expect(AppTypography.questionText().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.optionText().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.passageBody().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.bodyMedium().fontFamily, 'Noto Sans Devanagari');
      expect(AppTypography.labelSmall().fontFamily, 'Noto Sans Devanagari');
    });

    test('print the weights explicitly and through the variable axis', () {
      final title = AppTypography.titleLarge();
      expect(title.fontVariations, isNotNull);
      expect(
        title.fontVariations!.any((v) => v.axis == 'wght' && v.value == 700),
        isTrue,
      );
      // An explicit FontWeight holds the premium weight even on faces
      // without a variable axis (the fallback path on Android).
      expect(title.fontWeight, FontWeight.w700);

      final question = AppTypography.questionText();
      expect(
        question.fontVariations!.any((v) => v.axis == 'wght' && v.value == 500),
        isTrue,
      );
    });

    test('devanagari text is never letter-spaced or tracked', () {
      expect(AppTypography.titleLarge().letterSpacing, 0);
      expect(AppTypography.labelSmall().letterSpacing, 0);
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
