import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:tet_app/widgets/formatted_question_stem.dart';

void main() {
  group('QuestionContentParser Tests', () {
    test('Correctly parses multi-statement questions with (A), (B), (C)', () {
      const raw =
          'शैक्षिक सुधारों में प्रभावी विकेन्द्रीकरण तभी संभव होगा– (A) जब खंड व संकुल संदर्भ केन्द्रों की भागीदारी बढ़े (B) स्थानीय संदर्भ व्यक्ति उपलब्ध हो (C) अध्यापकों के पास संसाधन और प्रासंगिक सामग्री भी मौजूद हो सही उत्तर चुनें–';

      final parsed = QuestionContentParser.parse(raw);
      expect(parsed, isA<MultiStatementContent>());

      final multi = parsed as MultiStatementContent;
      expect(multi.intro, contains('शैक्षिक सुधारों'));
      expect(multi.statements.length, 3);
      expect(multi.statements[0].marker, '(A)');
      expect(multi.statements[0].text, contains('भागीदारी बढ़े'));
      expect(multi.statements[1].marker, '(B)');
      expect(multi.statements[1].text, contains('स्थानीय संदर्भ व्यक्ति'));
      expect(multi.statements[2].marker, '(C)');
      expect(multi.statements[2].text, contains('अध्यापकों के पास'));
      expect(multi.conclusion, contains('सही उत्तर चुनें'));
    });

    test('Correctly parses Assertion-Reason questions', () {
      const raw =
          'अभिकथन (A) : शिक्षार्थी जो पहले से जानते हैं उसके आधार पर अपने ज्ञान का निर्माण करते हैं। कारण (R) : पैटर्न ढूँढ़ना और पिछले ज्ञान के साथ जुड़ाव बनाने से शिक्षार्थियों को जानकारी को सार्थक रूप से संसाधित करने में मदद मिलती है। सही विकल्प चुनें :';

      final parsed = QuestionContentParser.parse(raw);
      expect(parsed, isA<AssertionReasonContent>());

      final ar = parsed as AssertionReasonContent;
      expect(ar.assertionLabel, contains('अभिकथन'));
      expect(ar.assertionText, contains('शिक्षार्थी जो पहले से जानते हैं'));
      expect(ar.reasonLabel, contains('कारण'));
      expect(ar.reasonText, contains('पैटर्न ढूँढ़ना'));
      expect(ar.conclusion, contains('सही विकल्प चुनें'));
    });

    test('Correctly parses Match-The-Column pairs from flutter_03.png', () {
      const raw =
          'पठन के तरीकों का, पाठक को क्या करना चाहिए, ये मिलान कीजिए ः पठन के तरीके पाठक को क्या करना चाहिए A. अनुमान i. लेखक कैसे लिखते हैं, इसके आधार पर यह सुनिश्चित करना चाहिए कि लेखक क्या महसूस करते हैं। B. निष्कर्ष निकालना ii. अपरिचित शब्दों को समझने के लिए पाठ्य-सामग्री के कुछ हिस्सों से मदद लेनी चाहिए। C. संदर्भ से जोड़कर अर्थ निकालना iii. शीर्ष कथन या प्रस्तावना पर ध्यान देते हुए यह देखना चाहिए कि सूचनाएँ किस तरह से संरचित की गई हैं। D. गहन पठन iv. पाठ्य-पुस्तक में भाषा का किस तरह से प्रयोग किया गया है, इस पर ध्यान केन्द्रित करना चाहिए। E. पाठ्य-वस्तु के संयोजन की पहचान v. पाठ्य-सामग्री किस बारे में है, यह जानने के लिए शीर्षकों और चित्रों का प्रयोग करना चाहिए।';

      final parsed = QuestionContentParser.parse(raw);
      expect(parsed, isA<MatchColumnContent>());

      final match = parsed as MatchColumnContent;
      expect(match.pairs.length, 5);
      expect(match.pairs[0].leftMarker, 'A.');
      expect(match.pairs[0].leftText, 'अनुमान');
      expect(match.pairs[0].rightMarker, 'i.');
      expect(match.pairs[0].rightText, contains('लेखक कैसे लिखते हैं'));

      expect(match.pairs[4].leftMarker, 'E.');
      expect(match.pairs[4].leftText, 'पाठ्य-वस्तु के संयोजन की पहचान');
      expect(match.pairs[4].rightMarker, 'v.');
      expect(match.pairs[4].rightText, contains('शीर्षकों और चित्रों का प्रयोग'));
    });

    test('Correctly parses EVS Column A and Column B matching pairs', () {
      const raw =
          'स्तम्भ A और स्तम्भ B का मिलान कीजिए ः स्तम्भ A स्तम्भ B A. जीरा I. कील की तरह दिखता है B. केसर II. दक्षिणी अमेरिका से उत्पत्ति C. मिर्च III. पीले रंग का D. लौंग IV. छोटा परन्तु खुशबूदार';

      final parsed = QuestionContentParser.parse(raw);
      expect(parsed, isA<MatchColumnContent>());

      final match = parsed as MatchColumnContent;
      expect(match.pairs.length, 4);
      expect(match.pairs[0].leftText, 'जीरा');
      expect(match.pairs[0].rightText, 'कील की तरह दिखता है');
      expect(match.pairs[3].leftText, 'लौंग');
      expect(match.pairs[3].rightText, 'छोटा परन्तु खुशबूदार');
    });

    test('Correctly parses Markdown Tables in questions', () {
      const raw = '''
एक कक्षा में अध्यापक ने निम्न तालिका बनाई जो 40 विद्यार्थियों की आँखों के रंग को दर्शाती है:

|  | नीली आँखें | भूरी आँखें | काली आँखें |
|---|---|---|---|
| लड़के | 5 | 4 | 11 |
| लड़कियाँ | 7 | 3 | 10 |

अध्यापक ने चार विद्यार्थियों को कहा कि वे इस तालिका के बारे में एक-एक कथन श्यामपट्ट पर लिखें।
''';

      final parsed = QuestionContentParser.parse(raw);
      expect(parsed, isA<TableQuestionContent>());

      final table = parsed as TableQuestionContent;
      expect(table.intro, contains('तालिका बनाई'));
      expect(table.headers.length, 4);
      expect(table.headers[1], 'नीली आँखें');
      expect(table.rows.length, 2);
      expect(table.rows[0][0], 'लड़के');
      expect(table.rows[0][1], '5');
      expect(table.rows[1][0], 'लड़कियाँ');
      expect(table.rows[1][3], '10');
      expect(table.postTable, contains('श्यामपट्ट पर लिखें'));
    });

    test('Plain questions with dates in parentheses like (1896-1980) do NOT trigger multi-statement', () {
      const raw = 'जीन पियाजे (1896-1980) के अनुसार संज्ञानात्मक विकास क्या है?';
      final parsed = QuestionContentParser.parse(raw);
      expect(parsed, isA<PlainQuestionContent>());
    });

    test('LaTeX math questions in flutter_04.png are handled as PlainQuestionContent with math', () {
      const raw = r'व्यंजक $ \left[\left(\sqrt{2}\right)^{\sqrt{2}}\right]^{\sqrt{2}}$ क्या है?';
      final parsed = QuestionContentParser.parse(raw);
      expect(parsed, isA<PlainQuestionContent>());
      expect((parsed as PlainQuestionContent).text, contains(r'\sqrt{2}'));
    });
  });

  group('FormattedQuestionStem Widget Rendering Tests', () {
    testWidgets('Renders flutter_04.png math question with Math widget', (tester) async {
      const raw = r'व्यंजक $ \left[\left(\sqrt{2}\right)^{\sqrt{2}}\right]^{\sqrt{2}}$ क्या है?';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedQuestionStem(text: raw, isDark: true),
          ),
        ),
      );

      expect(find.byType(FormattedQuestionStem), findsOneWidget);
      expect(find.byType(Math), findsOneWidget);
      expect(find.textContaining('व्यंजक'), findsOneWidget);
      expect(find.textContaining('क्या है?'), findsOneWidget);
    });

    testWidgets('Renders flutter_03.png Match-The-Column pairs in structured cards', (tester) async {
      const raw =
          'पठन के तरीकों का, पाठक को क्या करना चाहिए, ये मिलान कीजिए ः पठन के तरीके पाठक को क्या करना चाहिए A. अनुमान i. लेखक कैसे लिखते हैं, इसके आधार पर यह सुनिश्चित करना चाहिए कि लेखक क्या महसूस करते हैं। B. निष्कर्ष निकालना ii. अपरिचित शब्दों को समझने के लिए पाठ्य-सामग्री के कुछ हिस्सों से मदद लेनी चाहिए। C. संदर्भ से जोड़कर अर्थ निकालना iii. शीर्ष कथन या प्रस्तावना पर ध्यान देते हुए यह देखना चाहिए कि सूचनाएँ किस तरह से संरचित की गई हैं। D. गहन पठन iv. पाठ्य-पुस्तक में भाषा का किस तरह से प्रयोग किया गया है, इस पर ध्यान केन्द्रित करना चाहिए। E. पाठ्य-वस्तु के संयोजन की पहचान v. पाठ्य-सामग्री किस बारे में है, यह जानने के लिए शीर्षकों और चित्रों का प्रयोग करना चाहिए।';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormattedQuestionStem(text: raw, isDark: false),
            ),
          ),
        ),
      );

      expect(find.text('A.'), findsOneWidget);
      expect(find.text('अनुमान'), findsOneWidget);
      expect(find.text('i.'), findsOneWidget);
      expect(find.text('B.'), findsOneWidget);
      expect(find.text('निष्कर्ष निकालना'), findsOneWidget);
      expect(find.text('ii.'), findsOneWidget);
      expect(find.text('E.'), findsOneWidget);
      expect(find.text('v.'), findsOneWidget);
    });

    testWidgets('Renders Markdown Table widget for tabular question', (tester) async {
      const raw = '''
तालिका:

| वस्तु | मात्रा | मूल्य |
|---|---|---|
| टमाटर | 1 kg | 40 |
| आलू | 2 kg | 50 |
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedQuestionStem(text: raw, isDark: false),
          ),
        ),
      );

      expect(find.byType(Table), findsOneWidget);
      expect(find.text('वस्तु'), findsOneWidget);
      expect(find.text('टमाटर'), findsOneWidget);
      expect(find.text('आलू'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
    });
  });
}
