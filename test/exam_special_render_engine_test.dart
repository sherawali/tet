import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/models/question.dart';
import 'package:tet_app/models/test_language_mode.dart';
import 'package:tet_app/widgets/exam_special_render_engine.dart';
import 'package:tet_app/widgets/math_diagram_widget.dart';

void main() {
  group('ExamSpecialRenderEngine Tests', () {
    testWidgets('Renders geometry diagram for utet-p1-2022-mathematics-q115', (WidgetTester tester) async {
      const question = Question(
        id: 'utet-p1-2022-mathematics-q115',
        exams: 'UTET',
        section: 'mathematics',
        topicIndex: 0,
        difficulty: 2,
        qHindi: 'दी गई आकृति में, OP || RS, ∠OPQ = 100° तथा ∠QRS = 140° तो ∠PQR का मान है :',
        qEnglish: 'In the given figure, OP || RS, ∠OPQ = 100° and ∠QRS = 140° then the value of ∠PQR is :',
        optionsHindi: ['40°', '50°', '60°', '70°'],
        optionsEnglish: ['40°', '50°', '60°', '70°'],
        answer: 2,
        pScore: 0.95,
        sourceTag: 'UTET 2022 Paper 1',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExamSpecialRenderEngine(
                question: question,
                languageMode: TestLanguageMode.bilingual,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      // Verify that MathDiagramWidget is rendered
      expect(find.byType(MathDiagramWidget), findsOneWidget);
      expect(find.textContaining('OP || RS'), findsWidgets);
      // Verify secondary bilingual translation box is present
      expect(find.textContaining('In the given figure'), findsOneWidget);
    });

    testWidgets('Renders Hindi-only mode without secondary translation box', (WidgetTester tester) async {
      const question = Question(
        id: 'sample-q1',
        exams: 'CTET',
        section: 'cdp',
        topicIndex: 0,
        difficulty: 1,
        qHindi: 'विकास का सिद्धांत क्या है?',
        qEnglish: 'What is the theory of development?',
        optionsHindi: ['A', 'B', 'C', 'D'],
        answer: 0,
        pScore: 0.8,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExamSpecialRenderEngine(
              question: question,
              languageMode: TestLanguageMode.onlyHindi,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.textContaining('विकास का सिद्धांत'), findsOneWidget);
      // Secondary English text should NOT be rendered in onlyHindi mode
      expect(find.textContaining('What is the theory of development?'), findsNothing);
    });
  });
}
