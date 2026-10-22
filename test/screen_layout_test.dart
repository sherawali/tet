import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/design_system/app_theme.dart';
import 'package:tet_app/models/mock_config.dart';
import 'package:tet_app/models/question.dart';
import 'package:tet_app/models/test_session.dart';
import 'package:tet_app/screens/cbt_exam_screen.dart';
import 'package:tet_app/screens/result_screen.dart';
import 'package:tet_app/screens/solution_screen.dart';

/// No screen may overflow on a small phone.
///
/// Every screen is rendered on a 360 dp wide phone (the narrowest common
/// width) in both the light and the dark theme.  A RenderFlex overflow is a
/// Flutter error, so the test fails as soon as one of the screens breaks.
Question _question(int i) => Question(
      id: 'q$i',
      exams: 'utet',
      section: i.isEven ? 'cdp' : 'hindi',
      topicIndex: 0,
      topicName: 'बाल विकास एवं शिक्षा विज्ञान',
      difficulty: 2,
      qHindi: 'प्रश्न $i का पाठ, जिसे पढ़कर सही उत्तर चुनना है।',
      optionsHindi: const ['पहला विकल्प', 'दूसरा विकल्प', 'तीसरा विकल्प', 'चौथा विकल्प'],
      qEnglish: 'Question $i text that the candidate has to read.',
      optionsEnglish: const ['First option', 'Second option', 'Third option', 'Fourth option'],
      answer: 1,
      pScore: 0.5,
    );

TestSession _session() {
  final questions = List.generate(4, _question);
  return TestSession(
    id: 'layout-probe',
    config: MockConfig(
      mode: MockMode.pyq,
      seed: 1,
      totalQuestions: 4,
      timeLimitMinutes: 30,
    ),
    questions: questions,
    passages: const {},
    selectedAnswers: {0: 1, 1: 0, 3: 2},
    markedForReview: {2},
    visitedIndices: {0, 1, 2, 3},
    elapsedSeconds: 300,
    isCompleted: true,
    paperTitle: 'UTET 2022 Paper-1 Model Test Paper 01',
  );
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen, ThemeData theme) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: theme, home: screen));
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final name = theme.brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('the result screen lays out on a 360 dp phone ($name)',
        (tester) async {
      await pumpScreen(tester, ResultScreen(session: _session()), theme);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the solution screen lays out on a 360 dp phone ($name)',
        (tester) async {
      await pumpScreen(tester, SolutionScreen(session: _session()), theme);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the CBT screen lays out on a 360 dp phone ($name)',
        (tester) async {
      await pumpScreen(
        tester,
        CbtExamScreen(session: _session()),
        theme,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
