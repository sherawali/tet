import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tet_app/widgets/question_figure_catalog.dart';

/// Questions whose text points to a picture need that picture.
///
/// The check reads the shipped question bank, so a new question that talks
/// about a drawing without a drawing and without a description in the stem
/// fails the test instead of reaching the candidate.
void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('tet_figures');
    final source = File('assets/database/tet_mock_vault.db');
    final file = File('${dir.path}/vault.db')
      ..writeAsBytesSync(source.readAsBytesSync());
    db = await databaseFactoryFfi.openDatabase(file.path);
  });

  tearDownAll(() async {
    await db.close();
  });

  test('every question that points to a picture has one', () async {
    const pointerWords = <String>[
      'निम्न आकृत',
      'निम्नलिखित आकृत',
      'दिये गये चित्र',
      'दिए गए चित्र',
      'दी गई आकृत',
      'दी गयी आकृत',
      'दिए गए आकार',
      'दिये गये आकार',
      'चित्र में',
      'आकृति में',
      'आकृति अनुसार',
    ];
    // A picture that is written out in the stem answers the question.
    final described = RegExp(r'(आकृति\s*:|आकृति\s*-|चित्र\s*:|figure\s*:)');
    // The question is about the picture itself, not about a property of it.
    final meta = RegExp(
      r'(यह\s*प्रश्न|निम्न\s*प्रश्न|कौन\s*सा\s*प्रश्न|किस\s*प्रकार\s*का\s*प्रश्न|'
      r'कौन-सा\s*प्रश्न|this\s+question)',
    );
    // Words that only look like a picture.
    final notAPicture = RegExp(r'(मानचित्र|चित्रकला|चित्रालेख|चित्रण)');

    // Questions that talk about shapes but are answered from knowledge
    // alone - the options name the shapes, so nothing has to be drawn.
    const answerableWithoutDrawing = <String>{
      'ctet-p1-2021-pyq_q056', // Van Hiele level, the shapes are not shown.
      'ctet-p2-ms-mock-01_q119', // the options name the shapes.
      'ctet-p2-ms-mock-05_q106', // histogram: frequency is shown by the area.
    };

    final rows = await db.rawQuery(
      'SELECT q.id, q.q_hindi, q.q_english, a.paper_form_id AS paper, '
      'a.question_number AS number FROM appearances a '
      'JOIN questions q ON a.question_id = q.id',
    );
    expect(rows.length, greaterThan(9000));

    final missing = <String>[];
    for (final row in rows) {
      final text = '${row['q_hindi'] ?? ''} ${row['q_english'] ?? ''}';
      if (!pointerWords.any(text.contains)) continue;
      if (described.hasMatch(text) || meta.hasMatch(text)) continue;
      if (notAPicture.hasMatch(text) && !text.contains('आकृति')) continue;
      if (answerableWithoutDrawing.contains(row['id'])) continue;
      if (QuestionFigureCatalog.hasQuestionFigure(row['id'] as String)) continue;
      missing.add('${row['paper']} qn${row['number']} ${row['id']}: '
          '${text.trim().split(' ').take(12).join(' ')}');
    }

    expect(missing, isEmpty,
        reason: 'these questions point to a picture that is not drawn: '
            '${missing.join(' | ')}');
  });

  test('the hand drawn figures are complete', () {
    const ids = <String>[
      '25a91897876ef150',
      'ctet-p1-2018-pyq_q047',
      'd726e769bed17822',
      '7162186106ad5143',
    ];
    for (final id in ids) {
      expect(QuestionFigureCatalog.hasQuestionFigure(id), isTrue,
          reason: 'figure for $id is missing');
      final svg = QuestionFigureCatalog.questionSvg(id);
      expect(svg, isNotNull, reason: 'no svg for $id');
      expect(svg, contains('<svg'), reason: 'broken svg for $id');
      expect(svg!.length, greaterThan(200), reason: 'svg for $id is too small');
    }
  });

  testWidgets('every figure paints in the app as well', (tester) async {
    for (final id in const [
      '25a91897876ef150',
      'ctet-p1-2018-pyq_q047',
      'd726e769bed17822',
      '7162186106ad5143',
      '42585dbbc302b422',
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuestionFigureCatalog.buildQuestion(
            questionId: id,
            isDark: false,
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'figure $id failed to paint');
    }
  });
}
