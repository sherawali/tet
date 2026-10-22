import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tet_app/models/mock_config.dart';
import 'package:tet_app/models/passage.dart';
import 'package:tet_app/models/question.dart';
import 'package:tet_app/models/test_session.dart';
import 'package:tet_app/services/html_booklet_builder.dart';

/// Proves, for every paper in the vault, that
///  1. all 150 questions are rendered,
///  2. a passage is printed together with its own questions and nowhere else,
///  3. no passage text can leak into an option.
void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('tet_booklet');
    final source = File('assets/database/tet_mock_vault.db');
    final file = File('${dir.path}/vault.db')
      ..writeAsBytesSync(source.readAsBytesSync());
    db = await databaseFactoryFfi.openDatabase(file.path);
  });

  tearDownAll(() async {
    await db.close();
  });

  test('every paper renders all of its questions with its passages', () async {
    final forms = await db.rawQuery('SELECT * FROM paper_forms ORDER BY id');
    // A tripwire against a broken bank, not a fixed number: the vault
    // has grown before (62 → 63) and may grow again.
    expect(forms.length, greaterThan(55));

    // The booklets are rendered in two halves, because a full run of all
    // booklets in one test used more memory than the test isolate has.
    final half = (forms.length / 2).ceil();
    final first = await _checkPapers(db, forms.sublist(0, half));
    final second = await _checkPapers(db, forms.sublist(half));

    final papersChecked = first.papers + second.papers;
    final questionsChecked = first.questions + second.questions;
    final optionsChecked = first.options + second.options;
    final passageGroupsChecked = first.passages + second.passages;

    // ignore: avoid_print
    print(
      'Verified $papersChecked papers, $questionsChecked questions, '
      '$optionsChecked options, $passageGroupsChecked passage groups',
    );
    // 150 questions per paper, the app-wide rule (BankFacts.questionsPerPaper).
    expect(papersChecked, forms.length);
    expect(questionsChecked, forms.length * 150);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

class _PaperCheck {
  const _PaperCheck(this.papers, this.questions, this.options, this.passages);

  final int papers;
  final int questions;
  final int options;
  final int passages;
}

/// Checks one group of papers and reports what it found.
Future<_PaperCheck> _checkPapers(Database db, List<Map<String, Object?>> forms) async {
  {
    var papersChecked = 0;
    var questionsChecked = 0;
    var passageGroupsChecked = 0;
    var optionsChecked = 0;

    for (final form in forms) {
      final formId = form['id'] as String;
      final paper = form['paper'] as int;

      // Load the paper exactly like the app does (stream filter for Paper 2).
      final rows = await db.rawQuery(
        'SELECT a.question_number, a.section, q.* FROM appearances a '
        'JOIN questions q ON a.question_id = q.id '
        'WHERE a.paper_form_id = ?',
        [formId],
      );
      var questions = rows.map((r) => Question.fromDbMap(r)).toList();
      if (paper == 2) {
        final sections = questions.map((q) => q.section).toSet();
        if (sections.contains('math_science') &&
            sections.contains('social_studies')) {
          // A Paper-2 candidate attempts one optional stream only.
          questions =
              questions.where((q) => q.section != 'social_studies').toList();
        }
      }
      questions.sort(
        (a, b) => (a.questionNumber ?? 0).compareTo(b.questionNumber ?? 0),
      );
      expect(questions.length, 150, reason: 'paper $formId must expose 150 questions');

      // Passages of this paper.
      final passages = <String, Passage>{};
      for (final q in questions) {
        final pid = q.passageId;
        if (pid == null || pid.isEmpty || passages.containsKey(pid)) continue;
        final p = await db.query('passages', where: 'id = ?', whereArgs: [pid]);
        if (p.isEmpty) continue;
        final row = p.first;
        passages[pid] = Passage(
          id: row['id'] as String,
          kind: row['kind'] as String? ?? 'prose',
          dirText: row['dir_text'] as String? ?? '',
          body: row['body'] as String? ?? '',
        );
      }

      final session = TestSession(
        id: 'check-$formId',
        config: MockConfig(
          mode: MockMode.pyq,
          exam: form['exam'] as String,
          totalQuestions: questions.length,
          timeLimitMinutes: 150,
          seed: 1,
        ),
        questions: questions,
        passages: passages,
        elapsedSeconds: 0,
        startTime: DateTime(2026, 1, 1),
        paperTitle: form['title'] as String? ?? formId,
        setCode: form['set_code'] as String? ?? 'A',
      );

      final html = HtmlBookletBuilder.buildHtml(session);
      final plain = _plainText(html);
      final optionBlocks = RegExp(
        r'<div class="option-row"[^>]*>(.*?)</div>',
        dotAll: true,
      ).allMatches(html).map((m) => _plainText(m.group(1) ?? '')).toList();

      // 1. every question is rendered exactly once
      final itemCount = RegExp(r'<div class="question-item"').allMatches(html).length;
      expect(itemCount, 150, reason: 'paper $formId renders $itemCount questions');
      for (var i = 1; i <= 150; i++) {
        expect(
          html.contains('id="qitem-$i"'),
          isTrue,
          reason: 'paper $formId is missing question $i',
        );
      }

      for (final q in questions) {
        // The stem may be restructured by a specialised renderer (statement
        // lists split the intro from the parts), so a short prefix plus all
        // four options is the reliable completeness proof.
        final stem = _letters(q.qHindi);
        if (stem.length >= 12) {
          expect(
            plain.contains(stem.substring(0, 12)),
            isTrue,
            reason: 'paper $formId does not render ${q.id}',
          );
        }
        for (final option in q.optionsHindi) {
          final opt = _letters(option);
          if (opt.length < 8) continue;
          expect(
            plain.contains(opt.substring(0, 8)),
            isTrue,
            reason: 'paper $formId misses an option of ${q.id}',
          );
          optionsChecked++;
        }
      }
      questionsChecked += questions.length;

      // 2. + 3. every passage is printed once, with its own questions, and
      //         never inside an option.
      for (final entry in passages.entries) {
        final pid = entry.key;
        final passage = entry.value;
        final groupStart = html.indexOf('<section class="q-group" data-pid="$pid">');
        expect(
          groupStart,
          greaterThanOrEqualTo(0),
          reason: 'paper $formId has no group for passage $pid',
        );
        final groupEnd = html.indexOf('</section>', groupStart);
        final group = _plainText(html.substring(groupStart, groupEnd));
        passageGroupsChecked++;

        final body = _letters(passage.cleanBody);
        final bodyNeedle = body.substring(0, body.length > 40 ? 40 : body.length);

        // The passage is printed inside the group of its own questions.
        expect(
          group.contains(bodyNeedle),
          isTrue,
          reason: 'passage $pid is not printed inside its own group',
        );

        // The passage is printed exactly once in the whole booklet.
        expect(
          plain.split(bodyNeedle).length - 1,
          1,
          reason: 'passage $pid is printed more than once in $formId',
        );

        // All questions of this passage sit in the same group.
        for (final q in questions.where((q) => q.passageId == pid)) {
          expect(
            html.substring(groupStart, groupEnd).contains('id="qitem-${q.questionNumber}"'),
            isTrue,
            reason: 'question ${q.id} is not inside the group of passage $pid',
          );
        }

        // No option may contain a copy of the passage.  A question may quote a
        // single line of its reading, so a copy has to be a long one.
        for (final option in optionBlocks) {
          if (option.length < 60) continue;
          expect(
            option.contains(bodyNeedle.substring(0, 40)),
            isFalse,
            reason: 'passage $pid leaked into an option of $formId',
          );
        }
      }

      papersChecked++;
    }

    return _PaperCheck(
      papersChecked,
      questionsChecked,
      optionsChecked,
      passageGroupsChecked,
    );
  }
}

/// The visible letters of a text, so that formatting (escaping, tags, blank
/// place holders, line breaks) cannot hide a missing question.
String _letters(String text) =>
    text.replaceAll(RegExp('[^\\u0900-\\u097F A-Za-z0-9]'.replaceAll(' ', '')), '');

/// The same, but for a chunk of HTML: tags are removed, entities are decoded.
String _plainText(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp('[^\\u0900-\\u097F A-Za-z0-9]'.replaceAll(' ', '')), '');
