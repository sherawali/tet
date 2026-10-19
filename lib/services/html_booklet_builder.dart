import 'dart:convert';
import '../models/test_session.dart';
import 'exam_service.dart';

/// Converts any [TestSession] (official PYQ or dynamic generated Mock)
/// into a standalone, ultra-premium, real-time HTML Question Booklet.
class HtmlBookletBuilder {
  static String escape(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String formatPoemBody(String body) {
    final lines = body.trim().split('\n');
    final htmlLines = <String>[];
    for (final line in lines) {
      final s = line.trim();
      if (s.isEmpty) {
        htmlLines.add('<div class="poem-stanza-gap"></div>');
      } else {
        htmlLines.add('<div class="poem-line">${escape(s)}</div>');
      }
    }
    return htmlLines.join('\n');
  }

  static String formatProseBody(String body) {
    // Paragraphs = blank-line separated. Single newlines inside a paragraph are
    // PDF wrap artifacts: reflow them with spaces so paragraphs do not visually
    // splinter into the question area below.
    final paragraphs = body.trim().split(RegExp(r'\n\s*\n'));
    final htmlP = <String>[];
    for (final p in paragraphs) {
      final s = p.trim();
      if (s.isNotEmpty) {
        final reflowed = s
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .join(' ');
        htmlP.add('<p class="prose-p">${escape(reflowed)}</p>');
      }
    }
    return htmlP.join('\n');
  }

  /// Splits a leaked instruction/direction line off a passage body so it is
  /// shown as directions instead of becoming the first "paragraph" of the
  /// passage. Returns the merged directions and the cleaned body.
  static ({String dir, String body}) splitPassageDirections(String body, String dir) {
    var b = body.trim();
    var d = dir.trim();
    final instr = RegExp(
      r'^\s*(?:\*\*)?(?:निर्देश|Directions?)\b[^\n]*',
      caseSensitive: false,
    );
    final readInstr = RegExp(
      r'^\s*(?:अधोलिखित|निम्नलिखित|नीचे\s+दिया\s+गया|Read\s+the\s+(?:extract|passage|poem))\b[^\n]*(?:पढ़कर|के\s+आधार|given\s+below)[^\n]*$',
      caseSensitive: false,
    );
    final m = instr.firstMatch(b) ?? readInstr.firstMatch(b);
    if (m != null) {
      final line = m.group(0)!.trim().replaceAll(RegExp(r'[\*\s]+$'), '');
      b = b.substring(m.end).trim();
      if (d.isEmpty) {
        d = line;
      } else if (!d.contains(line) && line.length > 12) {
        d = '$d\n$line';
      }
    }
    return (dir: d, body: b);
  }

  static String ensureOptionLabel(String opt) {
    var s = opt.trim();
    // Safety net for stale vaults: an option that starts with a continuation
    // fragment (", (B) and (C)", "and (3)", "is true but (R)") lost its real
    // leading marker "(A)"/"(1)" at ingest time. Restore a display marker.
    // Note: "Both (A) and (R) are true" is a COMPLETE option and is left alone.
    final usesDigitMarkers = RegExp(r'\([1-9]\)').hasMatch(s);
    final isContinuation = RegExp(
      r'^(?:[,،]\s*\(|(?:और|तथा|and)\s*\(|is\s+(?:true|false|right|wrong)\b|are\s+(?:true|false|right|wrong)\b)',
      caseSensitive: false,
    ).hasMatch(s);
    if (isContinuation) {
      s = '${usesDigitMarkers ? '(1)' : '(A)'} $s';
    }
    return s;
  }

  /// Formats one option cell: continuation-marker repair + markdown + newline
  /// preservation (multi-line combo options keep their line breaks).
  static String formatOptionHtml(String opt) {
    return formatInlineMarkdown(ensureOptionLabel(opt)).replaceAll('\n', '<br>');
  }

  static String formatInlineMarkdown(String text) {
    var s = escape(text);
    // Convert code blocks ``` ... ```
    s = s.replaceAllMapped(
      RegExp(r'```(?:\w+)?\s*\n?(.*?)```', dotAll: true),
      (m) => '<pre class="q-pre"><code>${m[1]!.trim()}</code></pre>',
    );
    // Convert LaTeX fraction patterns \frac{a}{b} or \dfrac{a}{b} to nice vertical fractions
    s = s.replaceAllMapped(
      RegExp(r'(?:\\d?frac\{([^{}]+)\}\{([^{}]+)\})'),
      (m) => '<span class="m-frac"><span class="m-num">${m[1]}</span><span class="m-den">${m[2]}</span></span>',
    );
    // Convert square roots \sqrt{x}
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]+)\}'),
      (m) => '√<span class="m-sqrt">${m[1]}</span>',
    );
    // Exponents x^2, 10^3
    s = s.replaceAllMapped(
      RegExp(r'(\b\w+)\^([0-9a-zA-Z\+\-]+)'),
      (m) => '${m[1]}<sup>${m[2]}</sup>',
    );
    // Clean out any raw $ math delimiters
    s = s.replaceAllMapped(RegExp(r'\$([^$]+)\$'), (m) => '${m[1]}');
    s = s.replaceAll(r'$', '');
    // Replace **bold** with <b>bold</b>
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<b>${m[1]}</b>');
    // Replace fill-in-the-blank underlines / boxes: [ _______ ] or ______ or ..... or [ ... ]
    s = s.replaceAllMapped(
      RegExp(r'\[\s*(?:_{2,}|\.{3,}|\s{3,})\s*\]|(?<!\w)_{2,}(?!\w)|\.{4,}'),
      (m) => '<span class="q-blank" title="रिक्त स्थान">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>',
    );
    return s;
  }

  static int? _parseMarkerSequenceValue(String s, String style) {
    final clean = s.trim().replaceAll(RegExp(r'[\(\)\.\:\s]'), '');
    if (style == 'alpha') {
      if (clean.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(clean)) {
        return clean.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0) + 1;
      }
    } else if (style == 'digit') {
      return int.tryParse(clean);
    } else if (style == 'roman') {
      const romanMap = {
        'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9, 'x': 10,
        'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10,
      };
      return romanMap[clean];
    }
    return null;
  }

  static bool _checkSequentialList(List<String> markers, String style) {
    if (markers.isEmpty) return false;
    final first = _parseMarkerSequenceValue(markers[0], style);
    if (first == null || first != 1) return false;
    for (int i = 0; i < markers.length; i++) {
      final val = _parseMarkerSequenceValue(markers[i], style);
      if (val != i + 1) return false;
    }
    return true;
  }

  static bool _isDirectSuccessor(String prev, String next) {
    final p = prev.toUpperCase();
    final n = next.toUpperCase();
    if (p.length == 1 && n.length == 1 && p.codeUnitAt(0) >= 65 && p.codeUnitAt(0) <= 90) {
      return n.codeUnitAt(0) == p.codeUnitAt(0) + 1;
    }
    final pInt = int.tryParse(p);
    final nInt = int.tryParse(n);
    if (pInt != null && nInt != null) {
      return nInt == pInt + 1;
    }
    const romanMap = {'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10};
    if (romanMap.containsKey(p) && romanMap.containsKey(n)) {
      return romanMap[n] == romanMap[p]! + 1;
    }
    return false;
  }

  static List<({String marker, String text})> _parseColumnItems(String rawCol) {
    final clean = rawCol.trim().replaceAll(RegExp(r'[।.,;—–\-\s]+$'), '');
    // 1. Try marker matching: (a) or a. or 1. or (1) or (i) or i. or (A) or A.
    final matches = RegExp(
      r'(?:^|[\s\.\:\-।;,])(?:\(([A-Za-z0-9]+|[i-vI-V]+)\)|([A-Za-z0-9]+|[i-vI-V]+)[\.\)])\s*([^\(\n]+?)(?=(?:[\s\.\:\-।;,](?:\([A-Za-z0-9]+|[i-vI-V]+\)|[A-Za-z0-9]+[\.\)]))|$)',
    ).allMatches(clean).toList();

    if (matches.length >= 2) {
      return matches.map((m) {
        final marker = m.group(1) != null ? '(${m.group(1)})' : '${m.group(2)}.';
        return (marker: marker, text: m.group(3)!.trim());
      }).toList();
    }

    // 2. Try comma / semicolon / newline / danda separated
    final parts = clean.split(RegExp(r'[,،;؛।\n]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return [
        for (int i = 0; i < parts.length; i++)
          (marker: '${i + 1}.', text: parts[i])
      ];
    }

    return [];
  }

  /// Parses question stem into structured HTML for Kathan (Assertion-Reason),
  /// Match the Following (Tables), Multi-Statement, and clean paragraphs.
  static String formatQuestionStemHtml(String rawStem) {
    var text = rawStem.trim();
    if (text.isEmpty) return '';

    // 0. Pre-clean question number leaks and accidental markers (Preserve __ for blanks)
    text = text
        .replaceAll(RegExp(r'^\s*(?:\*\*|#{1,6}\s*)?Q(?:uestion)?\.?\s*\d+[\.\:\*]?\s*', caseSensitive: false, multiLine: true), '')
        .replaceAll(RegExp(r'^\s*#{1,6}\s*(?:Q\.?\s*)?\d*[\.\:\-]?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*\*\*Options\s*(?:/\s*विकल्प)?\*\*\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[✅✓]'), '')
        .replaceAll(RegExp(r'^\s*#{1,6}\s*'), '')
        .replaceAllMapped(
          RegExp(r'\*\*\s*(अभिकथन|कारण|दावा|तर्क|कथनम्|कारणम्|कथन|Assertion|Reason)(?:\s*\(([A-Za-z0-9]+)\))?\s*[:\-–—ः.]?\s*\*\*', caseSensitive: false),
          (m) => '${m[1]} ${m[2] != null ? "(${m[2]}):" : ":"} ',
        )
        .replaceAllMapped(
          RegExp(r'(अभिकथन|कारण|दावा|तर्क|कथनम्|कारणम्|कथन|Assertion|Reason)(?:\s*\(([A-Za-z0-9]+)\))?\s*[:\-–—ः.]?\s*\*\*', caseSensitive: false),
          (m) => '${m[1]} ${m[2] != null ? "(${m[2]}):" : ":"} ',
        )
        .replaceAll('**', '')
        .trim();

    final conclusionPattern = RegExp(
      r'^(.*?)\s*([–—\-:ः]*\s*(?:सही\s*(?:विकल्प|उत्तर|कूट|कोड)|दिए\s*गए\s*विकल्प(?:ों)?|निम्नलिखित\s*(?:में\s*से\s*)?सही|उपर्युक्त|उपरोक्त|नीचे\s*दिए|इनमें\s*से|इनमें|Choose\s*the\s*correct|Select\s*the\s*correct|Select\s*from\s*the|Which\s*of\s*the\s*above|Code\s*:|Codes\s*:|कूट\s*:|कोड\s*:)[^\n]*)$',
      caseSensitive: false,
      dotAll: true,
    );

    // 1. Check Markdown Table:
    if (text.contains('|') && RegExp(r'\|\s*[-:]+[-| :]*\|').hasMatch(text)) {
      final lines = text.split('\n');
      int tableStartIndex = -1;
      int tableDividerIndex = -1;
      int tableEndIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('|') && line.endsWith('|')) {
          if (tableStartIndex == -1) tableStartIndex = i;
          if (tableDividerIndex == -1 && RegExp(r'^\|[\s\-:|]+\|$').hasMatch(line.replaceAll(' ', ''))) {
            tableDividerIndex = i;
          }
          tableEndIndex = i;
        } else if (tableStartIndex != -1 && tableEndIndex != -1 && tableDividerIndex != -1) {
          break;
        }
      }

      if (tableStartIndex != -1 && tableDividerIndex != -1 && tableDividerIndex > tableStartIndex) {
        final introLines = lines.sublist(0, tableStartIndex).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        final intro = introLines.isNotEmpty ? introLines.join('<br>') : null;
        final headerLine = lines[tableStartIndex].trim();
        final rawHeaders = headerLine.split('|').map((c) => c.trim().replaceAll('**', '')).toList();
        final headers = rawHeaders.length > 2
            ? rawHeaders.sublist(1, rawHeaders.length - 1)
            : rawHeaders.where((c) => c.isNotEmpty).toList();

        final rows = <List<String>>[];
        for (int i = tableDividerIndex + 1; i <= tableEndIndex; i++) {
          final rowLine = lines[i].trim();
          if (rowLine.startsWith('|') && rowLine.endsWith('|')) {
            final rawCells = rowLine.split('|').map((c) => c.trim().replaceAll('**', '')).toList();
            final cells = rawCells.length > 2
                ? rawCells.sublist(1, rawCells.length - 1)
                : rawCells.where((c) => c.isNotEmpty).toList();
            if (cells.isNotEmpty) rows.add(cells);
          }
        }
        final postLines = lines.sublist(tableEndIndex + 1).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        final postTable = postLines.isNotEmpty ? postLines.join('<br>') : null;

        final buffer = StringBuffer();
        buffer.write('<div class="q-table-wrapper">');
        if (intro != null) {
          buffer.write('<div class="q-stem-intro">${formatInlineMarkdown(intro)}</div>');
        }
        buffer.write('<table class="q-table"><thead><tr>');
        for (final h in headers) {
          buffer.write('<th>${formatInlineMarkdown(h)}</th>');
        }
        buffer.write('</tr></thead><tbody>');
        for (final r in rows) {
          buffer.write('<tr>');
          for (final cell in r) {
            buffer.write('<td>${formatInlineMarkdown(cell)}</td>');
          }
          buffer.write('</tr>');
        }
        buffer.write('</tbody></table>');
        if (postTable != null) {
          buffer.write('<div class="q-stem-post">${formatInlineMarkdown(postTable)}</div>');
        }
        buffer.write('</div>');
        return buffer.toString();
      }
    }

    // 2A. Check Match-The-Following Type 1: Sequential Columns (सूची-I / List-I followed by सूची-II / List-II or स्तम्भ 1/2 or कॉलम A/B)
    final h1Matches = RegExp(r"""(?:सूची|स्तम्भ|कॉलम|भाग|तालिका|List|Column)\s*[-–—:'"]*\s*(?:I|1|A)(?:\s*\([^\)]+\))?\s*[:\-–—\.]?""", caseSensitive: false).allMatches(text).toList();
    final h2Matches = RegExp(r"""(?:सूची|स्तम्भ|कॉलम|भाग|तालिका|List|Column)\s*[-–—:'"]*\s*(?:II|2|B)(?:\s*\([^\)]+\))?\s*[:\-–—\.]?""", caseSensitive: false).allMatches(text).toList();

    if (h1Matches.isNotEmpty && h2Matches.isNotEmpty) {
      final lastH2 = h2Matches.last;
      final precedingH1s = h1Matches.where((m) => m.start < lastH2.start).toList();
      if (precedingH1s.isNotEmpty) {
        final chosenH1 = precedingH1s.last;
        final intro = text.substring(0, chosenH1.start).trim();
        final col1Raw = text.substring(chosenH1.end, lastH2.start).trim();
        var col2Raw = text.substring(lastH2.end).trim();
        String? matchConclusion;

        final cm = conclusionPattern.firstMatch(col2Raw);
        if (cm != null) {
          col2Raw = cm.group(1)!.trim().replaceAll(RegExp(r'[\s:\-–—ः.\*]+$'), '').trim();
          matchConclusion = cm.group(2)!.trim();
        }

        final col1Items = _parseColumnItems(col1Raw);
        final col2Items = _parseColumnItems(col2Raw);

        if (col1Items.length >= 2 && col2Items.length >= 2) {
          final maxRows = col1Items.length > col2Items.length ? col1Items.length : col2Items.length;
          final h1Title = chosenH1.group(0)!.trim().replaceAll(RegExp(r'[:\-–—\s\.]+$'), '');
          final h2Title = lastH2.group(0)!.trim().replaceAll(RegExp(r'[:\-–—\s\.]+$'), '');

          final b = StringBuffer();
          b.write('<div class="match-table-wrapper">');
          if (intro.isNotEmpty) {
            b.write('<div class="match-intro">${formatInlineMarkdown(intro)}</div>');
          }
          b.write('<table class="match-table"><thead><tr>');
          b.write('<th>${formatInlineMarkdown(h1Title)}</th><th>${formatInlineMarkdown(h2Title)}</th>');
          b.write('</tr></thead><tbody>');
          for (int i = 0; i < maxRows; i++) {
            final l = i < col1Items.length ? col1Items[i] : null;
            final r = i < col2Items.length ? col2Items[i] : null;
            b.write('<tr>');
            b.write('<td>${l != null ? "<b>${l.marker}</b> ${formatInlineMarkdown(l.text)}" : ""}</td>');
            b.write('<td>${r != null ? "<b>${r.marker}</b> ${formatInlineMarkdown(r.text)}" : ""}</td>');
            b.write('</tr>');
          }
          b.write('</tbody></table>');
          if (matchConclusion != null && matchConclusion.isNotEmpty) {
            b.write('<div class="match-conclusion">${formatInlineMarkdown(matchConclusion)}</div>');
          }
          b.write('</div>');
          return b.toString();
        }
      }
    }

    // 2B. Check Match-The-Following Type 2: Dashed Pairs (e.g. 1. नीलगिरी – (a) अनाईमुडी 2. सतपुड़ा – (b) डोडाबेट्टा)
    final isMatchStem = RegExp(r'(?:सुमेलित|मिलान|Match|युग्म|जोड़ा|जोड़े|कॉलम|स्तम्भ|सूची)', caseSensitive: false).hasMatch(text);
    // Gated behind isMatchStem so a non-match stem with dashed pairs can never
    // be misparsed into a table.
    final pairMatches = RegExp(
      r'(?:^|[\s\.\:\-।;,])(\d+|[a-eA-E]|[i-vI-V]+)[\.\)]\s*([^–\-]+?)\s*[–\-]\s*(?:\(([a-zA-Z0-9]+|[i-vI-V]+)\)|([a-zA-Z0-9]+|[i-vI-V]+)[\.\)])\s*([^0-9\–\-\n]+?)(?=(?:[\s\.\:\-।;,](?:\d+|[a-eA-E]|[i-vI-V]+)[\.\)]|$|\s*कूट\s*:|\s*कोड\s*:))',
    ).allMatches(text).toList();

    if (isMatchStem && pairMatches.length >= 2) {
      final firstStart = pairMatches.first.start;
      final intro = firstStart > 0 ? text.substring(0, firstStart).trim() : '';
      final lastEnd = pairMatches.last.end;
      final afterText = lastEnd < text.length ? text.substring(lastEnd).trim() : '';

      final b = StringBuffer();
      b.write('<div class="match-table-wrapper">');
      if (intro.isNotEmpty) {
        b.write('<div class="match-intro">${formatInlineMarkdown(intro)}</div>');
      }
      b.write('<table class="match-table"><thead><tr>');
      b.write('<th>स्तम्भ I / सूची A</th><th>स्तम्भ II / सूची B</th>');
      b.write('</tr></thead><tbody>');
      for (final pm in pairMatches) {
        final lMarker = pm.group(1)!;
        final lText = pm.group(2)!.trim();
        final rMarker = pm.group(3) ?? pm.group(4)!;
        final rText = pm.group(5)!.trim();
        b.write('<tr>');
        b.write('<td><b>$lMarker.</b> ${formatInlineMarkdown(lText)}</td>');
        b.write('<td><b>($rMarker)</b> ${formatInlineMarkdown(rText)}</td>');
        b.write('</tr>');
      }
      b.write('</tbody></table>');
      if (afterText.isNotEmpty) {
        b.write('<div class="match-conclusion">${formatInlineMarkdown(afterText)}</div>');
      }
      b.write('</div>');
      return b.toString();
    }


    // 2C. Check Match-The-Following Type 3: Alternating Pairs (e.g. A. X i. Y B. Z ii. W or (A) X (i) Y)
    final matchItems = RegExp(
      r'(?:^|[\s\.\:\-।;,])(?:\(([A-Za-z0-9]+|[i-vI-V]+)\)|([A-Za-z0-9]+|[i-vI-V]+)[\.\)])\s*(.+?)(?=(?:[\s\.\:\-।;,](?:\([A-Za-z0-9]+|[i-vI-V]+\)|[A-Za-z0-9]+[\.\)]))|$)',
      dotAll: true,
    ).allMatches(text).toList();

    if (matchItems.length >= 4) {
      final markers = <String>[];
      final texts = <String>[];
      final rawMarkers = <String>[];
      for (final m in matchItems) {
        rawMarkers.add((m.group(1) ?? m.group(2))!.trim());
        final cleanMarker = m.group(1) != null ? '(${m.group(1)})' : '${m.group(2)}.';
        markers.add(cleanMarker);
        texts.add(m.group(3)!.trim());
      }
      final evenRaw = [for (int i = 0; i < rawMarkers.length; i += 2) rawMarkers[i]];
      final oddRaw = [for (int i = 1; i < rawMarkers.length; i += 2) rawMarkers[i]];

      bool isAlternatingMatch = false;
      for (final s1 in ['alpha', 'digit', 'roman']) {
        for (final s2 in ['alpha', 'digit', 'roman']) {
          if (s1 != s2 && _checkSequentialList(evenRaw, s1) && _checkSequentialList(oddRaw, s2)) {
            isAlternatingMatch = true;
            break;
          }
        }
        if (isAlternatingMatch) break;
      }

      if (isMatchStem && isAlternatingMatch && evenRaw.length == oddRaw.length) {
        final firstStart = matchItems.first.start;
        final intro = firstStart > 0 ? text.substring(0, firstStart).trim() : '';
        var lastRightText = texts.last;
        String? matchConclusion;
        final cm = conclusionPattern.firstMatch(lastRightText);
        if (cm != null) {
          lastRightText = cm.group(1)!.trim().replaceAll(RegExp(r'[\s:\-–—ः.\*]+$'), '').trim();
          matchConclusion = cm.group(2)!.trim();
        }

        final b = StringBuffer();
        b.write('<div class="match-table-wrapper">');
        if (intro.isNotEmpty) {
          b.write('<div class="match-intro">${formatInlineMarkdown(intro)}</div>');
        }
        b.write('<table class="match-table"><thead><tr>');
        b.write('<th>स्तम्भ I / सूची A</th><th>स्तम्भ II / सूची B</th>');
        b.write('</tr></thead><tbody>');
        for (int i = 0; i < evenRaw.length; i++) {
          final lMarker = markers[i * 2];
          final lText = texts[i * 2];
          final rMarker = (i * 2 + 1 < markers.length) ? markers[i * 2 + 1] : '';
          final rText = (i == evenRaw.length - 1) ? lastRightText : (i * 2 + 1 < texts.length ? texts[i * 2 + 1] : '');
          b.write('<tr>');
          b.write('<td><b>$lMarker</b> ${formatInlineMarkdown(lText)}</td>');
          b.write('<td><b>$rMarker</b> ${formatInlineMarkdown(rText)}</td>');
          b.write('</tr>');
        }
        b.write('</tbody></table>');
        if (matchConclusion != null && matchConclusion.isNotEmpty) {
          b.write('<div class="match-conclusion">${formatInlineMarkdown(matchConclusion)}</div>');
        }
        b.write('</div>');
        return b.toString();
      }
    }

    // 3. Check Explicit Multi-Statement (कथन (A), कथन (B) or Statement (A), Statement (B))
    final explicitStmtMatches = RegExp(
      r'(?:^|[\s\.\:\-])(कथन\s*\(([A-Za-z0-9]+)\)|कथन\s*([A-Za-z0-9]+)|Statement\s*\(([A-Za-z0-9]+)\)|Statement\s*([A-Za-z0-9]+))\s*[:\-–—\.]\s*',
      caseSensitive: false,
    ).allMatches(text).toList();

    if (explicitStmtMatches.length >= 2) {
      final intro = text.substring(0, explicitStmtMatches[0].start).trim();
      final statements = <({String marker, String text})>[];
      for (int i = 0; i < explicitStmtMatches.length; i++) {
        final sm = explicitStmtMatches[i];
        final marker = sm.group(1)!.trim();
        final start = sm.end;
        final end = i + 1 < explicitStmtMatches.length ? explicitStmtMatches[i + 1].start : text.length;
        final sText = text.substring(start, end).trim();
        statements.add((marker: marker, text: sText));
      }
      String? conclusion;
      final last = statements.removeLast();
      final cm = conclusionPattern.firstMatch(last.text);
      if (cm != null) {
        statements.add((marker: last.marker, text: cm.group(1)!.trim()));
        conclusion = cm.group(2)!.trim();
      } else {
        statements.add(last);
      }

      if (statements.length == 2) {
        // Structured cards for 2 statements (e.g. कथन (A) & कथन (B))
        final b = StringBuffer();
        b.write('<div class="kathan-wrapper">');
        if (intro.isNotEmpty) {
          b.write('<div class="kathan-intro">${formatInlineMarkdown(intro)}</div>');
        }
        b.write('''
          <div class="kathan-box assertion-box">
            <span class="kathan-tag tag-a">${statements[0].marker}</span>
            <div class="kathan-body">${formatInlineMarkdown(statements[0].text)}</div>
          </div>
          <div class="kathan-box reason-box">
            <span class="kathan-tag tag-r">${statements[1].marker}</span>
            <div class="kathan-body">${formatInlineMarkdown(statements[1].text)}</div>
          </div>
        ''');
        if (conclusion != null && conclusion.isNotEmpty) {
          b.write('<div class="kathan-conclusion">${formatInlineMarkdown(conclusion)}</div>');
        }
        b.write('</div>');
        return b.toString();
      } else {
        // Multi-statement list rows for 3 or more statements
        final b = StringBuffer();
        b.write('<div class="multi-statement-wrapper">');
        if (intro.isNotEmpty) {
          b.write('<div class="stmt-intro">${formatInlineMarkdown(intro)}</div>');
        }
        b.write('<div class="stmt-list">');
        for (final st in statements) {
          b.write('''
            <div class="stmt-row">
              <span class="stmt-marker">${st.marker}</span>
              <span class="stmt-text">${formatInlineMarkdown(st.text)}</span>
            </div>
          ''');
        }
        b.write('</div>');
        if (conclusion != null && conclusion.isNotEmpty) {
          b.write('<div class="stmt-conclusion">${formatInlineMarkdown(conclusion)}</div>');
        }
        b.write('</div>');
        return b.toString();
      }
    }

    // 4. Check Assertion-Reason (अभिकथन एवं कारण / दावा एवं तर्क)
    // Strictly requires Assertion word OR (A) WITH Reason word OR (R).
    // NEVER triggers on Match stems!
    if (!isMatchStem) {
      final arPattern = RegExp(
        r'^(.*?)(?:^|[\s–—\-:ः।;,])(अभिकथन(?:\s*\([A-Za-z0-9]\))?|दावा(?:\s*\([A-Za-z0-9]\))?|कथनम्(?:\s*\([A-Za-z0-9]\))?|Assertion(?:\s*\([A-Za-z0-9]\))?|\(A\))\s*[:\-–—ः.]\s*(.*?)(?:^|[\s–—\-:ः।;,])(कारण(?:\s*\([A-Za-z0-9]\))?|तर्क(?:\s*\([A-Za-z0-9]\))?|कारणम्(?:\s*\([A-Za-z0-9]\))?|व्याख्या(?:\s*\([A-Za-z0-9]\))?|प्रभाव(?:\s*\([A-Za-z0-9]\))?|Reason(?:\s*\([A-Za-z0-9]\))?|Explanation(?:\s*\([A-Za-z0-9]\))?|Effect(?:\s*\([A-Za-z0-9]\))?|\(R\))\s*[:\-–—ः.]\s*(.*?)$',
        caseSensitive: false,
        dotAll: true,
      );

      final arMatch = arPattern.firstMatch(text);
      if (arMatch != null) {
        final intro = arMatch.group(1)?.trim();
        var aLabel = arMatch.group(2)!.trim();
        var aText = arMatch.group(3)!.trim().replaceAll(RegExp(r'^[\s:\-–—ः.\*]+'), '').trim();
        var rLabel = arMatch.group(4)!.trim();
        var rText = arMatch.group(5)!.trim().replaceAll(RegExp(r'^[\s:\-–—ः.\*]+'), '').trim();
        String? conclusion;

        if (aLabel == '(A)' || aLabel == 'A') aLabel = 'अभिकथन (A)';
        if (rLabel == '(R)' || rLabel == 'R') rLabel = 'कारण (R)';

        final cm = conclusionPattern.firstMatch(rText);
        if (cm != null) {
          rText = cm.group(1)!.trim().replaceAll(RegExp(r'[\s:\-–—ः.\*]+$'), '').trim();
          conclusion = cm.group(2)!.trim();
        }

        if (aText.isNotEmpty && rText.isNotEmpty) {
          final isVyakhyan = RegExp(r'व्याख्या|प्रभाव|Explanation|Effect', caseSensitive: false).hasMatch(rLabel);
          final rTagClass = isVyakhyan ? 'tag-v' : 'tag-r';
          final rBoxClass = isVyakhyan ? 'vyakhyan-box' : 'reason-box';

          final b = StringBuffer();
          b.write('<div class="kathan-wrapper">');
          if (intro != null && intro.isNotEmpty) {
            b.write('<div class="kathan-intro">${formatInlineMarkdown(intro)}</div>');
          }
          b.write('''
            <div class="kathan-box assertion-box">
              <span class="kathan-tag tag-a">$aLabel</span>
              <div class="kathan-body">${formatInlineMarkdown(aText)}</div>
            </div>
            <div class="kathan-box $rBoxClass">
              <span class="kathan-tag $rTagClass">$rLabel</span>
              <div class="kathan-body">${formatInlineMarkdown(rText)}</div>
            </div>
          ''');
          if (conclusion != null && conclusion.isNotEmpty) {
            b.write('<div class="kathan-conclusion">${formatInlineMarkdown(conclusion)}</div>');
          }
          b.write('</div>');
          return b.toString();
        }
      }
    }

    // 4B. Check Inline Statement Evaluation (e.g. कथनों को पढ़िए / विचार कीजिए ... (i), (ii) or I., II.)
    final hasStmtIntro = RegExp(r'(?:कथन|कथनों|विचार|पढ़िए|सत्य|सही|गलत|कूट|निम्नलिखित|निम्न|Statement|Statements|Consider|Following|Which)', caseSensitive: false).hasMatch(text);
    if (hasStmtIntro) {
      // 4B-1: Parenthesized markers: (i), (ii), (iii) or (1), (2) or (A), (B)
      final allMatches = RegExp(r'(?:^|[\s\.\:\-–—।;,])\(((?:[A-Ea-e]|[i-vI-V]+|[1-9]))\)\s*').allMatches(text).toList();
      if (allMatches.length >= 2) {
        // Group matches into strictly increasing sequential chains
        final candidates = <List<RegExpMatch>>[];
        List<RegExpMatch> currentSeq = [];

        for (int i = 0; i < allMatches.length; i++) {
          final m = allMatches[i];
          final marker = m.group(1)!;

          if (currentSeq.isEmpty) {
            currentSeq.add(m);
          } else {
            final prevMarker = currentSeq.last.group(1)!;
            if (_isDirectSuccessor(prevMarker, marker)) {
              currentSeq.add(m);
            } else {
              if (currentSeq.length >= 2) {
                candidates.add(List.from(currentSeq));
              }
              currentSeq = [m];
            }
          }
        }
        if (currentSeq.length >= 2) {
          candidates.add(List.from(currentSeq));
        }

        if (candidates.isNotEmpty) {
          // Select the best candidate sequence:
          // In questions where intro says "कथन (A) तथा (B)", the true statement body comes after with substantive text!
          List<RegExpMatch> bestCandidate = candidates.last;
          for (int i = candidates.length - 1; i >= 0; i--) {
            final cand = candidates[i];
            int totalLen = 0;
            for (int j = 0; j < cand.length; j++) {
              final start = cand[j].end;
              final end = (j + 1 < cand.length) ? cand[j + 1].start : text.length;
              totalLen += (end - start);
            }
            final avgLen = totalLen / cand.length;
            if (avgLen > 4) {
              bestCandidate = cand;
              break;
            }
          }

          final intro = text.substring(0, bestCandidate.first.start).trim();
          final statements = <({String marker, String text})>[];
          for (int i = 0; i < bestCandidate.length; i++) {
            final sm = bestCandidate[i];
            final marker = '(${sm.group(1)})';
            final start = sm.end;
            final end = i + 1 < bestCandidate.length ? bestCandidate[i + 1].start : text.length;
            final sText = text.substring(start, end).trim();
            statements.add((marker: marker, text: sText));
          }
          String? conclusion;
          final last = statements.removeLast();
          final cm = conclusionPattern.firstMatch(last.text);
          if (cm != null) {
            statements.add((marker: last.marker, text: cm.group(1)!.trim()));
            conclusion = cm.group(2)!.trim();
          } else {
            statements.add(last);
          }

          final b = StringBuffer();
          b.write('<div class="multi-statement-wrapper">');
          if (intro.isNotEmpty) {
            b.write('<div class="stmt-intro">${formatInlineMarkdown(intro)}</div>');
          }
          b.write('<div class="stmt-list">');
          for (final st in statements) {
            b.write('''
              <div class="stmt-row">
                <span class="stmt-marker">${st.marker}</span>
                <span class="stmt-text">${formatInlineMarkdown(st.text)}</span>
              </div>
            ''');
          }
          b.write('</div>');
          if (conclusion != null && conclusion.isNotEmpty) {
            b.write('<div class="stmt-conclusion">${formatInlineMarkdown(conclusion)}</div>');
          }
          b.write('</div>');
          return b.toString();
        }
      }

      // 4B-2: Dot-notation markers: I. II. III. or 1. 2. 3. or A. B. C.
      final dotMatches = RegExp(r'(?:^|[\s\.\:\-–—।;,])((?:[i-vI-V]{1,4}|[1-9]|[A-Ea-e]))[\.\)]\s+').allMatches(text).toList();
      if (dotMatches.length >= 2) {
        final mVals = dotMatches.map((m) => m.group(1)!.toUpperCase()).toList();
        final isSeq = (mVals[0] == '1' && mVals[1] == '2') ||
            (mVals[0] == 'I' && mVals[1] == 'II') ||
            (mVals[0] == 'A' && mVals[1] == 'B');
        if (isSeq) {
          final intro = text.substring(0, dotMatches.first.start).trim();
          final statements = <({String marker, String text})>[];
          for (int i = 0; i < dotMatches.length; i++) {
            final sm = dotMatches[i];
            final marker = '${sm.group(1)}.';
            final start = sm.end;
            final end = i + 1 < dotMatches.length ? dotMatches[i + 1].start : text.length;
            final sText = text.substring(start, end).trim();
            statements.add((marker: marker, text: sText));
          }
          String? conclusion;
          final last = statements.removeLast();
          final cm = conclusionPattern.firstMatch(last.text);
          if (cm != null) {
            statements.add((marker: last.marker, text: cm.group(1)!.trim()));
            conclusion = cm.group(2)!.trim();
          } else {
            statements.add(last);
          }

          final b = StringBuffer();
          b.write('<div class="multi-statement-wrapper">');
          if (intro.isNotEmpty) {
            b.write('<div class="stmt-intro">${formatInlineMarkdown(intro)}</div>');
          }
          b.write('<div class="stmt-list">');
          for (final st in statements) {
            b.write('''
              <div class="stmt-row">
                <span class="stmt-marker">${st.marker}</span>
                <span class="stmt-text">${formatInlineMarkdown(st.text)}</span>
              </div>
            ''');
          }
          b.write('</div>');
          if (conclusion != null && conclusion.isNotEmpty) {
            b.write('<div class="stmt-conclusion">${formatInlineMarkdown(conclusion)}</div>');
          }
          b.write('</div>');
          return b.toString();
        }
      }
    }

    // 4C. Check Newline-separated Multi-Statement (only if statements start on separate lines)
    if (text.contains('\n')) {
      final lines = text.split('\n');
      final markerRegex = RegExp(r'^(?:\((?:[A-Ea-e]|[i-v]+|[1-9])\)|(?:[A-Ea-e]|[i-vI-V]+|[1-9])[\.\)])\s*[:\-–—]?\s*(.*)$');
      final statements = <({String marker, String text})>[];
      final introLines = <String>[];
      bool insideList = false;

      for (final l in lines) {
        final trimmed = l.trim();
        final m = markerRegex.firstMatch(trimmed);
        if (m != null) {
          insideList = true;
          statements.add((marker: m.group(0)!.split(RegExp(r'\s+')).first, text: m.group(1)!.trim()));
        } else if (insideList && statements.isNotEmpty) {
          final last = statements.removeLast();
          statements.add((marker: last.marker, text: '${last.text} $trimmed'.trim()));
        } else {
          introLines.add(trimmed);
        }
      }

      if (statements.length >= 2) {
        final intro = introLines.where((s) => s.isNotEmpty).join('<br>');
        String? conclusion;
        final last = statements.removeLast();
        final cm = conclusionPattern.firstMatch(last.text);
        if (cm != null) {
          statements.add((marker: last.marker, text: cm.group(1)!.trim()));
          conclusion = cm.group(2)!.trim();
        } else {
          statements.add(last);
        }

        final b = StringBuffer();
        b.write('<div class="multi-statement-wrapper">');
        if (intro.isNotEmpty) {
          b.write('<div class="stmt-intro">${formatInlineMarkdown(intro)}</div>');
        }
        b.write('<div class="stmt-list">');
        for (final st in statements) {
          b.write('''
            <div class="stmt-row">
              <span class="stmt-marker">${st.marker}</span>
              <span class="stmt-text">${formatInlineMarkdown(st.text)}</span>
            </div>
          ''');
        }
        b.write('</div>');
        if (conclusion != null && conclusion.isNotEmpty) {
          b.write('<div class="stmt-conclusion">${formatInlineMarkdown(conclusion)}</div>');
        }
        b.write('</div>');
        return b.toString();
      }
    }

    // 5. Default: Paragraph / Multi-line preservation
    // (Replace \n with <br> AFTER escaping/markdown — otherwise the tags
    // render as literal "&lt;br&gt;" text.)
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    if (paragraphs.length > 1) {
      return paragraphs.map((p) => '<div class="stem-p">${formatInlineMarkdown(p).replaceAll('\n', '<br>')}</div>').join('\n');
    }

    return '<div class="stem-p">${formatInlineMarkdown(text).replaceAll('\n', '<br>')}</div>';
  }

  /// Builds the complete HTML test booklet from a [TestSession]
  static String buildHtml(TestSession session) {
    final questions = session.questions;
    final passages = session.passages;
    final totalQs = questions.length;
    final examCode = session.config.exam.toLowerCase();
    final isUtet = examCode.contains('utet');
    final isPaper2 = examCode.contains('2') || ExamService.instance.selectedPaper == 2;

    final boardAuthHi = isUtet
        ? 'उत्तराखण्ड शिक्षक पात्रता परीक्षा (UTET) अभ्यास टेस्ट'
        : 'केन्द्रीय शिक्षक पात्रता परीक्षा (CTET) अभ्यास टेस्ट';
    final boardAuthEn = isUtet
        ? 'UTTARAKHAND TEACHER ELIGIBILITY TEST PRACTICE'
        : 'CENTRAL TEACHER ELIGIBILITY TEST PRACTICE';

    // Prioritize session.setCode, fallback to seed-derived char
    final setCode = session.setCode ?? String.fromCharCode(65 + ((session.config.seed.abs()) % 4));

    // Prioritize session.paperTitle, fallback to localized standard name
    final title = session.paperTitle ?? (isUtet
        ? (isPaper2 ? 'यूटीईटी (UTET) — उच्च प्राथमिक स्तर पेपर II' : 'यूटीईटी (UTET) — प्राथमिक स्तर पेपर I')
        : (isPaper2 ? 'सीटीईटी (CTET) — उच्च प्राथमिक स्तर पेपर II' : 'सीटीईटी (CTET) — प्राथमिक स्तर पेपर I'));

    final paperCoverSubtitle = isPaper2
        ? 'द्वितीय प्रश्न-पत्र (PAPER – II) · उच्च प्राथमिक स्तर (कक्षा 6 से 8)'
        : 'प्रथम प्रश्न-पत्र (PAPER – I) · प्राथमिक स्तर (कक्षा 1 से 5)';

    // Metadata for JS (String keys required for standard jsonEncode)
    final ansKey = <String, int>{};
    final sectionMap = <String, String>{};
    final topicMap = <String, String>{};
    final passagesDict = <String, Map<String, String>>{};
    final renderedPassages = <String>{};

    final l1Name = ExamService.instance.lang1LabelHindi;
    final l1NameEn = ExamService.instance.lang1LabelEnglish;
    final l2Name = ExamService.instance.lang2LabelHindi;
    final l2NameEn = ExamService.instance.lang2LabelEnglish;

    // Define sections based on exam and Paper 1 vs Paper 2
    final sectionsDef = isPaper2
        ? [
            [1, 30, 'भाग I : बाल विकास एवं शिक्षण विज्ञान', 'PART I : Child Development and Pedagogy'],
            [31, 60, 'भाग II : भाषा प्रथम – $l1Name', 'PART II : Language I – $l1NameEn'],
            [61, 90, 'भाग III : भाषा द्वितीय – $l2Name', 'PART III : Language II – $l2NameEn'],
            [91, 150, 'भाग IV : गणित एवं विज्ञान / सामाजिक अध्ययन (60 प्रश्न)', 'PART IV : Mathematics & Science / Social Studies (60 Questions)'],
          ]
        : (isUtet
            ? [
                [1, 30, 'भाग I : बाल विकास एवं शिक्षण विज्ञान', 'PART I : Child Development and Pedagogy'],
                [31, 60, 'भाग II : भाषा प्रथम – $l1Name', 'PART II : Language I – $l1NameEn'],
                [61, 90, 'भाग III : भाषा द्वितीय – $l2Name', 'PART III : Language II – $l2NameEn'],
                [91, 120, 'भाग IV : गणित', 'PART IV : Mathematics'],
                [121, 150, 'भाग V : पर्यावरण अध्ययन', 'PART V : Environmental Studies'],
              ]
            : [
                [1, 30, 'भाग I : बाल विकास एवं शिक्षाशास्त्र', 'PART I : Child Development and Pedagogy'],
                [31, 60, 'भाग II : गणित', 'PART II : Mathematics'],
                [61, 90, 'भाग III : पर्यावरण अध्ययन', 'PART III : Environmental Studies'],
                [91, 120, 'भाग IV : भाषा I – $l1Name', 'PART IV : Language I – $l1NameEn'],
                [121, 150, 'भाग V : भाषा II – $l2Name', 'PART V : Language II – $l2NameEn'],
              ]);

    String getSectionTitle(int qNum) {
      for (final s in sectionsDef) {
        final start = s[0] as int;
        final end = s[1] as int;
        if (qNum >= start && qNum <= end) {
          return s[2] as String;
        }
      }
      return 'सामान्य';
    }

    final h = StringBuffer();
    h.writeln('<!DOCTYPE html>');
    h.writeln('<html lang="hi">');
    h.writeln('<head>');
    h.writeln('  <meta charset="utf-8">');
    h.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">');
    h.writeln('  <title>${escape(title)} — रियल-टाइम टेस्ट बुकलेट</title>');
    h.writeln('  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">');
    h.writeln('  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>');
    h.writeln('  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/contrib/auto-render.min.js" onload="try{renderMathInElement(document.body);}catch(e){}"></script>');
    h.writeln('  <style>$_cssContent</style>');
    h.writeln('</head>');
    h.writeln('<body>');

    // CBT Control Bar (Ultra-responsive single-row sticky header)
    h.writeln('''
    <header class="cbt-bar">
      <div class="cbt-main-row">
        <!-- Left: Live Timer -->
        <div class="cbt-left">
          <div id="timer-box" title="समय शेष (Time Remaining)">
            <span class="t-icon">⏱️</span>
            <span id="timer-val">02:30:00</span>
          </div>
        </div>

        <!-- Center: Live Question Counter -->
        <div class="cbt-center">
          <div class="cbt-pill count-pill" title="हल किए गए प्रश्न">
            <span class="pill-dot ok-dot"></span>
            <span><span class="count-label">हल:&nbsp;</span><b id="stat-answered">${session.selectedAnswers.length}</b>/<span id="stat-total">$totalQs</span></span>
          </div>
          <div class="cbt-pill rev-pill hide-on-mobile" title="समीक्षा हेतु प्रश्न">
            <span class="pill-dot rev-dot"></span>
            <span>समीक्षा:&nbsp;<b id="stat-review">${session.markedForReview.length}</b></span>
          </div>
        </div>

        <!-- Right: Action Buttons -->
        <div class="cbt-right" id="cbt-actions">
          <button class="cbt-btn cbt-btn-omr" onclick="openOMR()" title="OMR शीट">
            <span>📝</span><span class="btn-text">OMR</span>
          </button>
          <button class="cbt-btn cbt-btn-palette" onclick="togglePalette()" title="प्रश्न पैलेट">
            <span>📑</span><span class="btn-text">पैलेट</span>
          </button>
          <button class="cbt-btn cbt-btn-primary" onclick="submitTest(false)" title="परीक्षा समाप्त करें">
            <span>🏁</span><span class="btn-text">समाप्त</span>
          </button>
          <button class="cbt-btn cbt-btn-exit" onclick="requestExitTest()" title="परीक्षा से बाहर निकलें">
            <span>✕</span>
          </button>
        </div>
      </div>
      <!-- Sub-row: Language Switcher -->
      <div class="cbt-subbar">
        <div class="cbt-lang-switcher">
          <button class="lang-pill-btn active" id="btn-lang-hi" onclick="setLangFilter('hi')">🇮🇳 केवल हिन्दी</button>
          <button class="lang-pill-btn" id="btn-lang-both" onclick="setLangFilter('both')">🌐 दोनों (Bilingual)</button>
          <button class="lang-pill-btn" id="btn-lang-en" onclick="setLangFilter('en')">🇬🇧 Only English</button>
        </div>
      </div>
    </header>

    <!-- Slide-down Question Palette Drawer (0px space when closed) -->
    <div class="palette-drawer" id="palette-drawer">
      <div class="palette-drawer-header">
        <b>📑 प्रश्न पैलेट (1-$totalQs) — सीधे प्रश्न पर जाएं:</b>
        <button class="palette-close-btn" onclick="closePalette()">✕ बंद करें</button>
      </div>
      <div class="palette-grid">
    ''');
    for (int n = 1; n <= totalQs; n++) {
      h.writeln('        <a id="pal-$n" href="javascript:void(0)" onclick="jumpToQuestion($n)">$n</a>');
    }
    h.writeln('''
      </div>
      <div class="palette-legend">
        <span><i style="background:#fff;border:1.5px solid #cbd5e1"></i>अनुत्तरित</span>
        <span><i style="background:var(--success)"></i>हल किया गया</span>
        <span><i style="background:var(--review)"></i>समीक्षा के लिए चिह्नित</span>
        <span><i style="background:linear-gradient(135deg,var(--success) 50%,var(--review) 50%)"></i>हल + समीक्षा</span>
      </div>
    </div>
    ''');

    // Booklet Main
    h.writeln('<main class="booklet-container">');

    // Authentic Cover Page
    h.writeln('''
    <section class="cover-page" id="booklet-cover">
      <div class="cover-header">
        <h2 class="cover-authority">$boardAuthHi</h2>
        <div class="cover-sub-auth">$boardAuthEn</div>
        <h1 class="cover-exam-title">${escape(title)}</h1>
        <div class="cover-exam-paper">$paperCoverSubtitle</div>
      </div>

      <div class="cover-meta-grid">
        <div class="cover-meta-box">
          <b>अनुक्रमांक (Roll No.)</b>
          <div class="roll-boxes">
            <div class="roll-digit-box">2</div>
            <div class="roll-digit-box">6</div>
            <div class="roll-digit-box">0</div>
            <div class="roll-digit-box">8</div>
            <div class="roll-digit-box">1</div>
            <div class="roll-digit-box">4</div>
            <div class="roll-digit-box">9</div>
            <div class="roll-digit-box">2</div>
          </div>
        </div>

        <div class="set-badge-box">
          <span>SET CODE</span>
          <b>$setCode</b>
        </div>

        <div class="cover-meta-box" style="text-align:right">
          <b>पुस्तिका संख्या (Booklet No.)</b>
          <div style="font-family:monospace;font-size:16px;font-weight:bold;letter-spacing:1px">TET-$setCode-${session.id.hashCode.abs() % 10000}</div>
        </div>
      </div>

      <div class="cover-time-marks">
        <span>समय : 2 घण्टे 30 मिनट (150 मिनट)</span>
        <span>पूर्णांक : $totalQs अंक ($totalQs प्रश्न)</span>
      </div>

      <div class="cover-instructions">
        <h4>परीक्षार्थियों के लिए महत्वपूर्ण निर्देश / IMPORTANT INSTRUCTIONS</h4>
        <ol>
          <li>इस प्रश्न-पुस्तिका में कुल $totalQs बहुविकल्पीय प्रश्न हैं। प्रत्येक प्रश्न 1 अंक का है।</li>
          <li>कोई ऋणात्मक अंकन (Negative Marking) नहीं है।</li>
          <li>प्रत्येक प्रश्न के चार वैकल्पिक उत्तर दिए गए हैं। सही विकल्प का चयन करें।</li>
          <li>परीक्षा प्रारंभ करने के लिए नीचे दिए गए बटन पर क्लिक करें।</li>
        </ol>
        <ol>
          <li>This question booklet contains $totalQs multiple choice questions. Each carries 1 mark.</li>
          <li>There is no negative marking for incorrect answers.</li>
          <li>Each question has four alternatives. Select the most appropriate option.</li>
          <li>Click the button below to begin the test and start the timer.</li>
        </ol>
      </div>

      <div class="start-test-action">
        <button class="start-btn" onclick="document.getElementById('qitem-1').scrollIntoView({behavior:'smooth'});">
          🚀 परीक्षा प्रारंभ करें
        </button>
      </div>
    </section>
    ''');

    // Questions Page
    h.writeln('<div class="paper-page">');

    for (int idx = 0; idx < questions.length; idx++) {
      final q = questions[idx];
      final qNum = idx + 1;
      final qNumStr = qNum.toString();
      ansKey[qNumStr] = q.answer;
      sectionMap[qNumStr] = getSectionTitle(qNum);
      topicMap[qNumStr] = q.topicName ?? 'सामान्य';

      // Check section boundary
      for (final s in sectionsDef) {
        final start = s[0] as int;
        final end = s[1] as int;
        if (qNum == start) {
          h.writeln('''
          <div class="section-banner">
            <h2>${s[2]}</h2>
            <small>${s[3]} · प्रश्न संख्या $start से $end</small>
          </div>
          ''');
        }
      }

      // Check passage
      final pid = q.passageId;
      if (pid != null && !renderedPassages.contains(pid) && passages.containsKey(pid)) {
        renderedPassages.add(pid);
        final passage = passages[pid]!;
        final isPoem = passage.isPoem;
        final icon = isPoem ? '📜' : '📖';
        final related = [
          for (int i = 0; i < questions.length; i++)
            if (questions[i].passageId == pid) i + 1
        ];
        final qRangeStr = related.isNotEmpty ? ' (प्रश्न ${related.first}–${related.last})' : '';
        final typeLabel = isPoem ? 'काव्यांश / कविता$qRangeStr' : 'अपठित गद्यांश$qRangeStr';
        final dirSplit = splitPassageDirections(passage.cleanBody, passage.displayDir);
        final formattedBody = isPoem ? formatPoemBody(dirSplit.body) : formatProseBody(dirSplit.body);

        passagesDict[pid] = {
          'kind': passage.kind,
          'dir': dirSplit.dir,
          'body': formattedBody,
        };

        h.writeln('''
        <div class="stimulus-wrapper" id="stimulus-$pid">
          <div class="stimulus-header ${isPoem ? 'poem-head' : ''}">
            <span>$icon</span>
            <span><b>$typeLabel</b> — ${escape(dirSplit.dir)}</span>
          </div>
          <div class="stimulus-content ${isPoem ? 'poem-body' : ''}">
            $formattedBody
          </div>
        </div>
        ''');
      }

      final isBilingual = q.isBilingual && (q.optionsEnglish?.length == 4);
      final optLetters = ['(1)', '(2)', '(3)', '(4)'];

      h.writeln('<div class="question-item" id="qitem-$qNum" data-qnum="$qNum">');

      if (isBilingual) {
        final optsHi = q.optionsHindi;
        final optsEn = q.optionsEnglish!;
        final maxLen = (optsHi + optsEn).fold<int>(0, (prev, e) => e.length > prev ? e.length : prev);
        final gridTwoClass = maxLen < 26 ? 'grid-two' : '';

        h.writeln('  <div class="q-bilingual-wrapper">');
        // 1. Desktop Dual-Column View (Screen width >= 769px)
        h.writeln('    <div class="bilingual-desktop-grid">');
        h.writeln('      <div class="q-column">');
        h.writeln('        <div class="q-header">');
        h.writeln('          <span class="q-num">$qNum.</span>');
        h.writeln('          <div class="q-stem">${formatQuestionStemHtml(q.qHindi)}</div>');
        h.writeln('        </div>');
        h.writeln('        <div class="options-list $gridTwoClass">');
        for (int i = 0; i < optsHi.length; i++) {
          h.writeln('          <div class="option-row" data-optidx="$i" onclick="selectOption($qNum, $i)">');
          h.writeln('            <span class="opt-badge">${optLetters[i]}</span>');
          h.writeln('            <span>${formatOptionHtml(optsHi[i])}</span>');
          h.writeln('          </div>');
        }
        h.writeln('        </div>');
        h.writeln('      </div>');

        h.writeln('      <div class="q-column">');
        h.writeln('        <div class="q-header">');
        h.writeln('          <span class="q-num">$qNum.</span>');
        h.writeln('          <div class="q-stem">${formatQuestionStemHtml(q.qEnglish ?? "")}</div>');
        h.writeln('        </div>');
        h.writeln('        <div class="options-list $gridTwoClass">');
        for (int i = 0; i < optsEn.length; i++) {
          h.writeln('          <div class="option-row" data-optidx="$i" onclick="selectOption($qNum, $i)">');
          h.writeln('            <span class="opt-badge">${optLetters[i]}</span>');
          h.writeln('            <span>${formatOptionHtml(optsEn[i])}</span>');
          h.writeln('          </div>');
        }
        h.writeln('        </div>');
        h.writeln('      </div>');
        h.writeln('    </div>');

        // 2. Mobile Unified Stack (< 769px: Single question + translation + 1 set of options)
        h.writeln('    <div class="bilingual-mobile-stack">');
        h.writeln('      <div class="q-header">');
        h.writeln('        <span class="q-num">$qNum.</span>');
        h.writeln('        <div class="q-stem q-stem-hi-text">${formatQuestionStemHtml(q.qHindi)}</div>');
        h.writeln('      </div>');
        if (q.qEnglish != null && q.qEnglish!.trim().isNotEmpty) {
          h.writeln('      <div class="q-stem-translation">');
          h.writeln('        <span class="lang-tag">EN</span>');
          h.writeln('        <div class="q-stem-en-body">${formatQuestionStemHtml(q.qEnglish!)}</div>');
          h.writeln('      </div>');
        }
        h.writeln('      <div class="options-list $gridTwoClass">');
        for (int i = 0; i < optsHi.length; i++) {
          final hiText = optsHi[i];
          final enText = (i < optsEn.length) ? optsEn[i] : '';
          final hasDistinctEn = enText.trim().isNotEmpty && enText.trim() != hiText.trim();
          h.writeln('        <div class="option-row" data-optidx="$i" onclick="selectOption($qNum, $i)">');
          h.writeln('          <span class="opt-badge">${optLetters[i]}</span>');
          h.writeln('          <div class="opt-content">');
          h.writeln('            <span class="opt-primary">${formatOptionHtml(hiText)}</span>');
          if (hasDistinctEn) {
            h.writeln('            <span class="opt-secondary">${formatOptionHtml(enText)}</span>');
          }
          h.writeln('          </div>');
          h.writeln('        </div>');
        }
        h.writeln('      </div>');
        h.writeln('    </div>');
        h.writeln('  </div>');
      } else {
        final stem = q.qHindi.isNotEmpty ? q.qHindi : (q.qEnglish ?? '');
        final opts = q.optionsHindi.isNotEmpty ? q.optionsHindi : (q.optionsEnglish ?? []);
        final maxLen = opts.fold<int>(0, (prev, e) => e.length > prev ? e.length : prev);
        final gridTwoClass = maxLen < 30 ? 'grid-two' : '';

        h.writeln('  <div class="q-grid-mono">');
        h.writeln('    <div class="q-column">');
        h.writeln('      <div class="q-header">');
        h.writeln('        <span class="q-num">$qNum.</span>');
        h.writeln('        <div class="q-stem">${formatQuestionStemHtml(stem)}</div>');
        h.writeln('      </div>');
        h.writeln('      <div class="options-list $gridTwoClass">');
        for (int i = 0; i < opts.length; i++) {
          h.writeln('        <div class="option-row" data-optidx="$i" onclick="selectOption($qNum, $i)">');
          h.writeln('          <span class="opt-badge">${optLetters[i]}</span>');
          h.writeln('          <span>${formatOptionHtml(opts[i])}</span>');
          h.writeln('        </div>');
        }
        h.writeln('      </div>');
        h.writeln('    </div>');
        h.writeln('  </div>');
      }

      // Footer
      h.writeln('  <div class="q-footer">');
      h.writeln('    <div class="q-meta-tags">');
      h.writeln('      <span class="q-topic-tag">🏷️ ${escape(q.topicName ?? 'सामान्य')}</span>');
      if (pid != null && passages.containsKey(pid)) {
        h.writeln('      <button class="q-peek-btn" onclick="showPassageModal(\'$pid\')">📖 गद्यांश/पद्यांश देखें</button>');
      }
      h.writeln('    </div>');
      h.writeln('    <div class="q-btn-group">');
      h.writeln('      <button class="q-rev-btn" id="rev-btn-$qNum" onclick="toggleReview($qNum)">⭐ समीक्षा के लिए रखें</button>');
      h.writeln('      <button class="q-report-btn" onclick="openReportModal(\'${escape(q.id)}\', $qNum)">🚩 रिपोर्ट</button>');
      h.writeln('    </div>');
      h.writeln('  </div>');

      h.writeln('  <div class="result-mark" id="mark-$qNum"></div>');
      h.writeln('</div>');

      if (qNum % 30 == 0 && qNum < totalQs) {
        h.writeln('<div class="pto-text">P. T. O. (कृपया पृष्ठ पलटिए)</div>');
      }
    }

    h.writeln('</div>'); // end paper-page
    h.writeln('</main>'); // end booklet-container

    // Floating Passage Modal
    h.writeln('''
    <div id="passage-modal">
      <div class="p-modal-head">
        <span id="p-modal-title">📖 संदर्भ सामग्री</span>
        <button class="p-modal-close" onclick="closePassageModal()">✕</button>
      </div>
      <div class="p-modal-body" id="p-modal-text"></div>
    </div>
    ''');

    // OMR Sheet Modal
    h.writeln('''
    <div id="omr-modal">
      <div class="omr-sheet-card">
        <div class="omr-head">
          <span style="font-weight:700">📝 वास्तविक OMR शीट व्यू (1-$totalQs प्रश्न)</span>
          <button class="p-modal-close" onclick="closeOMR()">✕</button>
        </div>
        <div class="omr-body">
    ''');
    for (int n = 1; n <= totalQs; n++) {
      h.writeln('''
          <div class="omr-row" id="omr-row-$n">
            <span class="omr-num">$n.</span>
            <div class="omr-bubbles">
              <span class="omr-bubble" onclick="selectOption($n, 0)">A</span>
              <span class="omr-bubble" onclick="selectOption($n, 1)">B</span>
              <span class="omr-bubble" onclick="selectOption($n, 2)">C</span>
              <span class="omr-bubble" onclick="selectOption($n, 3)">D</span>
            </div>
          </div>
      ''');
    }
    h.writeln('''
        </div>
      </div>
    </div>
    ''');

    // Confirmation Modal
    h.writeln('''
    <div id="confirm-modal">
      <div class="confirm-card">
        <h3>🏁 परीक्षा समाप्त करना चाहते हैं?</h3>
        <p>जमा करने के पश्चात आपका स्कोरकार्ड, सटीकता और सही उत्तर तुरंत प्रदर्शित होंगे।</p>
        <div class="confirm-stats">
          <div class="c-stat-box"><b>$totalQs</b><span>कुल प्रश्न</span></div>
          <div class="c-stat-box"><b style="color:var(--success)" id="cf-ans">0</b><span>हल किए</span></div>
          <div class="c-stat-box"><b style="color:var(--text-muted)" id="cf-left">$totalQs</b><span>शेष</span></div>
        </div>
        <div style="display:flex;gap:10px;justify-content:center">
          <button class="cbt-btn cbt-btn-secondary" style="color:#0f172a;border:1.5px solid #cbd5e1" onclick="closeConfirmModal()">नहीं, जारी रखें</button>
          <button class="cbt-btn cbt-btn-primary" onclick="executeSubmit(false)">हाँ, जमा करें</button>
        </div>
      </div>
    </div>
    ''');

    // Result Modal
    h.writeln('''
    <div id="result-modal">
      <div class="result-card">
        <div class="result-top-summary">
          <div class="score-circle" id="res-score">0<small>/$totalQs</small></div>
          <div class="verdict-tag" id="res-verdict">परिणाम</div>
          <p id="res-sub" style="margin:8px 0 0;font-size:14px;color:var(--text-muted)"></p>
        </div>

        <div class="kpi-grid">
          <div class="kpi-box"><b style="color:var(--success)" id="kpi-ok">0</b><span>सही उत्तर</span></div>
          <div class="kpi-box"><b style="color:var(--danger)" id="kpi-wrong">0</b><span>गलत उत्तर</span></div>
          <div class="kpi-box"><b style="color:var(--text-muted)" id="kpi-skip">0</b><span>छोड़े गए</span></div>
          <div class="kpi-box"><b id="kpi-pct">0%</b><span>प्राप्तांक प्रतिशत</span></div>
          <div class="kpi-box"><b id="kpi-acc">0%</b><span>सटीकता (Accuracy)</span></div>
          <div class="kpi-box"><b id="kpi-time">00:00</b><span>व्यतीत समय</span></div>
        </div>

        <h3 style="margin:16px 0 8px;font-size:16px;border-left:4px solid var(--accent);padding-left:10px">खण्डवार विस्तृत विश्लेषण (Sectional Performance)</h3>
        <table class="res-table" id="res-table-body"></table>

        <div class="weak-list" id="weak-section" style="display:none"></div>

        <div class="result-actions">
          <button class="cbt-btn cbt-btn-primary" onclick="closeResult()">🔍 प्रश्न-पत्र में उत्तर देखें</button>
          <button class="cbt-btn cbt-btn-secondary" style="background:#475569" onclick="toggleWrongOnly()">⚠️ केवल गलत/छोड़े गए देखें</button>
          <button class="cbt-btn cbt-btn-secondary" style="background:#0f172a" onclick="location.reload()">🔄 पुनः टेस्ट दें</button>
        </div>
      </div>
    </div>

    <!-- Question Error Report Modal -->
    <div id="report-modal">
      <div class="report-card">
        <div class="report-head">
          <span style="font-weight:700">🚩 प्रश्न <span id="rep-qnum">1</span> में त्रुटि रिपोर्ट करें</span>
          <button class="p-modal-close" onclick="closeReportModal()">✕</button>
        </div>
        <div class="report-body">
          <p style="font-size:13.5px;color:var(--text-muted);margin:0 0 12px">इस प्रश्न में क्या समस्या है? कृपया चुनें:</p>
          <div class="report-reasons">
            <label class="rep-radio-label">
              <input type="radio" name="rep-reason" value="उत्तर गलत है / Wrong Answer" checked>
              <span>❌ उत्तर गलत है (Wrong Answer)</span>
            </label>
            <label class="rep-radio-label">
              <input type="radio" name="rep-reason" value="अधूरा प्रश्न या विकल्प / Incomplete">
              <span>❓ अधूरा प्रश्न या विकल्प (Incomplete)</span>
            </label>
            <label class="rep-radio-label">
              <input type="radio" name="rep-reason" value="अनुवाद / वर्तनी त्रुटि / Translation/Typo">
              <span>🔤 अनुवाद / वर्तनी त्रुटि (Translation/Typo)</span>
            </label>
            <label class="rep-radio-label">
              <input type="radio" name="rep-reason" value="अन्य समस्या / Other Issue">
              <span>📑 अन्य समस्या (Other Issue)</span>
            </label>
          </div>
          <div style="margin-top:14px">
            <label style="font-size:12.5px;font-weight:600;display:block;margin-bottom:6px">अतिरिक्त टिप्पणी (वैकल्पिक / Optional):</label>
            <textarea id="rep-comment" placeholder="सही उत्तर क्या होना चाहिए या क्या सुधार होना चाहिए..." style="width:100%;box-sizing:border-box;border:1.5px solid #cbd5e1;border-radius:8px;padding:8px 10px;font-size:13px;resize:vertical;min-height:60px"></textarea>
          </div>
          <div style="display:flex;gap:10px;justify-content:flex-end;margin-top:16px">
            <button class="cbt-btn cbt-btn-secondary" style="color:#0f172a;border:1.5px solid #cbd5e1" onclick="closeReportModal()">रद्द करें</button>
            <button class="cbt-btn cbt-btn-primary" onclick="submitQuestionReport()">🚀 रिपोर्ट सबमिट करें</button>
          </div>
        </div>
      </div>
    </div>
    ''');

    // JS Engine injection
    final js = _jsEngine
        .replaceAll('__ANS_KEY__', jsonEncode(ansKey))
        .replaceAll('__SECTIONS__', jsonEncode(sectionMap))
        .replaceAll('__TOPICS__', jsonEncode(topicMap))
        .replaceAll('__TOTAL_QS__', totalQs.toString())
        .replaceAll('__PAPER_ID__', session.id)
        .replaceAll('__PASSAGES__', jsonEncode(passagesDict));

    h.writeln('<script>$js</script>');
    h.writeln('</body>');
    h.writeln('</html>');

    return h.toString();
  }

  static const String _cssContent = '''
:root {
  --primary: #0f172a;
  --primary-light: #1e293b;
  --accent: #2563eb;
  --accent-hover: #1d4ed8;
  --success: #16a34a;
  --success-bg: #dcfce7;
  --danger: #dc2626;
  --danger-bg: #fee2e2;
  --warning: #d97706;
  --warning-bg: #fef3c7;
  --review: #7c3aed;
  --review-bg: #ede9fe;
  --paper-bg: #ffffff;
  --booklet-bg: #f1f5f9;
  --text-main: #0f172a;
  --text-muted: #64748b;
  --border-color: #cbd5e1;
  --font-hindi: 'Noto Sans Devanagari', 'Nirmala UI', Mangal, -apple-system, sans-serif;
  --font-eng: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
}

* { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
html {
  scroll-behavior: smooth;
  width: 100%;
  max-width: 100%;
  overflow-x: hidden;
}
body {
  margin: 0;
  padding: 0;
  width: 100%;
  max-width: 100%;
  overflow-x: hidden;
  background-color: var(--booklet-bg);
  color: var(--text-main);
  font-family: var(--font-hindi);
  line-height: 1.6;
  font-size: 15px;
  -webkit-font-smoothing: antialiased;
}

.cbt-bar {
  position: -webkit-sticky;
  position: sticky;
  top: 0;
  left: 0;
  right: 0;
  z-index: 10000;
  background: rgba(15, 23, 42, 0.96);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  color: #fff;
  padding: max(6px, env(safe-area-inset-top)) 10px 6px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.25);
  border-bottom: 1px solid rgba(255,255,255,0.08);
  width: 100%;
  box-sizing: border-box;
}

.cbt-main-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  width: 100%;
  max-width: 980px;
  margin: 0 auto;
}

.cbt-left {
  display: flex;
  align-items: center;
  flex-shrink: 0;
}

#timer-box {
  height: 36px;
  background: #020617;
  border: 1.5px solid #334155;
  border-radius: 8px;
  padding: 0 10px;
  font-family: 'JetBrains Mono', 'Roboto Mono', monospace, var(--font-eng);
  font-variant-numeric: tabular-nums;
  font-size: 13.5px;
  font-weight: 700;
  color: #38bdf8;
  letter-spacing: 0.5px;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  white-space: nowrap;
  box-sizing: border-box;
}

#timer-box.timer-warning {
  background: #7f1d1d;
  border-color: #ef4444;
  color: #fff;
  animation: pulse-warn 1s infinite alternate;
}

@keyframes pulse-warn {
  0% { transform: scale(1); opacity: 1; }
  100% { transform: scale(1.03); opacity: 0.8; }
}

.cbt-center {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

.cbt-pill {
  height: 36px;
  background: rgba(255,255,255,0.08);
  border: 1px solid rgba(255,255,255,0.18);
  border-radius: 8px;
  padding: 0 10px;
  font-size: 12px;
  font-weight: 700;
  color: #f8fafc;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  white-space: nowrap;
  box-sizing: border-box;
}

.pill-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
.ok-dot { background: #22c55e; box-shadow: 0 0 6px rgba(34,197,94,0.6); }
.rev-dot { background: #a855f7; box-shadow: 0 0 6px rgba(168,85,247,0.6); }

.cbt-right {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

.cbt-btn {
  height: 36px;
  border: 0;
  border-radius: 8px;
  padding: 0 11px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s ease;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  white-space: nowrap;
  line-height: 1;
  box-sizing: border-box;
}

.cbt-btn-omr, .cbt-btn-palette {
  background: #1e293b;
  color: #f8fafc;
  border: 1.5px solid #475569;
}
.cbt-btn-omr:hover, .cbt-btn-palette:hover { background: #334155; border-color: #64748b; }

.cbt-btn-primary {
  background: #16a34a;
  color: #fff;
  border: 1.5px solid #22c55e;
  box-shadow: 0 2px 8px rgba(22, 163, 74, 0.35);
}
.cbt-btn-primary:hover { background: #15803d; }

.cbt-btn-secondary { background: rgba(255,255,255,0.14); color: #f8fafc; border: 1px solid rgba(255,255,255,0.28); }
.cbt-btn-secondary:hover { background: rgba(255,255,255,0.24); }

.cbt-btn-exit {
  background: rgba(239, 68, 68, 0.18);
  color: #fca5a5;
  border: 1.5px solid rgba(239, 68, 68, 0.45);
  width: 36px;
  padding: 0;
  font-size: 14px;
  font-weight: 900;
}
.cbt-btn-exit:hover { background: #dc2626; color: #fff; }

.palette-drawer {
  position: fixed;
  top: 45px;
  left: 0;
  right: 0;
  z-index: 999;
  background: #ffffff;
  border-bottom: none;
  box-shadow: none;
  max-height: 0;
  overflow: hidden;
  visibility: hidden;
  pointer-events: none;
  transition: max-height 0.25s cubic-bezier(0.4, 0, 0.2, 1), visibility 0.25s;
  box-sizing: border-box;
}
.palette-drawer.open {
  visibility: visible;
  pointer-events: auto;
  max-height: 380px;
  border-bottom: 2px solid #cbd5e1;
  box-shadow: 0 10px 25px rgba(0,0,0,0.18);
}
.palette-drawer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #f1f5f9;
  padding: 8px 14px;
  font-size: 12.5px;
  border-bottom: 1px solid #e2e8f0;
}
.palette-close-btn {
  background: transparent;
  border: 0;
  color: #dc2626;
  font-weight: 700;
  cursor: pointer;
  font-size: 12px;
}
.palette-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(36px, 1fr));
  gap: 5px;
  max-height: 250px;
  overflow-y: auto;
  padding: 10px 14px;
  box-sizing: border-box;
}
.palette-grid a {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 32px;
  border-radius: 6px;
  background: #fff;
  border: 1.5px solid #cbd5e1;
  color: #334155;
  text-decoration: none;
  font-size: 12px;
  font-weight: 700;
  transition: all 0.1s ease;
}
.palette-grid a:hover { border-color: var(--accent); }
.palette-grid a.answered { background: var(--success); color: #fff; border-color: #15803d; }
.palette-grid a.reviewed { background: var(--review); color: #fff; border-color: #6d28d9; }
.palette-grid a.ans-rev { background: linear-gradient(135deg, var(--success) 50%, var(--review) 50%); color: #fff; border-color: #4c1d95; }
.palette-grid a.wrong { background: var(--danger); color: #fff; border-color: #b91c1c; }
.palette-grid a.skipped { background: #94a3b8; color: #fff; border-color: #64748b; }

.palette-legend {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  padding: 8px 14px;
  font-size: 11.5px;
  color: var(--text-muted);
  border-top: 1px solid #e2e8f0;
  background: #f8fafc;
}
.palette-legend span { display: inline-flex; align-items: center; gap: 4px; }
.palette-legend i { width: 10px; height: 10px; border-radius: 2px; display: inline-block; }

.booklet-container {
  width: 100%;
  max-width: 960px;
  margin: 0 auto;
  background: var(--paper-bg);
  box-shadow: 0 2px 14px rgba(0,0,0,0.06);
  min-height: 100vh;
  box-sizing: border-box;
  overflow-x: hidden;
  padding-bottom: 60px;
}

.cover-page {
  padding: 24px 20px;
  border-bottom: 4px double #000;
  background: #fff;
  box-sizing: border-box;
  width: 100%;
}
.cover-header { text-align: center; margin-bottom: 14px; }
.cover-authority { font-size: 15px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: #111; margin: 0; }
.cover-sub-auth { font-size: 12px; color: #333; margin-top: 2px; }
.cover-exam-title { font-size: 21px; font-weight: 800; letter-spacing: 0.5px; margin: 10px 0 4px; color: #000; }
.cover-exam-paper { font-size: 14.5px; font-weight: 700; color: #444; }

.cover-meta-grid {
  display: grid;
  grid-template-columns: 1fr 110px 1fr;
  gap: 12px;
  align-items: center;
  border-top: 2px solid #000;
  border-bottom: 2px solid #000;
  padding: 12px 8px;
  margin: 14px 0;
  box-sizing: border-box;
  width: 100%;
}
.cover-meta-box { border: 1.5px solid #000; padding: 6px 10px; font-size: 12.5px; border-radius: 4px; box-sizing: border-box; }
.cover-meta-box b { display: block; font-size: 10.5px; text-transform: uppercase; color: #555; margin-bottom: 4px; }
.roll-boxes { display: flex; gap: 3px; flex-wrap: wrap; }
.roll-digit-box { width: 20px; height: 26px; border: 1px solid #333; display: flex; align-items: center; justify-content: center; font-family: monospace; font-size: 13.5px; font-weight: bold; box-sizing: border-box; }
.set-badge-box { border: 3px double #000; height: 68px; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; background: #fdfdfd; }
.set-badge-box span { font-size: 10px; font-weight: 700; text-transform: uppercase; }
.set-badge-box b { font-size: 28px; font-weight: 900; line-height: 1; }

.cover-time-marks { display: flex; justify-content: space-between; font-weight: 700; font-size: 13.5px; padding: 6px 4px; border-bottom: 1.5px solid #000; margin-bottom: 12px; }
.cover-instructions { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; font-size: 12px; line-height: 1.55; text-align: justify; box-sizing: border-box; width: 100%; }
.cover-instructions h4 { grid-column: 1 / -1; text-align: center; margin: 6px 0 4px; font-size: 14px; text-decoration: underline; }
.cover-instructions ol { margin: 0; padding-left: 18px; }
.cover-instructions li { margin-bottom: 4px; }

.start-test-action { text-align: center; margin-top: 20px; }
.start-btn {
  background: #0f172a;
  color: #fff;
  border: 0;
  padding: 11px 32px;
  font-size: 15px;
  font-weight: 700;
  border-radius: 30px;
  cursor: pointer;
  box-shadow: 0 4px 14px rgba(0,0,0,0.22);
  transition: all 0.2s;
}
.start-btn:hover { background: #1e293b; transform: translateY(-2px); }

.paper-page { padding: 18px 24px; box-sizing: border-box; width: 100%; }
.section-banner {
  background: #0f172a;
  color: #fff;
  text-align: center;
  padding: 10px 14px;
  margin: 20px 0 14px;
  border-radius: 6px;
  border-left: 5px solid var(--accent);
  box-sizing: border-box;
  width: 100%;
}
.section-banner h2 { margin: 0; font-size: 16.5px; font-weight: 700; letter-spacing: 0.5px; }
.section-banner small { display: block; font-size: 12px; color: #cbd5e1; margin-top: 2px; font-family: var(--font-eng); }

.stimulus-wrapper { margin: 18px 0 20px; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.04); box-sizing: border-box; width: 100%; }
.stimulus-header {
  background: #f1f5f9;
  border-left: 5px solid #2563eb;
  padding: 8px 14px;
  font-size: 13px;
  font-weight: 700;
  color: #1e293b;
  display: flex;
  align-items: center;
  gap: 8px;
}
.stimulus-header.poem-head { border-left-color: var(--review); background: #f5f3ff; color: #4c1d95; }
.stimulus-content { padding: 14px 18px; font-size: 14px; line-height: 1.75; border: 1px solid #e2e8f0; border-top: 0; background: #fdfdfb; box-sizing: border-box; width: 100%; }
.stimulus-content.poem-body { background: #fcfbfe; text-align: center; font-style: italic; font-size: 14.5px; line-height: 2; padding: 18px 20px; }
.poem-line { margin: 2px 0; }
.poem-stanza-gap { height: 14px; }
.prose-p { margin: 0 0 10px; text-indent: 24px; text-align: justify; }

.question-item {
  padding: 14px 0;
  border-bottom: 1px dotted #cbd5e1;
  scroll-margin-top: 56px;
  transition: background 0.2s;
  box-sizing: border-box;
  width: 100%;
}
.question-item:hover { background: #fafbfc; }
.question-item.done { border-left: 4px solid var(--success); padding-left: 8px; }

.q-grid-bilingual { display: grid; grid-template-columns: 1fr 1fr; gap: 0 24px; width: 100%; box-sizing: border-box; }
.q-grid-mono { display: grid; grid-template-columns: 1fr; width: 100%; box-sizing: border-box; }
.q-column { display: flex; flex-direction: column; width: 100%; box-sizing: border-box; }
.q-header { display: flex; gap: 8px; align-items: flex-start; width: 100%; }
.q-num { font-weight: 900; min-width: 30px; font-size: 16.5px; color: #000000; flex-shrink: 0; }
.q-stem { flex: 1; min-width: 0; font-size: 16px; font-weight: 600; color: #0f172a; line-height: 1.65; word-break: break-word; }
.stem-p { margin: 0 0 6px 0; line-height: 1.65; }
.stem-p:last-child { margin-bottom: 0; }
.kathan-wrapper { display: flex; flex-direction: column; gap: 8px; margin: 6px 0 8px; width: 100%; box-sizing: border-box; }
.kathan-intro { font-weight: 700; font-size: 15.5px; color: #0f172a; margin-bottom: 2px; line-height: 1.5; }
.kathan-box { display: flex; gap: 10px; align-items: flex-start; padding: 10px 14px; border-radius: 8px; background: #f8fafc; border-left: 4.5px solid #2563eb; box-shadow: 0 1px 3px rgba(0,0,0,0.04); box-sizing: border-box; width: 100%; }
.kathan-box.reason-box { border-left-color: #7c3aed; background: #faf5ff; }
.kathan-box.vyakhyan-box { border-left-color: #d97706; background: #fffbeb; }
.kathan-tag { font-weight: 800; font-size: 13.5px; padding: 3px 8px; border-radius: 5px; white-space: nowrap; flex-shrink: 0; }
.kathan-tag.tag-a { background: #dbeafe; color: #1d4ed8; }
.kathan-tag.tag-r { background: #ede9fe; color: #6d28d9; }
.kathan-tag.tag-v { background: #fef3c7; color: #b45309; }
.kathan-body { flex: 1; color: #0f172a; font-size: 15.5px; font-weight: 600; line-height: 1.55; }
.kathan-conclusion { font-weight: 700; font-size: 15.5px; color: #1e293b; margin-top: 6px; line-height: 1.5; padding: 6px 10px; background: #f1f5f9; border-radius: 6px; }

.q-blank {
  display: inline-block;
  min-width: 65px;
  border-bottom: 2.5px solid #0f172a;
  margin: 0 4px;
  vertical-align: baseline;
  line-height: 1;
}

.multi-statement-wrapper { display: flex; flex-direction: column; gap: 6px; margin: 4px 0 6px; width: 100%; box-sizing: border-box; }
.stmt-intro { font-weight: 700; font-size: 15.5px; color: #0f172a; margin-bottom: 2px; line-height: 1.5; }
.stmt-list { display: flex; flex-direction: column; gap: 5px; background: #f8fafc; padding: 8px 12px; border-radius: 6px; border: 1px solid #e2e8f0; width: 100%; box-sizing: border-box; }
.stmt-row { display: flex; gap: 8px; align-items: baseline; }
.stmt-marker { font-weight: 800; color: #1d4ed8; min-width: 24px; flex-shrink: 0; }
.stmt-text { flex: 1; color: #0f172a; font-size: 15.5px; font-weight: 600; line-height: 1.5; }
.stmt-conclusion { font-weight: 700; font-size: 15.5px; color: #1e293b; margin-top: 4px; line-height: 1.5; }
.q-table-wrapper { margin: 6px 0; overflow-x: auto; width: 100%; box-sizing: border-box; }
.q-table { width: 100%; border-collapse: collapse; font-size: 14.5px; font-weight: 600; margin: 6px 0; }
.q-table th, .q-table td { border: 1.5px solid #94a3b8; padding: 6px 10px; text-align: left; }
.q-table th { background: #e2e8f0; font-weight: 800; color: #0f172a; }
.q-table td { background: #ffffff; color: #0f172a; }

.match-table-wrapper { margin: 8px 0 10px; width: 100%; box-sizing: border-box; }
.match-intro { font-weight: 700; font-size: 15.5px; color: #0f172a; margin-bottom: 6px; line-height: 1.5; }
.match-table { width: 100%; border-collapse: collapse; font-size: 14.5px; font-weight: 600; margin: 4px 0 8px; border-radius: 8px; overflow: hidden; border: 1.5px solid #cbd5e1; }
.match-table th, .match-table td { border: 1px solid #cbd5e1; padding: 8px 12px; text-align: left; vertical-align: middle; }
.match-table th { background: #f1f5f9; font-weight: 800; color: #1e293b; font-size: 13.5px; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 2px solid #94a3b8; }
.match-table td { background: #ffffff; color: #0f172a; }
.match-table tr:nth-child(even) td { background: #f8fafc; }
.match-conclusion { font-weight: 700; font-size: 15.5px; color: #1e293b; margin-top: 6px; line-height: 1.5; padding: 6px 10px; background: #f1f5f9; border-radius: 6px; }

.q-pre {
  background: #0f172a;
  color: #38bdf8;
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  font-size: 14.5px;
  font-weight: 700;
  line-height: 1.45;
  padding: 10px 16px;
  border-radius: 8px;
  margin: 8px 0;
  display: inline-block;
  min-width: 140px;
  max-width: 100%;
  overflow-x: auto;
  border: 1px solid #334155;
  box-shadow: 0 2px 8px rgba(0,0,0,0.12);
  white-space: pre;
}

.m-frac { display: inline-flex; flex-direction: column; vertical-align: middle; text-align: center; padding: 0 2px; font-size: 0.95em; line-height: 1.1; font-weight: 700; }
.m-num { border-bottom: 1.5px solid currentColor; padding: 0 1px; }
.m-den { padding: 0 1px; }
.m-sqrt { border-top: 1.5px solid currentColor; padding: 0 2px; margin-left: 1px; }

.q-bilingual-wrapper { width: 100%; box-sizing: border-box; }
.bilingual-desktop-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0 24px; width: 100%; box-sizing: border-box; }
.bilingual-mobile-stack { display: none; width: 100%; box-sizing: border-box; }
.q-stem-translation {
  background: #f8fafc;
  border-left: 3.5px solid #64748b;
  border-radius: 6px;
  padding: 8px 12px;
  margin: 6px 0 10px 30px;
  font-size: 14.5px;
  color: #334155;
  line-height: 1.55;
  display: flex;
  gap: 8px;
  align-items: flex-start;
}
.lang-tag {
  background: #e2e8f0;
  color: #475569;
  font-size: 10px;
  font-weight: 800;
  padding: 2px 5px;
  border-radius: 4px;
  letter-spacing: 0.5px;
  flex-shrink: 0;
  margin-top: 2px;
}
.q-stem-en-body { flex: 1; }
.opt-content { display: flex; flex-direction: column; gap: 2px; flex: 1; min-width: 0; }
.opt-primary { color: #0f172a; font-weight: 600; font-size: 15.5px; line-height: 1.45; }
.opt-secondary { color: #64748b; font-weight: 500; font-size: 13.5px; line-height: 1.4; }
.option-row.selected .opt-secondary { color: #1e40af; }
.option-row.correct-ans .opt-secondary { color: #14532d; }
.option-row.wrong-ans .opt-secondary { color: #7f1d1d; }

/* Language Filter Modes */
body.lang-mode-hi .bilingual-desktop-grid .q-column:nth-child(2) {
  display: none !important;
}
body.lang-mode-hi .bilingual-desktop-grid {
  grid-template-columns: 1fr !important;
}
body.lang-mode-hi .q-stem-translation {
  display: none !important;
}
body.lang-mode-hi .opt-secondary {
  display: none !important;
}

body.lang-mode-en .bilingual-desktop-grid .q-column:nth-child(1) {
  display: none !important;
}
body.lang-mode-en .bilingual-desktop-grid {
  grid-template-columns: 1fr !important;
}
body.lang-mode-en .bilingual-mobile-stack .q-stem-hi-text {
  display: none !important;
}
body.lang-mode-en .bilingual-mobile-stack .q-stem-translation {
  border-left: none !important;
  background: transparent !important;
  padding: 0 !important;
  margin: 0 0 10px 30px !important;
}
body.lang-mode-en .bilingual-mobile-stack .q-stem-translation .lang-tag {
  display: none !important;
}
body.lang-mode-en .bilingual-mobile-stack .q-stem-en-body {
  font-size: 16px !important;
  font-weight: 600 !important;
  color: #0f172a !important;
  line-height: 1.65 !important;
}
body.lang-mode-en .bilingual-mobile-stack .opt-primary {
  display: none !important;
}
body.lang-mode-en .bilingual-mobile-stack .opt-secondary {
  font-size: 15.5px !important;
  color: #0f172a !important;
  font-weight: 600 !important;
}

/* Sub-row Language Filter Bar */
.cbt-subbar {
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 5px;
  padding-top: 4px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  width: 100%;
}
.cbt-lang-switcher {
  display: inline-flex;
  align-items: center;
  background: rgba(0, 0, 0, 0.35);
  padding: 2px;
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  gap: 3px;
}
.lang-pill-btn {
  background: transparent;
  color: #94a3b8;
  border: none;
  border-radius: 16px;
  padding: 3px 11px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.18s ease;
  white-space: nowrap;
}
.lang-pill-btn:hover {
  color: #f8fafc;
}
.lang-pill-btn.active {
  background: #38bdf8;
  color: #0f172a;
  font-weight: 800;
  box-shadow: 0 2px 6px rgba(56, 189, 248, 0.4);
}

.options-list { margin-top: 8px; padding-left: 36px; display: flex; flex-direction: column; gap: 6px; width: 100%; box-sizing: border-box; }
.options-list.grid-two { display: grid; grid-template-columns: 1fr 1fr; gap: 6px 10px; }
.option-row {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 8px 12px;
  border-radius: 8px;
  cursor: pointer;
  border: 1.5px solid #cbd5e1;
  background: #ffffff;
  transition: all 0.12s ease;
  user-select: none;
  font-size: 15.5px;
  font-weight: 600;
  color: #0f172a;
  line-height: 1.48;
  width: 100%;
  box-sizing: border-box;
}
.option-row:hover { background: #f8fafc; border-color: #94a3b8; }
.option-row:active { transform: scale(0.99); }
.option-row.selected { background: #eff6ff; border-color: #2563eb; font-weight: 700; color: #1d4ed8; box-shadow: 0 1px 3px rgba(37,99,235,0.12); }
.option-row.correct-ans { background: var(--success-bg); border-color: var(--success); font-weight: 800; color: #166534; }
.option-row.wrong-ans { background: var(--danger-bg); border-color: var(--danger); font-weight: 800; color: #991b1b; }
.opt-badge { font-weight: 800; font-size: 14.5px; min-width: 24px; flex-shrink: 0; color: #0f172a; }

.q-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 8px;
  padding-left: 36px;
  font-size: 12px;
  color: var(--text-muted);
  box-sizing: border-box;
  width: 100%;
}
.q-meta-tags { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.q-topic-tag { background: #f1f5f9; padding: 2px 7px; border-radius: 4px; font-size: 11px; }
.q-btn-group { display: flex; gap: 6px; }
.q-rev-btn {
  background: transparent;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11.5px;
  cursor: pointer;
  color: #475569;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.q-rev-btn:hover { background: #f1f5f9; border-color: var(--review); color: var(--review); }
.q-rev-btn.active { background: var(--review); color: #fff; border-color: var(--review); }

.q-peek-btn {
  background: #e0f2fe;
  border: 1px solid #bae6fd;
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11.5px;
  cursor: pointer;
  color: #0369a1;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.q-peek-btn:hover { background: #bae6fd; }

.q-report-btn {
  background: transparent;
  border: 1px solid #fed7aa;
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11.5px;
  cursor: pointer;
  color: #c2410c;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.q-report-btn:hover { background: #ffedd5; border-color: #f97316; }

.result-mark { display: none; font-size: 13px; font-weight: 700; padding: 4px 10px; border-radius: 4px; margin-top: 6px; }
.question-item.evaluated .result-mark { display: block; }
.result-mark.ok { background: var(--success-bg); color: #166534; }
.result-mark.wrong { background: var(--danger-bg); color: #991b1b; }
.result-mark.skipped { background: #f1f5f9; color: #475569; }

.pto-text {
  text-align: right;
  font-weight: 800;
  font-size: 12px;
  letter-spacing: 1px;
  padding: 12px 0;
  border-bottom: 2px solid #000;
  margin-bottom: 20px;
}

#report-modal {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(15,23,42,0.82);
  z-index: 130;
  align-items: center;
  justify-content: center;
  padding: 16px;
}
#report-modal.open { display: flex; }
.report-card {
  background: #fff;
  width: 480px;
  max-width: 95%;
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 16px 40px rgba(0,0,0,0.35);
}
.report-head {
  background: #0f172a;
  color: #fff;
  padding: 12px 18px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 2px solid #ea580c;
}
.report-body { padding: 18px 20px; }
.report-reasons { display: flex; flex-direction: column; gap: 8px; }
.rep-radio-label {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  background: #f8fafc;
  border: 1.5px solid #e2e8f0;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13.5px;
  font-weight: 500;
  color: #1e293b;
  transition: all 0.15s ease;
}
.rep-radio-label:hover { background: #f1f5f9; border-color: #cbd5e1; }
.rep-radio-label input[type="radio"]:checked + span { font-weight: 700; color: #ea580c; }

#passage-modal {
  display: none;
  position: fixed;
  top: 60px;
  right: 20px;
  width: 440px;
  max-width: 90vw;
  max-height: calc(100vh - 80px);
  background: #ffffff;
  border: 2px solid #334155;
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.3);
  z-index: 99;
  flex-direction: column;
  overflow: hidden;
}
#passage-modal.open { display: flex; }
.p-modal-head {
  background: #0f172a;
  color: #fff;
  padding: 10px 16px;
  font-weight: 700;
  font-size: 14px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.p-modal-close { background: transparent; border: 0; color: #cbd5e1; font-size: 18px; cursor: pointer; }
.p-modal-body { padding: 16px 20px; overflow-y: auto; font-size: 14px; line-height: 1.8; }

#confirm-modal {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(15,23,42,0.82);
  z-index: 125;
  align-items: center;
  justify-content: center;
  padding: 16px;
}
#confirm-modal.open { display: flex; }
.confirm-card {
  background: #fff;
  width: 460px;
  max-width: 95%;
  border-radius: 14px;
  padding: 24px 28px;
  box-shadow: 0 16px 40px rgba(0,0,0,0.35);
  text-align: center;
}
.confirm-card h3 { margin: 0 0 10px; font-size: 18px; color: #0f172a; }
.confirm-card p { font-size: 14px; color: #475569; margin: 0 0 18px; line-height: 1.6; }
.confirm-stats {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 10px;
  margin-bottom: 20px;
}
.c-stat-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 10px; }
.c-stat-box b { display: block; font-size: 22px; font-family: var(--font-eng); }
.c-stat-box span { font-size: 12px; color: #64748b; }

#omr-modal {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(15,23,42,0.8);
  z-index: 110;
  align-items: center;
  justify-content: center;
  padding: 16px;
}
#omr-modal.open { display: flex; }
.omr-sheet-card {
  background: #fff;
  width: 860px;
  max-width: 100%;
  max-height: 90vh;
  border-radius: 14px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  box-shadow: 0 12px 36px rgba(0,0,0,0.3);
}
.omr-head {
  background: #0f172a;
  color: #fff;
  padding: 12px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.omr-body {
  padding: 16px 20px;
  overflow-y: auto;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px 20px;
}
.omr-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  padding: 3px 0;
  border-bottom: 1px solid #f1f5f9;
}
.omr-num { min-width: 28px; font-weight: 700; text-align: right; }
.omr-bubbles { display: flex; gap: 6px; }
.omr-bubble {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: 1.5px solid #475569;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.1s;
}
.omr-bubble:hover { border-color: #2563eb; background: #eff6ff; }
.omr-bubble.filled { background: #0f172a; color: #fff; border-color: #0f172a; }

#result-modal {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.94);
  z-index: 120;
  overflow-y: auto;
  padding: 24px 12px;
}
#result-modal.open { display: block; }
.result-card {
  max-width: 820px;
  margin: 0 auto;
  background: #fff;
  border-radius: 18px;
  padding: 32px 36px;
  box-shadow: 0 16px 40px rgba(0,0,0,0.3);
}
.result-top-summary {
  text-align: center;
  border-bottom: 2px solid #e2e8f0;
  padding-bottom: 22px;
  margin-bottom: 20px;
}
.score-circle {
  font-size: 58px;
  font-weight: 900;
  line-height: 1;
  font-family: var(--font-eng);
}
.score-circle small {
  font-size: 22px;
  font-weight: 700;
  color: var(--text-muted);
}
.verdict-tag {
  display: inline-block;
  margin-top: 12px;
  padding: 6px 22px;
  border-radius: 30px;
  color: #fff;
  font-weight: 700;
  font-size: 15px;
  letter-spacing: 0.3px;
}
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(115px, 1fr));
  gap: 12px;
  margin-bottom: 24px;
}
.kpi-box {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 12px 8px;
  text-align: center;
}
.kpi-box b { display: block; font-size: 24px; font-family: var(--font-eng); }
.kpi-box span { font-size: 12px; color: var(--text-muted); }

.res-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13.5px;
  margin-bottom: 24px;
}
.res-table th, .res-table td {
  border: 1px solid #e2e8f0;
  padding: 8px 12px;
  text-align: left;
}
.res-table th { background: #f8fafc; font-size: 12.5px; }
.res-table td.center { text-align: center; font-variant-numeric: tabular-nums; }
.prog-bar {
  height: 8px;
  background: #e2e8f0;
  border-radius: 4px;
  overflow: hidden;
  margin-top: 4px;
}
.prog-fill { height: 100%; border-radius: 4px; }

.weak-list {
  background: #fffaf0;
  border: 1px solid #feebc8;
  border-radius: 8px;
  padding: 12px 20px;
  margin-bottom: 24px;
}
.weak-list h4 { margin: 0 0 8px; color: #c05621; }
.weak-list ul { margin: 0; padding-left: 20px; font-size: 13.5px; }

.result-actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
  margin-top: 24px;
}

#report-modal {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.88);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  z-index: 150;
  align-items: center;
  justify-content: center;
  padding: 16px;
}
#report-modal.open { display: flex; }
.report-card {
  background: #0f172a;
  color: #f8fafc;
  width: 520px;
  max-width: 100%;
  border-radius: 18px;
  border: 1.2px solid rgba(245, 158, 11, 0.4);
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
  overflow: hidden;
}
.report-head {
  background: #1e293b;
  padding: 14px 18px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #334155;
  color: #f59e0b;
}
.report-body {
  padding: 18px 20px;
}
.report-reasons {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.rep-radio-label {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  background: #1e293b;
  border: 1px solid #334155;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.15s;
  font-size: 13.5px;
  color: #e2e8f0;
}
.rep-radio-label:hover {
  border-color: #f59e0b;
  background: rgba(245, 158, 11, 0.08);
}
.rep-radio-label input[type="radio"] {
  accent-color: #f59e0b;
  width: 16px;
  height: 16px;
}
#rep-comment {
  width: 100%;
  box-sizing: border-box;
  background: #1e293b;
  color: #f8fafc;
  border: 1px solid #334155;
  border-radius: 10px;
  padding: 10px 12px;
  font-size: 13px;
  outline: none;
}
#rep-comment:focus {
  border-color: #f59e0b;
}

@media (max-width: 768px) {
  body { font-size: 14px; }
  .cbt-bar { padding: max(6px, env(safe-area-inset-top)) 8px 6px; }
  .cbt-main-row { gap: 6px; }
  #timer-box { height: 32px; font-size: 12.5px; padding: 0 8px; gap: 4px; }
  .cbt-pill { height: 32px; font-size: 11.5px; padding: 0 8px; gap: 4px; }
  .cbt-btn { height: 32px; font-size: 11px; padding: 0 8px; gap: 4px; }
  .cbt-btn-exit { width: 32px; font-size: 13px; }
  .hide-on-mobile { display: none !important; }

  .paper-page { padding: 10px 8px; width: 100%; box-sizing: border-box; }
  .section-banner { margin: 14px 0 10px; padding: 8px 10px; border-radius: 6px; }
  .bilingual-desktop-grid { display: none; }
  .bilingual-mobile-stack { display: flex; flex-direction: column; }
  .q-stem-translation { margin-left: 0; }
  .options-list { padding-left: 0; }
  .options-list.grid-two { grid-template-columns: 1fr; }
  .option-row { padding: 8px 10px; font-size: 14.5px; }
  .opt-primary { font-size: 14.5px; }
  .opt-secondary { font-size: 13px; }
  .q-footer { padding-left: 0; flex-wrap: wrap; gap: 6px; }

  .cover-page { padding: 16px 10px; }
  .cover-meta-grid { grid-template-columns: 1fr; gap: 8px; }
  .cover-instructions { grid-template-columns: 1fr; gap: 10px; }
  .omr-body { grid-template-columns: 1fr; }
  .result-card { padding: 18px 12px; }
}

@media (max-width: 440px) {
  .cbt-main-row { gap: 4px; }
  .btn-text { display: none !important; }
  .count-label { display: none !important; }
  .cbt-btn { width: 32px; padding: 0; justify-content: center; }
  .cbt-btn span { font-size: 13px; margin: 0; }
  #timer-box { padding: 0 6px; font-size: 11.5px; }
}

/* KaTeX and general overflow protection (prevents horizontal shifting) */
.katex-display { overflow-x: auto; overflow-y: hidden; max-width: 100%; padding: 4px 0; }
.katex { max-width: 100%; }
table { max-width: 100%; overflow-x: auto; display: block; }

@media print {
  .cbt-bar, .palette-drawer, #result-modal, #omr-modal, #passage-modal, .q-footer { display: none !important; }
  body { background: #fff !important; }
  .booklet-container { box-shadow: none !important; max-width: 100% !important; }
  .cover-page { page-break-after: always; }
  .question-item { page-break-inside: avoid; }
}
''';

  static const String _jsEngine = '''
(function(){
  const ANS_KEY = __ANS_KEY__;
  const SECTIONS = __SECTIONS__;
  const TOPICS = __TOPICS__;
  const TOTAL_QS = __TOTAL_QS__;
  const PAPER_ID = '__PAPER_ID__';
  const PASSAGES = __PASSAGES__;

  let responses = {};
  let reviewed = {};
  let timeRemaining = 9000;
  let timerInterval = null;
  let testSubmitted = false;

  function notifyFlutter(type, data) {
    try {
      if (window.BookletChannel && window.BookletChannel.postMessage) {
        window.BookletChannel.postMessage(JSON.stringify({ type: type, ...data }));
      }
    } catch(e) {}
  }

  function formatTime(sec) {
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = sec % 60;
    return String(h).padStart(2,'0') + ':' + String(m).padStart(2,'0') + ':' + String(s).padStart(2,'0');
  }

  function startTimer() {
    if (timerInterval) return;
    timerInterval = setInterval(() => {
      timeRemaining--;
      const el = document.getElementById('timer-val');
      if (el) el.textContent = formatTime(Math.max(0, timeRemaining));
      if (timeRemaining <= 900) {
        const tb = document.getElementById('timer-box');
        if (tb) tb.classList.add('timer-warning');
      }
      if (timeRemaining <= 0) {
        clearInterval(timerInterval);
        submitTest(true);
      }
    }, 1000);
  }

  window.selectOption = function(qNum, optIdx) {
    if (testSubmitted) return;
    startTimer();
    responses[qNum] = optIdx;

    document.querySelectorAll('[data-qnum="'+qNum+'"] .option-row').forEach(row => {
      row.classList.toggle('selected', parseInt(row.dataset.optidx) === optIdx);
    });

    const qEl = document.getElementById('qitem-' + qNum);
    if (qEl) qEl.classList.add('done');

    updatePaletteStatus(qNum);
    updateOMRBubble(qNum, optIdx);
    updateStats();
    saveState();

    notifyFlutter('selectOption', { qIndex: qNum - 1, optionIndex: optIdx });
  };

  window.toggleReview = function(qNum) {
    if (testSubmitted) return;
    startTimer();
    reviewed[qNum] = !reviewed[qNum];
    const btn = document.getElementById('rev-btn-' + qNum);
    if (btn) btn.classList.toggle('active', !!reviewed[qNum]);
    updatePaletteStatus(qNum);
    updateStats();
    saveState();

    notifyFlutter('toggleReview', { qIndex: qNum - 1, isReviewed: !!reviewed[qNum] });
  };

  function updatePaletteStatus(qNum) {
    const pEl = document.getElementById('pal-' + qNum);
    if (!pEl) return;
    pEl.className = '';
    const hasAns = responses[qNum] !== undefined;
    const isRev = reviewed[qNum];
    if (hasAns && isRev) pEl.classList.add('ans-rev');
    else if (hasAns) pEl.classList.add('answered');
    else if (isRev) pEl.classList.add('reviewed');
  }

  function updateOMRBubble(qNum, optIdx) {
    const bubbles = document.querySelectorAll('#omr-row-' + qNum + ' .omr-bubble');
    bubbles.forEach((b, i) => {
      b.classList.toggle('filled', i === optIdx);
    });
  }

  function updateStats() {
    const answeredCount = Object.keys(responses).length;
    const reviewCount = Object.values(reviewed).filter(Boolean).length;
    const sAns = document.getElementById('stat-answered');
    const sLeft = document.getElementById('stat-left');
    const sRev = document.getElementById('stat-review');
    if (sAns) sAns.textContent = answeredCount;
    if (sLeft) sLeft.textContent = TOTAL_QS - answeredCount;
    if (sRev) sRev.textContent = reviewCount;
  }

  window.togglePalette = function() {
    const d = document.getElementById('palette-drawer');
    if (d) d.classList.toggle('open');
  };
  window.closePalette = function() {
    const d = document.getElementById('palette-drawer');
    if (d) d.classList.remove('open');
  };
  window.jumpToQuestion = function(qNum) {
    const el = document.getElementById('qitem-' + qNum);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
    closePalette();
  };
  window.requestExitTest = function() {
    notifyFlutter('exitTest', {});
  };
  window.requestRefreshTest = function() {
    notifyFlutter('refreshTest', {});
  };

  window.openOMR = function() {
    const m = document.getElementById('omr-modal');
    if (m) m.classList.add('open');
  };
  window.closeOMR = function() {
    const m = document.getElementById('omr-modal');
    if (m) m.classList.remove('open');
  };

  window.showPassageModal = function(passageId) {
    const pData = PASSAGES[passageId];
    if (!pData) return;
    const t = document.getElementById('p-modal-title');
    const b = document.getElementById('p-modal-text');
    if (t) t.textContent = (pData.kind === 'poem' ? '📜 काव्यांश / कविता' : '📖 अपठित गद्यांश');
    if (b) b.innerHTML = pData.body;
    const m = document.getElementById('passage-modal');
    if (m) m.classList.add('open');
  };
  window.closePassageModal = function() {
    const m = document.getElementById('passage-modal');
    if (m) m.classList.remove('open');
  };

  window.submitTest = function(auto) {
    if (testSubmitted) return;
    if (auto) {
      executeSubmit(true);
      return;
    }
    const answeredCount = Object.keys(responses).length;
    const cfAns = document.getElementById('cf-ans');
    const cfLeft = document.getElementById('cf-left');
    if (cfAns) cfAns.textContent = answeredCount;
    if (cfLeft) cfLeft.textContent = TOTAL_QS - answeredCount;
    const cfModal = document.getElementById('confirm-modal');
    if (cfModal) cfModal.classList.add('open');
    else executeSubmit(false);
  };

  window.closeConfirmModal = function() {
    const cfModal = document.getElementById('confirm-modal');
    if (cfModal) cfModal.classList.remove('open');
  };

  window.executeSubmit = function(auto) {
    if (testSubmitted) return;
    closeConfirmModal();
    testSubmitted = true;
    clearInterval(timerInterval);

    let correct = 0, wrong = 0, skipped = 0;
    const secStats = {};
    const topicStats = {};

    for (let n = 1; n <= TOTAL_QS; n++) {
      const ansKey = ANS_KEY[n];
      const sec = SECTIONS[n] || 'General';
      const top = TOPICS[n] || 'विविध';

      if (!secStats[sec]) secStats[sec] = { total: 0, ok: 0, wrong: 0, skipped: 0 };
      if (!topicStats[top]) topicStats[top] = { total: 0, ok: 0, wrong: 0 };

      secStats[sec].total++;
      topicStats[top].total++;

      const qEl = document.getElementById('qitem-' + n);
      if (qEl) qEl.classList.add('evaluated');

      const markEl = document.getElementById('mark-' + n);
      const userAns = responses[n];

      const optRows = document.querySelectorAll('[data-qnum="'+n+'"] .option-row');
      optRows.forEach(row => {
        const idx = parseInt(row.dataset.optidx);
        if (idx === ansKey) row.classList.add('correct-ans');
        else if (userAns === idx) row.classList.add('wrong-ans');
      });

      const palEl = document.getElementById('pal-' + n);

      if (userAns === undefined) {
        skipped++;
        secStats[sec].skipped++;
        if (markEl) {
          markEl.className = 'result-mark skipped';
          markEl.innerHTML = '⊘ अनुत्तरित — सही उत्तर : <b>(' + 'ABCD'[ansKey] + ')</b>';
        }
        if (palEl) { palEl.className = 'skipped'; }
      } else if (userAns === ansKey) {
        correct++;
        secStats[sec].ok++;
        topicStats[top].ok++;
        if (markEl) {
          markEl.className = 'result-mark ok';
          markEl.innerHTML = '✓ सही उत्तर (+1 अंक)';
        }
        if (palEl) { palEl.className = 'answered'; }
      } else {
        wrong++;
        secStats[sec].wrong++;
        topicStats[top].wrong++;
        if (markEl) {
          markEl.className = 'result-mark wrong';
          markEl.innerHTML = '✗ गलत — आपका उत्तर : <b>(' + 'ABCD'[userAns] + ')</b> | सही उत्तर : <b>(' + 'ABCD'[ansKey] + ')</b>';
        }
        if (palEl) { palEl.className = 'wrong'; }
      }
    }

    displayResults(correct, wrong, skipped, secStats, topicStats, auto);

    notifyFlutter('testSubmitted', {
      score: correct,
      correctCount: correct,
      wrongCount: wrong,
      skippedCount: skipped,
      totalQuestions: TOTAL_QS,
      elapsedSeconds: 9000 - timeRemaining,
      responses: responses
    });
  };

  function displayResults(correct, wrong, skipped, secStats, topicStats, auto) {
    const pct = ((correct / TOTAL_QS) * 100).toFixed(1);

    let verdictColor, verdictText, verdictSub;
    if (correct >= 90) {
      verdictColor = '#16a34a';
      verdictText = '🎉 उत्तीर्ण (QUALIFIED) — सामान्य वर्ग कट-ऑफ पार!';
      verdictSub = 'बधाई! आपने 60% (90+ अंक) प्राप्त कर शिक्षक पात्रता परीक्षा उत्तीर्ण कर ली है।';
    } else if (correct >= 82) {
      verdictColor = '#65a30d';
      verdictText = '👍 उत्तीर्ण (QUALIFIED) — आरक्षित श्रेणी (OBC/SC/ST कट-ऑफ पार)';
      verdictSub = 'आपने आरक्षित वर्ग के न्यूनतम 55% (82 अंक) की पात्रता सुरक्षित कर ली है।';
    } else {
      verdictColor = '#dc2626';
      verdictText = '⚠️ अनुत्तीर्ण (NOT QUALIFIED) — और अभ्यास की आवश्यकता';
      verdictSub = 'पात्रता के लिए न्यूनतम 82 अंक (आरक्षित) अथवा 90 अंक (सामान्य) आवश्यक हैं।';
    }

    const rScore = document.getElementById('res-score');
    if (rScore) {
      rScore.innerHTML = correct + '<small>/' + TOTAL_QS + '</small>';
      rScore.style.color = verdictColor;
    }

    const vTag = document.getElementById('res-verdict');
    if (vTag) {
      vTag.style.background = verdictColor;
      vTag.textContent = verdictText;
    }

    const rSub = document.getElementById('res-sub');
    if (rSub) rSub.textContent = verdictSub;

    const setTxt = (id, val) => { const e = document.getElementById(id); if (e) e.textContent = val; };
    setTxt('kpi-ok', correct);
    setTxt('kpi-wrong', wrong);
    setTxt('kpi-skip', skipped);
    setTxt('kpi-pct', pct + '%');
    const accuracy = (correct + wrong) > 0 ? ((correct / (correct + wrong)) * 100).toFixed(1) : '0';
    setTxt('kpi-acc', accuracy + '%');
    setTxt('kpi-time', formatTime(9000 - timeRemaining));

    let tableHtml = '<tr><th>खण्ड (Section)</th><th class="center">कुल</th><th class="center">सही</th><th class="center">गलत</th><th class="center">छोड़े</th><th style="width:30%">प्राप्तांक एवं प्रतिशत</th></tr>';
    for (const sName in secStats) {
      const s = secStats[sName];
      const sPct = ((s.ok / s.total) * 100).toFixed(1);
      const barColor = sPct >= 70 ? '#16a34a' : (sPct >= 50 ? '#d97706' : '#dc2626');
      tableHtml += '<tr>'
        + '<td><b>' + sName + '</b></td>'
        + '<td class="center">' + s.total + '</td>'
        + '<td class="center" style="color:#16a34a;font-weight:700">' + s.ok + '</td>'
        + '<td class="center" style="color:#dc2626;font-weight:700">' + s.wrong + '</td>'
        + '<td class="center" style="color:#64748b">' + s.skipped + '</td>'
        + '<td><b>' + s.ok + ' / ' + s.total + ' (' + sPct + '%)</b>'
        + '<div class="prog-bar"><div class="prog-fill" style="width:'+sPct+'%;background:'+barColor+'"></div></div></td>'
        + '</tr>';
    }
    const tb = document.getElementById('res-table-body');
    if (tb) tb.innerHTML = tableHtml;

    const weakList = Object.keys(topicStats)
      .filter(t => topicStats[t].wrong > 0)
      .sort((a,b) => topicStats[b].wrong - topicStats[a].wrong)
      .slice(0, 8);

    const ws = document.getElementById('weak-section');
    if (weakList.length > 0 && ws) {
      let wHtml = '<h4>🎯 कमजोर टॉपिक्स — प्राथमिकता से अभ्यास करें:</h4><ul>';
      weakList.forEach(t => {
        wHtml += '<li><b>' + t + '</b>: ' + topicStats[t].ok + '/' + topicStats[t].total + ' सही (' + topicStats[t].wrong + ' त्रुटियाँ)</li>';
      });
      wHtml += '</ul>';
      ws.innerHTML = wHtml;
      ws.style.display = 'block';
    }

    const rm = document.getElementById('result-modal');
    if (rm) rm.classList.add('open');

    const ca = document.getElementById('cbt-actions');
    if (ca) ca.innerHTML = '<button class="cbt-btn cbt-btn-primary" onclick="reopenResult()"><span>📊</span> <span class="btn-text">परिणाम</span></button> ' +
                           '<button class="cbt-btn cbt-btn-secondary" onclick="location.reload()"><span>🔄</span> <span class="btn-text">रीटेस्ट</span></button> ' +
                           '<button class="cbt-btn cbt-btn-exit" onclick="requestExitTest()" title="बाहर निकलें"><span>✕</span></button>';
  }

  window.closeResult = function() {
    const rm = document.getElementById('result-modal');
    if (rm) rm.classList.remove('open');
  };
  window.reopenResult = function() {
    const rm = document.getElementById('result-modal');
    if (rm) rm.classList.add('open');
  };

  let filterWrongOnly = false;
  window.toggleWrongOnly = function() {
    filterWrongOnly = !filterWrongOnly;
    closeResult();
    for (let n = 1; n <= TOTAL_QS; n++) {
      const qEl = document.getElementById('qitem-' + n);
      if (!qEl) continue;
      const isCorrect = responses[n] !== undefined && responses[n] === ANS_KEY[n];
      qEl.style.display = (filterWrongOnly && isCorrect) ? 'none' : 'block';
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  window.resetTest = function() {
    if (testSubmitted) return;
    if (!confirm("क्या आप अपने सभी उत्तर मिटाना चाहते हैं?")) return;
    responses = {};
    reviewed = {};
    document.querySelectorAll('.option-row').forEach(r => r.classList.remove('selected'));
    document.querySelectorAll('.palette-grid a').forEach(a => a.className = '');
    document.querySelectorAll('.omr-bubble').forEach(b => b.classList.remove('filled'));
    document.querySelectorAll('.q-rev-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.question-item').forEach(q => q.classList.remove('done'));
    updateStats();
    try { localStorage.removeItem('TET_TEST_' + PAPER_ID); } catch(e){}
    notifyFlutter('resetTest', {});
  };

  function saveState() {
    try {
      localStorage.setItem('TET_TEST_' + PAPER_ID, JSON.stringify({
        responses: responses,
        reviewed: reviewed,
        timeRemaining: timeRemaining,
        savedAt: Date.now()
      }));
    } catch(e){}
  }

  function restoreState() {
    try {
      const raw = localStorage.getItem('TET_TEST_' + PAPER_ID);
      if (!raw) return;
      const data = JSON.parse(raw);
      if (data && data.responses) {
        responses = data.responses;
        reviewed = data.reviewed || {};
        if (data.timeRemaining) timeRemaining = data.timeRemaining;

        for (const qNum in responses) {
          const idx = responses[qNum];
          document.querySelectorAll('[data-qnum="'+qNum+'"] .option-row').forEach(row => {
            row.classList.toggle('selected', parseInt(row.dataset.optidx) === idx);
          });
          const qEl = document.getElementById('qitem-' + qNum);
          if (qEl) qEl.classList.add('done');
          updatePaletteStatus(parseInt(qNum));
          updateOMRBubble(parseInt(qNum), idx);
        }
        for (const qNum in reviewed) {
          if (reviewed[qNum]) {
            const btn = document.getElementById('rev-btn-' + qNum);
            if (btn) btn.classList.add('active');
            updatePaletteStatus(parseInt(qNum));
          }
        }
        updateStats();
      }
    } catch(e){}
  }

  let currentReportQId = '';
  let currentReportQNum = 1;

  window.openReportModal = function(qId, qNum) {
    if (window.BookletChannel && window.BookletChannel.postMessage) {
      window.BookletChannel.postMessage(JSON.stringify({
        type: 'requestReport',
        qIndex: qNum - 1,
        qNum: qNum,
        qId: qId
      }));
      return;
    }
    currentReportQId = qId;
    currentReportQNum = qNum;
    const qNumEl = document.getElementById('rep-qnum');
    if (qNumEl) qNumEl.textContent = qNum;
    const commentEl = document.getElementById('rep-comment');
    if (commentEl) commentEl.value = '';
    const modal = document.getElementById('report-modal');
    if (modal) modal.classList.add('open');
  };

  window.closeReportModal = function() {
    const modal = document.getElementById('report-modal');
    if (modal) modal.classList.remove('open');
  };

  window.submitQuestionReport = function() {
    const selectedRadio = document.querySelector('input[name="rep-reason"]:checked');
    const reason = selectedRadio ? selectedRadio.value : 'उत्तर गलत है / Wrong Answer';
    const comment = (document.getElementById('rep-comment')?.value || '').trim();
    
    if (window.BookletChannel) {
      window.BookletChannel.postMessage(JSON.stringify({
        type: 'reportQuestion',
        qIndex: currentReportQNum - 1,
        qNum: currentReportQNum,
        qId: currentReportQId,
        reason: reason,
        comment: comment
      }));
    }
    closeReportModal();
  };

  window.setLangFilter = function(mode) {
    document.body.classList.remove('lang-mode-both', 'lang-mode-hi', 'lang-mode-en');
    document.body.classList.add('lang-mode-' + mode);
    
    document.querySelectorAll('.lang-pill-btn').forEach(function(btn) {
      btn.classList.remove('active');
    });
    var target = document.getElementById('btn-lang-' + mode);
    if (target) target.classList.add('active');
    
    try {
      localStorage.setItem('booklet_lang_filter', mode);
    } catch(e){}
  };

  window.addEventListener('DOMContentLoaded', () => {
    const tv = document.getElementById('timer-val');
    if (tv) tv.textContent = formatTime(timeRemaining);
    restoreState();
    try {
      var savedLang = localStorage.getItem('booklet_lang_filter') || 'hi';
      setLangFilter(savedLang);
    } catch(e) {
      setLangFilter('hi');
    }
  });
})();
''';
}
