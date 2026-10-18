import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:tet_app/widgets/smart_math_text.dart';

void main() {
  testWidgets('SmartMathText renders mixed Hindi text and math correctly', (tester) async {
    const raw = r'व्यंजक $ \left[\left(\sqrt{2}\right)^{\sqrt{2}}\right]^{\sqrt{2}}$ क्या है?';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartMathText(raw),
        ),
      ),
    );

    expect(find.byType(SmartMathText), findsOneWidget);
    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining('व्यंजक'), findsOneWidget);
    expect(find.textContaining('क्या है?'), findsOneWidget);
  });

  testWidgets('SmartMathText renders pure text with normal Text widget fast path', (tester) async {
    const plain = 'धन पूर्णांक है';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartMathText(plain),
        ),
      ),
    );

    expect(find.text('धन पूर्णांक है'), findsOneWidget);
    expect(find.byType(Math), findsNothing);
  });

  testWidgets('SmartMathText renders fraction math expression correctly', (tester) async {
    const frac = r'$\dfrac{(2.3)^3 - 0.027}{(2.3)^2 + 0.69 + 0.09}$ का मान क्या है?';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartMathText(frac),
        ),
      ),
    );

    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining('का मान क्या है?'), findsOneWidget);
  });
}
