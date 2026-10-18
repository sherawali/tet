import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/data/official_pyq_repository.dart';

void main() {
  group('Official PYQ Hardcoded Repository Tests', () {
    final years = ['2020', '2021', '2022', '2024', '2025', '2026'];

    test('All 6 official UTET Paper-1 years are recognized', () {
      for (final y in years) {
        expect(OfficialPyqRepository.hasPaper('utet1', y), isTrue, reason: 'Year $y must exist');
      }
      expect(OfficialPyqRepository.hasPaper('utet1', '2019'), isFalse);
      expect(OfficialPyqRepository.hasPaper('ctet1', '2020'), isFalse);
    });

    test('Each official paper has exactly 150 questions in official section sequence', () {
      for (final y in years) {
        final paper = OfficialPyqRepository.getPaper('utet1', y);
        expect(paper, isNotNull);
        expect(paper!.questions.length, 150, reason: 'Year $y must have 150 questions');

        // Verify section boundaries
        final cdp = paper.questions.sublist(0, 30);
        final hindi = paper.questions.sublist(30, 60);
        final english = paper.questions.sublist(60, 90);
        final math = paper.questions.sublist(90, 120);
        final evs = paper.questions.sublist(120, 150);

        for (final q in cdp) {
          expect(q.section, 'cdp');
        }
        for (final q in hindi) {
          expect(q.section, 'hindi');
        }
        for (final q in english) {
          expect(q.section, 'english');
        }
        for (final q in math) {
          expect(q.section, 'math');
        }
        for (final q in evs) {
          expect(q.section, 'evs');
        }
      }
    });

    test('Passages in official papers are 100% contiguous and never split', () {
      for (final y in years) {
        final paper = OfficialPyqRepository.getPaper('utet1', y);
        expect(paper, isNotNull);

        final questions = paper!.questions;
        final passageIndices = <String, List<int>>{};

        for (int i = 0; i < questions.length; i++) {
          final pid = questions[i].passageId;
          if (pid != null && pid.isNotEmpty) {
            passageIndices.setdefault(pid, []).add(i);
          }
        }

        // Each passage must have all its questions consecutive
        for (final entry in passageIndices.entries) {
          final pid = entry.key;
          final indices = entry.value;
          expect(paper.passages.containsKey(pid), isTrue, reason: 'Passage $pid must be in passages map');
          final passage = paper.passages[pid]!;
          expect(passage.body.trim().isNotEmpty, isTrue, reason: 'Passage $pid body must not be empty');

          for (int j = 1; j < indices.length; j++) {
            expect(
              indices[j],
              indices[j - 1] + 1,
              reason: 'Passage $pid questions must be strictly contiguous in year $y! Found index ${indices[j]} after ${indices[j-1]}',
            );
          }
        }
      }
    });

    test('All 24 official passages are present, clean, and contain zero raw HTML tags', () {
      expect(OfficialPyqRepository.allPassages.length, 24);
      for (final entry in OfficialPyqRepository.allPassages.entries) {
        final p = entry.value;
        expect(p.id, isNotEmpty);
        expect(p.body, isNotEmpty);
        expect(p.kind == 'prose' || p.kind == 'poem', isTrue);
        expect(p.body.contains('<br>'), isFalse, reason: 'Passage ${p.id} must not contain raw <br>');
        expect(p.body.contains('<b>'), isFalse, reason: 'Passage ${p.id} must not contain raw <b>');
        expect(p.dirText.contains('<b>'), isFalse, reason: 'Passage ${p.id} dirText must not contain raw <b>');
      }
    });

    test('All questions in official papers are clean and free of leaked headings or answer keys', () {
      for (final y in years) {
        final paper = OfficialPyqRepository.getPaper('utet1', y);
        expect(paper, isNotNull);
        for (final q in paper!.questions) {
          // Question text should never have markdown headers, answer key summaries, or document end
          expect(q.qHindi.contains('##'), isFalse, reason: 'Question ${q.id} in $y has leaked ## in qHindi: ${q.qHindi}');
          expect(q.qHindi.contains('📋 उत्तर कुंजी'), isFalse, reason: 'Question ${q.id} in $y has leaked answer key summary');
          expect(q.qHindi.contains('दस्तावेज़ समाप्त'), isFalse, reason: 'Question ${q.id} in $y has leaked end marker');
          expect(q.qHindi.contains('Correct Answer'), isFalse, reason: 'Question ${q.id} in $y has leaked Correct Answer');
        }
      }
    });
  });
}

extension on Map<String, List<int>> {
  List<int> setdefault(String key, List<int> defaultValue) {
    if (!containsKey(key)) {
      this[key] = defaultValue;
    }
    return this[key]!;
  }
}
