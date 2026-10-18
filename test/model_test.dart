import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/models/question.dart';
import 'package:tet_app/models/passage.dart';
import 'package:tet_app/models/mock_config.dart';
import 'package:tet_app/models/test_session.dart';
import 'package:tet_app/models/test_language_mode.dart';
import 'package:tet_app/models/flash_message.dart';
import 'package:tet_app/design_system/app_strings.dart';
import 'package:tet_app/services/sync_service.dart';
import 'package:tet_app/services/exam_service.dart';
import 'package:tet_app/services/mock_engine.dart';

void main() {
  group('TET Models Test', () {
    test('Question serialization and getters', () {
      final q = Question(
        id: 'test_1',
        exams: 'utet1',
        section: 'cdp',
        topicIndex: 0,
        topicName: 'समावेशी शिक्षा',
        difficulty: 2,
        qHindi: 'समावेशी शिक्षा का तात्पर्य है:',
        optionsHindi: ['सभी बच्चों को एक साथ पढ़ाना', 'अलग विद्यालय', 'विशेष कोचिंग', 'कोई नहीं'],
        answer: 0,
        pScore: 0.84,
        years: '2023,2025',
      );

      expect(q.isPyq, true);
      expect(q.pScore, 0.84);
      expect(q.topicName, 'समावेशी शिक्षा');

      final dbMap = q.toDbMap();
      final fromDb = Question.fromDbMap(dbMap);

      expect(fromDb.id, 'test_1');
      expect(fromDb.answer, 0);
      expect(fromDb.optionsHindi.length, 4);
    });

    test('QuestionSanitizer cleans leaked exam tags from options and extracts source tag', () {
      final q = Question.fromPackJson({
        'k': 'test_leak',
        'e': 'ctet1',
        's': 'cdp',
        't': 0,
        'd': 2,
        'qh': 'अध्यापक का मुख्य कर्तव्य क्या है?',
        'oh': [
          'सिखाना',
          'समझाना',
          'मार्गदर्शन',
          'अब्दुल कलाम आजाद UT TET Paper - I (Class I-V) 12 Nov 2013',
        ],
        'a': 3,
        'p': 0.75,
      });

      expect(q.optionsHindi[3], 'अब्दुल कलाम आजाद');
      expect(q.sourceTag, contains('UTET'));
      expect(q.sourceTag, contains('2013'));
      expect(q.years, '2013');
      expect(q.displayTag, contains('UTET'));
    });

    test('Passage serialization and HTML sanitization', () {
      final p = Passage.fromJson({
        'id': 'p_101',
        'k': 'prose',
        'd': '<b>निर्देश :</b> निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों...',
        'b': '<p>उत्तराखंड की <b>पावन</b> भूमि&nbsp;है।</p>',
      });

      expect(p.dirText.contains('<b>'), false);
      expect(p.dirText.startsWith('निर्देश'), false); // Removed duplicated prefix
      expect(p.body, 'उत्तराखंड की पावन भूमि है।');

      final map = p.toMap();
      final restored = Passage.fromMap(map);

      expect(restored.id, 'p_101');
      expect(restored.kind, 'prose');
      expect(restored.body, contains('पावन भूमि'));
    });

    test('QuestionSanitizer strips HTML tags from question stem and options', () {
      final q = Question.fromPackJson({
        'k': 'test_html',
        'e': 'ctet1',
        's': 'hindi',
        't': 0,
        'd': 2,
        'qh': '<b>भाषा</b> के संदर्भ में <i>सत्य</i> कथन है:',
        'oh': [
          '<b>कथन A</b>',
          'कथन B &amp; C',
          'कथन D',
          'उपरोक्त सभी',
        ],
        'a': 0,
        'p': 0.5,
      });

      expect(q.qHindi, 'भाषा के संदर्भ में सत्य कथन है:');
      expect(q.optionsHindi[0], 'कथन A');
      expect(q.optionsHindi[1], 'कथन B & C');
    });

    test('TestSession score and status calculation', () {
      final q1 = Question(
        id: 'q1',
        exams: 'utet1',
        section: 'cdp',
        topicIndex: 0,
        difficulty: 2,
        qHindi: 'Q1',
        optionsHindi: ['A', 'B', 'C', 'D'],
        answer: 1,
        pScore: 0.5,
      );

      final q2 = Question(
        id: 'q2',
        exams: 'utet1',
        section: 'cdp',
        topicIndex: 0,
        difficulty: 2,
        qHindi: 'Q2',
        optionsHindi: ['A', 'B', 'C', 'D'],
        answer: 2,
        pScore: 0.5,
      );

      final session = TestSession(
        id: 'session_1',
        config: const MockConfig(mode: MockMode.predicted, seed: 123),
        questions: [q1, q2],
        passages: {},
      );

      expect(session.getQuestionStatus(0), QuestionStatus.notVisited);

      // Visit question 0
      session.visitedIndices.add(0);
      expect(session.getQuestionStatus(0), QuestionStatus.notAnswered);

      // Answer question 0 correctly
      session.selectedAnswers[0] = 1;
      expect(session.getQuestionStatus(0), QuestionStatus.answered);

      // Mark question 0 for review
      session.markedForReview.add(0);
      expect(session.getQuestionStatus(0), QuestionStatus.answeredAndMarked);

      // Answer question 1 incorrectly
      session.visitedIndices.add(1);
      session.selectedAnswers[1] = 0;

      // Score check: q1 is correct (1==1), q2 is incorrect (0!=2)
      expect(session.calculateScore(), 1);
    });

    test('MockMode details should not contain secret engine formulas', () {
      final desc = MockMode.predicted.description;
      expect(desc.contains('लाप्लास'), false);
      expect(desc.contains('पॉइसों'), false);
      expect(desc.contains('Laplace'), false);
      expect(desc.contains('Poisson'), false);
      expect(desc.contains('गहन विश्लेषण'), true);
    });

    test('Database management strings and SyncService reactivity', () {
      expect(AppStrings.settingsBankHeader.isNotEmpty, true);
      expect(AppStrings.dbCleanResyncBtn.isNotEmpty, true);
      expect(AppStrings.dbOptimizeBtn.isNotEmpty, true);
      expect(AppStrings.dbCleanDialogTitle.isNotEmpty, true);
      expect(AppStrings.dbOptimizeDoneTitle.isNotEmpty, true);

      // Verify SyncService onDatabaseUpdated notifier
      DateTime? notifiedTime;
      SyncService.onDatabaseUpdated.addListener(() {
        notifiedTime = SyncService.onDatabaseUpdated.value;
      });

      final testNow = DateTime.now();
      SyncService.onDatabaseUpdated.value = testNow;
      expect(notifiedTime, testNow);
    });

    test('FlashMessage model serialization and dismiss filter', () {
      final msg = FlashMessage.fromJson({
        'id': 'notice_v1',
        'title': 'टेस्ट सूचना',
        'message': 'यह एक टेस्ट नोटिस है।',
        'type': 'notice',
        'actionLabel': 'देखें',
        'isDismissible': true,
      });

      expect(msg.id, 'notice_v1');
      expect(msg.title, 'टेस्ट सूचना');
      expect(msg.isDismissible, true);

      final dismissedIds = {'notice_v1'};
      final allMsgs = [msg, const FlashMessage(id: 'notice_v2', title: 'नया संदेश', message: 'मैसेज')];
      final visible = allMsgs.where((m) => !dismissedIds.contains(m.id)).toList();

      expect(visible.length, 1);
      expect(visible.first.id, 'notice_v2');
    });

    test('TestLanguageMode covers all 3 modes cleanly', () {
      expect(TestLanguageMode.values.length, 3);

      expect(TestLanguageMode.onlyHindi.badgeLabel, 'हिन्दी');
      expect(TestLanguageMode.onlyEnglish.badgeLabel, 'English');
      expect(TestLanguageMode.bilingual.badgeLabel, 'HI + EN');

      expect(TestLanguageMode.onlyHindi.title.contains('हिन्दी'), true);
      expect(TestLanguageMode.onlyEnglish.title.contains('English'), true);
      expect(TestLanguageMode.bilingual.title.contains('द्विभाषी'), true);
    });

    test('ExamService Paper 1 and Paper 2 architecture mapping', () {
      final service = ExamService.instance;
      service.currentExam.value = AppExam.utet;
      service.currentPaper.value = AppPaper.paper1;
      expect(service.examCode, 'utet1');
      expect(service.isPaper1, true);
      expect(service.isPaper2, false);

      service.currentPaper.value = AppPaper.paper2;
      expect(service.examCode, 'utet2');
      expect(service.isPaper2, true);

      service.currentExam.value = AppExam.ctet;
      expect(service.examCode, 'ctet2');
      expect(service.isCtet, true);

      service.currentPaper.value = AppPaper.paper1;
      expect(service.examCode, 'ctet1');

      // Verify sections
      expect(MockEngine.paper1Sections.length, 5);
      expect(MockEngine.paper1Sections, contains('evs'));
      expect(MockEngine.paper2Sections.length, 6);
      expect(MockEngine.paper2Sections, contains('science'));
      expect(MockEngine.paper2Sections, contains('social'));
    });

    test('Question model safely falls back to Hindi options when English options are empty', () {
      final q = Question.fromPackJson({
        'k': 'test_fallback',
        'e': 'ctet1',
        's': 'cdp',
        't': 0,
        'd': 2,
        'qh': 'विकास की दिशा क्या होती है?',
        'oh': ['सिर से पैर की ओर', 'पैर से सिर की ओर', 'केंद्र से बाहर', 'समान'],
        'qe': 'What is the direction of development?',
        'oe': ['', '', 'Center to outward', ''],
        'a': 0,
        'p': 0.9,
      });

      expect(q.optionsEnglish, isNotNull);
      expect(q.optionsEnglish![0], 'सिर से पैर की ओर');
      expect(q.optionsEnglish![1], 'पैर से सिर की ओर');
      expect(q.optionsEnglish![2], 'Center to outward');
      expect(q.optionsEnglish![3], 'समान');
    });

    test('Question displayTag sanitizes ugly bank/practice tags', () {
      final q = Question(
        id: 'q_bank_tag',
        exams: 'ctet1',
        section: 'cdp',
        topicIndex: 0,
        difficulty: 2,
        qHindi: 'test',
        optionsHindi: ['a', 'b', 'c', 'd'],
        answer: 0,
        pScore: 0.5,
        sourceTag: 'CTET Bank CDP Questions 2021',
      );

      expect(q.displayTag, 'CTET 2021');
    });
  });
}
