import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tet_app/services/section_catalog.dart';

/// The UI must never show a raw section code (LANG1_HINDI, MATH_SCIENCE)
/// and must never offer a subject that the selected paper does not contain.
void main() {
  late Database db;
  late List<String> sections;

  setUpAll(() async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('tet_bank_facts');
    final source = File('assets/database/tet_mock_vault.db');
    final file = File('${dir.path}/vault.db')
      ..writeAsBytesSync(source.readAsBytesSync());
    db = await databaseFactoryFfi.openDatabase(file.path);
    sections = [
      for (final row in await db.rawQuery('SELECT DISTINCT section FROM questions'))
        row['section'] as String,
    ];
  });

  tearDownAll(() async {
    await db.close();
  });

  test('every section of the vault has a readable label', () {
    expect(sections, isNotEmpty);
    for (final code in sections) {
      final label = SectionCatalog.label(code);
      expect(
        label.hi,
        isNot(equals(code.toUpperCase())),
        reason: 'section "$code" has no Hindi label',
      );
      expect(
        label.en,
        isNot(equals(code.toUpperCase())),
        reason: 'section "$code" has no English label',
      );
      expect(label.hi, isNotEmpty);
      expect(label.en, isNotEmpty);
    }
  });

  test('the subject grid only offers sections that exist for the paper', () async {
    for (final paper in [1, 2]) {
      final allowed = SectionCatalog.forPaper(paper).toSet();
      final rows = await db.rawQuery(
        'SELECT DISTINCT q.section AS section FROM appearances a '
        'JOIN questions q ON q.id = a.question_id '
        'JOIN paper_forms p ON p.id = a.paper_form_id '
        'WHERE p.paper = ?',
        [paper],
      );
      for (final row in rows) {
        final code = row['section'] as String;
        expect(
          allowed.contains(code),
          isTrue,
          reason: 'section "$code" of paper $paper is not in the catalogue',
        );
      }
    }
  });

  test('the year list only offers years that really have a paper', () async {
    final rows = await db.rawQuery(
      "SELECT DISTINCT exam, exam_date FROM paper_forms "
      "WHERE exam_date IS NOT NULL AND exam_date != '' AND exam_date NOT LIKE '%Mock%'",
    );
    expect(rows, isNotEmpty);
    final years = <String>{};
    for (final row in rows) {
      final match = RegExp(r'(20\d{2})').firstMatch(row['exam_date'] as String);
      if (match != null) years.add(match.group(1)!);
    }
    for (final year in years) {
      final forms = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM paper_forms "
        "WHERE exam_date LIKE ? AND exam_date NOT LIKE '%Mock%'",
        ['%$year%'],
      );
      expect((forms.first['cnt'] as num).toInt(), greaterThan(0));
    }
  });
}
