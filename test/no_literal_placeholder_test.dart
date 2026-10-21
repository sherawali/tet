import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A placeholder that reaches the screen is a bug.
///
/// The string "सेट-\$num" once showed up as "सेट-$num" in the practice sets,
/// so every source file is scanned for an escaped placeholder.
void main() {
  test('no source file prints a placeholder literally', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);

    final escaped = RegExp(r'\\\$\{?[A-Za-z_]\w*\}?');
    final problems = <String>[];

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // A regex may legitimately want a literal dollar sign.
        if (line.contains('RegExp') || line.contains('regex')) continue;
        final match = escaped.firstMatch(line);
        if (match != null) {
          problems.add('${file.path}:${i + 1} -> ${match.group(0)}');
        }
      }
    }

    expect(problems, isEmpty,
        reason: 'these files print a placeholder instead of its value: '
            '${problems.join(', ')}');
  });
}
