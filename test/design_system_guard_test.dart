import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The design system has to stay in charge.
///
/// Every rule here was a real defect: a colour that only existed in one
/// screen, an animation with its own duration, a corner radius that nobody
/// else used.  The test keeps the polish from slipping away again.
void main() {
  List<File> widgetFiles() {
    final files = <File>[];
    for (final folder in ['lib/screens', 'lib/widgets', 'lib/services']) {
      final directory = Directory(folder);
      if (!directory.existsSync()) continue;
      files.addAll(
        directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
      );
    }
    return files;
  }

  test('no screen paints a hard coded colour', () {
    final pattern = RegExp(r'Color\(0xFF[0-9A-Fa-f]{6}\)');
    final problems = <String>[];
    for (final file in widgetFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          problems.add('${file.path}:${i + 1} -> ${lines[i].trim()}');
        }
      }
    }
    expect(problems, isEmpty,
        reason: 'these screens still hard code a colour: ${problems.join(' | ')}');
  });

  test('no screen invents its own animation duration', () {
    final pattern = RegExp(r'Duration\(milliseconds:');
    final problems = <String>[];
    for (final file in widgetFiles()) {
      if (file.path.contains('design_system')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          problems.add('${file.path}:${i + 1} -> ${lines[i].trim()}');
        }
      }
    }
    expect(problems, isEmpty,
        reason: 'these animations do not use AppMotion: ${problems.join(' | ')}');
  });

  test('every animated container has a curve', () {
    final problems = <String>[];
    for (final file in widgetFiles()) {
      final text = file.readAsStringSync();
      final pattern = RegExp(
        r'Animated(Container|Size|Opacity)\(\s*\n(\s*)duration:[^,]+,',
      );
      for (final match in pattern.allMatches(text)) {
        final after = text.substring(match.end, match.end + 120);
        if (!after.contains('curve:')) {
          final line = text.substring(0, match.start).split('\n').length;
          problems.add('${file.path}:$line');
        }
      }
    }
    expect(problems, isEmpty,
        reason: 'these animations run with the linear default: '
            '${problems.join(' | ')}');
  });

  test('the booklet css uses one type scale', () {
    final builder = File('lib/services/html_booklet_builder.dart').readAsStringSync();
    final marker = "static final String _cssContent = '''";
    final start = builder.indexOf(marker) + marker.length;
    final css = builder.substring(start, builder.indexOf("'''", start));

    final sizes = RegExp(r'font-size:\s*([0-9.]+)px')
        .allMatches(css)
        .map((m) => double.parse(m.group(1)!))
        .toSet()
        .toList()
      ..sort();
    expect(sizes.length, lessThanOrEqualTo(14),
        reason: 'the booklet uses too many font sizes: $sizes');
  });

  test('no screen hard codes a Hindi label', () {
    // Every label of the exam flow lives in app_strings.dart, so the whole
    // app can speak Hindi or English.  A Hindi only string in a screen is a
    // label that stays Hindi in the English mode.
    const examFlow = <String>[
      'lib/screens/home_screen.dart',
      'lib/screens/cbt_exam_screen.dart',
      'lib/screens/result_screen.dart',
      'lib/screens/solution_screen.dart',
      'lib/screens/subject_detail_screen.dart',
      'lib/screens/mock_series_screen.dart',
      'lib/screens/pyq_vault_screen.dart',
      'lib/widgets/math_diagram_widget.dart',
      'lib/widgets/passage_display_card.dart',
    ];
    final devanagari = RegExp(r'[\u0900-\u097F]');
    final latin = RegExp(r'[A-Za-z]{3,}');
    final problems = <String>[];

    for (final path in examFlow) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith("'") && !line.startsWith('"')) continue;
        if (!devanagari.hasMatch(line)) continue;
        // A line that picks its language is fine.
        if (line.contains('isHi') || line.contains('isHindi')) continue;
        // A label that carries both languages is fine.
        if (latin.hasMatch(line)) continue;
        problems.add('$path:${i + 1} -> ${line.substring(0, line.length > 70 ? 70 : line.length)}');
      }
    }
    expect(problems, isEmpty,
        reason: 'these labels stay Hindi in the English mode: '
            '${problems.join(' | ')}');
  });
}
