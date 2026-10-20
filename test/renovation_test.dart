import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/models/mock_config.dart';
import 'package:tet_app/models/passage.dart';
import 'package:tet_app/models/question.dart';
import 'package:tet_app/models/test_session.dart';
import 'package:tet_app/services/exam_rules.dart';
import 'package:tet_app/services/html_booklet_builder.dart';
import 'package:tet_app/widgets/question_figure_catalog.dart';

Question _question({
  required String id,
  String section = 'math',
  String? passageId,
  int? seq,
}) {
  return Question(
    id: id,
    exams: '["utet1"]',
    section: section,
    topicIndex: 0,
    topicName: section,
    difficulty: 1,
    qHindi: 'प्रश्न $id',
    optionsHindi: const ['विकल्प A', 'विकल्प B', 'विकल्प C', 'विकल्प D'],
    qEnglish: 'Question $id',
    optionsEnglish: const ['Option A', 'Option B', 'Option C', 'Option D'],
    answer: 1,
    pScore: 1,
    passageId: passageId,
    seqInPassage: seq,
  );
}

TestSession _session({
  required List<Question> questions,
  int timeLimitMinutes = 150,
  Map<String, Passage> passages = const {},
}) {
  return TestSession(
    id: 'test-session',
    config: MockConfig(
      mode: MockMode.pyq,
      exam: 'utet1',
      totalQuestions: questions.length,
      timeLimitMinutes: timeLimitMinutes,
      seed: 42,
    ),
    questions: questions,
    passages: passages,
    selectedAnswers: {0: 1},
    markedForReview: {1},
    visitedIndices: {0, 1},
    elapsedSeconds: 125,
    startTime: DateTime(2026, 10, 20, 10),
    paperTitle: 'टेस्ट पेपर',
    setCode: 'A',
  );
}

void main() {
  group('ExamRules', () {
    test('uses official 60% and 55% cut-offs without rounding up', () {
      expect(ExamRules.generalPassMark(150), 90);
      expect(ExamRules.reservedPassMark(150), 82);
      expect(ExamRules.generalPassMark(30), 18);
      expect(ExamRules.reservedPassMark(30), 16);
      expect(ExamRules.isGeneralPass(90, 150), isTrue);
      expect(ExamRules.isGeneralPass(89, 150), isFalse);
    });

    test('formats wall-clock durations', () {
      expect(ExamRules.formatClock(9000), '02:30:00');
      expect(ExamRules.formatClock(-5), '00:00:00');
      expect(ExamRules.formatMinutes(30), '30 मिनट');
      expect(ExamRules.formatMinutes(150), '2 घण्टे 30 मिनट');
    });
  });

  group('TestSession persistence', () {
    test('round-trips questions, passages, answers and timer metadata', () {
      final passage = const Passage(
        id: 'p1',
        kind: 'prose',
        dirText: 'Read the passage.',
        body: 'A clean passage body.',
      );
      final original = _session(
        questions: [_question(id: 'q1', passageId: 'p1', seq: 1)],
        passages: {'p1': passage},
      );

      final restored = TestSession.decode(original.encode());

      expect(restored.id, original.id);
      expect(restored.questions.length, 1);
      expect(restored.questions.first.id, 'q1');
      expect(restored.questions.first.passageId, 'p1');
      expect(restored.passages['p1']?.body, contains('clean passage'));
      expect(restored.selectedAnswers, {0: 1});
      expect(restored.markedForReview, {1});
      expect(restored.config.timeLimitMinutes, 150);
      expect(restored.elapsedSeconds, 125);
    });

    test('remaining time is based on the wall clock', () {
      final session = _session(
        questions: [_question(id: 'q1')],
        timeLimitMinutes: 150,
      );
      final now = session.startTime.add(const Duration(minutes: 10));
      expect(session.remainingSecondsAt(now), 140 * 60);
      final expired = session.startTime.add(const Duration(hours: 4));
      expect(session.remainingSecondsAt(expired), 0);
    });
  });

  group('Figure catalog', () {
    test('provides both Flutter and HTML renderings for repaired figures', () {
      expect(
        QuestionFigureCatalog.hasQuestionFigure('42585dbbc302b422'),
        isTrue,
      );
      expect(
        QuestionFigureCatalog.questionSvg('42585dbbc302b422'),
        contains('50°'),
      );
      expect(
        QuestionFigureCatalog.optionSvg('ctet-p1-2018-pyq_q056', 1),
        contains('Net B'),
      );
      expect(
        QuestionFigureCatalog.optionSvg('ctet-p1-2018-pyq_q058', 0),
        contains('Shape A'),
      );
    });
  });

  group('HTML booklet', () {
    test('derives section banners and language labels from loaded questions', () {
      final session = _session(
        questions: [
          _question(id: 'q1', section: 'hindi_2'),
          _question(id: 'q2', section: 'english_1'),
        ],
        timeLimitMinutes: 30,
      );
      final html = HtmlBookletBuilder.buildHtml(session);

      expect(html, contains('भाग I : भाषा द्वितीय – हिन्दी'));
      expect(html, contains('भाग II : भाषा प्रथम – अंग्रेज़ी'));
      expect(html, contains('समय : 30 मिनट'));
      expect(html, contains(ExamRules.formatClock(30 * 60 - 125)));
      expect(html, isNot(contains('2 घण्टे 30 मिनट')));
      expect(html, contains('startTimer();'));
      expect(html, isNot(contains('__INITIAL_REMAINING__')));
      expect(html, isNot(contains('__TIME_LIMIT__')));
      expect(
        html,
        contains('const GENERAL_PASS = ${ExamRules.generalPassMark(2)};'),
      );
      expect(
        html,
        contains('const RESERVED_PASS = ${ExamRules.reservedPassMark(2)};'),
      );
    });

    test('embeds reconstructed question and option figures', () {
      final session = _session(
        questions: [
          Question(
            id: 'ctet-p1-2018-pyq_q056',
            exams: '["ctet1"]',
            section: 'math',
            topicIndex: 0,
            topicName: 'math',
            difficulty: 2,
            qHindi: 'दिए गए ठोस को किसको मोड़कर बनाया जा सकता है?',
            optionsHindi: const ['चित्र A', 'चित्र B', 'चित्र C', 'चित्र D'],
            answer: 1,
            pScore: 0,
          ),
        ],
      );

      final html = HtmlBookletBuilder.buildHtml(session);
      expect(html, contains('class="q-figure"'));
      expect(html, contains('class="opt-figure"'));
      expect(html, contains('Net B'));
      expect(html, isNot(contains('FIGURE NOT AVAILABLE')));
    });
  });
}
