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
}
