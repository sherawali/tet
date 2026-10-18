import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/models/mock_config.dart';
import 'package:tet_app/models/passage.dart';
import 'package:tet_app/models/question.dart';
import 'package:tet_app/models/test_session.dart';
import 'package:tet_app/services/html_booklet_builder.dart';

void main() {
  group('HtmlBookletBuilder Tests', () {
    test('buildHtml creates authentic HTML with cover, bilingual grid and passages', () {
      final questions = List.generate(
        150,
        (i) => Question(
          id: 'test-q-${i + 1}',
          exams: 'utet1',
          section: i < 30 ? 'cdp' : (i < 60 ? 'hindi' : (i < 90 ? 'english' : (i < 120 ? 'math' : 'evs'))),
          topicIndex: 1,
          topicName: 'समावेशी शिक्षा',
          difficulty: 1,
          qHindi: 'प्रश्न ${i + 1} का हिन्दी कथन क्या है?',
          optionsHindi: ['विकल्प 1', 'विकल्प 2', 'विकल्प 3', 'विकल्प 4'],
          qEnglish: 'What is question ${i + 1} statement?',
          optionsEnglish: ['Option A', 'Option B', 'Option C', 'Option D'],
          answer: i % 4,
          pScore: 0.95,
          passageId: (i >= 30 && i <= 34) ? 'passage-p1' : null,
        ),
      );

      final passages = {
        'passage-p1': const Passage(
          id: 'passage-p1',
          kind: 'poem',
          dirText: 'दी गई कविता को पढ़कर प्रश्नों के उत्तर दीजिए।',
          body: 'माना आज मशीनी युग में समय बहुत महंगा है\nलेकिन तुम थोड़ा अवकाश निकालो तुमसे दो बातें करनी हैं।',
        ),
      };

      final session = TestSession(
        id: 'mock_session_101',
        config: const MockConfig(
          mode: MockMode.predicted,
          seed: 20260929,
          totalQuestions: 150,
        ),
        questions: questions,
        passages: passages,
      );

      final html = HtmlBookletBuilder.buildHtml(session);

      // Verify essential components
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('उत्तराखंड विद्यालयी शिक्षा परिषद्'));
      expect(html, contains('अनुक्रमांक (Roll No.)'));
      expect(html, contains('SET CODE'));
      expect(html, contains('02:30:00')); // timer
      expect(html, contains('qitem-1'));
      expect(html, contains('qitem-150'));
      expect(html, contains('q-grid-bilingual'));
      expect(html, contains('stimulus-passage-p1'));
      expect(html, contains('poem-body'));
      expect(html, contains('माना आज मशीनी युग में'));
      expect(html, contains('omr-modal'));
      expect(html, contains('confirm-modal'));
      expect(html, contains('result-modal'));
      expect(html, contains('BookletChannel'));
      expect(html, contains('cbt-bar'));
      expect(html, contains('palette-drawer'));
      expect(html, contains('jumpToQuestion'));
      expect(html, contains('requestExitTest'));
    });

    test('formatQuestionStemHtml properly formats Assertion-Reason into structured cards', () {
      const rawStem = '**अभिकथन (A):** विद्यालय में अधिगम बच्चों के सामाजिक संदर्भों से निर्लिप्त होना चाहिए।\n\n**कारण (R):** विद्यालय में प्रवेश से पहले ही छात्रों के पास सुपरिभाषित समझ होती है।\n\nदिए गए विकल्पों में से उपयुक्त विकल्प चुनिए :';
      final html = HtmlBookletBuilder.formatQuestionStemHtml(rawStem);

      expect(html, contains('kathan-wrapper'));
      expect(html, contains('assertion-box'));
      expect(html, contains('reason-box'));
      expect(html, contains('tag-a'));
      expect(html, contains('tag-r'));
      expect(html, contains('kathan-conclusion'));
      expect(html, contains('विद्यालय में अधिगम'));
      expect(html, contains('विद्यालय में प्रवेश से पहले'));
      // Raw asterisks must not be present
      expect(html, isNot(contains('**अभिकथन')));
      expect(html, isNot(contains('**कारण')));
    });

    test('formatQuestionStemHtml strips leaked Q-number prefixes', () {
      const rawStem = '**Q114.** Which one of the following is the primary purpose of language learning?';
      final html = HtmlBookletBuilder.formatQuestionStemHtml(rawStem);

      expect(html, isNot(contains('Q114')));
      expect(html, isNot(contains('**Q114.**')));
      expect(html, contains('Which one of the following is the primary purpose'));
    });

    test('formatQuestionStemHtml structures Multi-Statement questions', () {
      const rawStem = 'निम्नलिखित कथनों पर विचार कीजिए :\n(A) यह बच्चे को सृजनात्मक बनाता है।\n(B) यह कल्पना को पोषित करता है।\n(C) यह तर्क पर आधारित है।\nसही कूट चुनिए :';
      final html = HtmlBookletBuilder.formatQuestionStemHtml(rawStem);

      expect(html, contains('multi-statement-wrapper'));
      expect(html, contains('stmt-list'));
      expect(html, contains('stmt-row'));
      expect(html, contains('(A)'));
      expect(html, contains('(B)'));
      expect(html, contains('(C)'));
      expect(html, contains('सही कूट चुनिए'));
    });
  });
}
