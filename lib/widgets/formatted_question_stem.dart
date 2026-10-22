import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_typography.dart';
import '../services/question_layout_parser.dart';
import 'smart_math_text.dart';

/// Structured parsed question representation to avoid "khichdi" in complex board questions
sealed class ParsedQuestionContent {
  const ParsedQuestionContent();
}

class PlainQuestionContent extends ParsedQuestionContent {
  final String text;
  const PlainQuestionContent(this.text);
}

class TableQuestionContent extends ParsedQuestionContent {
  final String? intro;
  final List<String> headers;
  final List<List<String>> rows;
  final String? postTable;

  const TableQuestionContent({
    this.intro,
    required this.headers,
    required this.rows,
    this.postTable,
  });
}

class MatchColumnContent extends ParsedQuestionContent {
  final String? intro;
  final List<({String leftMarker, String leftText, String rightMarker, String rightText})> pairs;
  final String? conclusion;

  const MatchColumnContent({
    this.intro,
    required this.pairs,
    this.conclusion,
  });
}

class AssertionReasonContent extends ParsedQuestionContent {
  final String? intro;
  final String assertionLabel;
  final String assertionText;
  final String reasonLabel;
  final String reasonText;
  final String? conclusion;

  const AssertionReasonContent({
    this.intro,
    required this.assertionLabel,
    required this.assertionText,
    required this.reasonLabel,
    required this.reasonText,
    this.conclusion,
  });
}

class MultiStatementContent extends ParsedQuestionContent {
  final String? intro;
  final List<({String marker, String text})> statements;
  final String? conclusion;

  const MultiStatementContent({
    this.intro,
    required this.statements,
    this.conclusion,
  });
}

/// Helper parser to break unformatted questions (Tables, Match the Column, Assertion-Reason, Multi-Statement)
/// into structured components.
class QuestionContentParser {
  static final RegExp _conclusionPattern = RegExp(
    r'^(.*?)\s*([–—\-:ः]*\s*(?:सही\s*(?:विकल्प|उत्तर|कूट|कोड)|दिए\s*गए\s*विकल्प(?:ों)?|निम्नलिखित\s*(?:में\s*से\s*)?सही|उपर्युक्त|उपरोक्त|नीचे\s*दिए|इनमें\s*से|इनमें|Choose\s*the\s*correct|Select\s*the\s*correct|Select\s*from\s*the|Which\s*of\s*the\s*above|Code\s*:|Codes\s*:|कूट\s*:|कोड\s*:)[^\n]*)$',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _arPattern = RegExp(
    r'^(.*?)(?:^|[\s–—\-:ः।;,])(अभिकथन(?:\s*\([A-Za-z]\))?|कथन(?:\s*[-–—]?\s*(?:1|2|I|II|[A-Za-z]))?|दावा(?:\s*\([A-Za-z]\))?|कथनम्(?:\s*\([A-Za-z]\))?|Assertion(?:\s*\([A-Za-z]\))?|\(A\))\s*[:\-–—ः.]\s*(.*?)(?:^|[\s–—\-:ः।;,])(कारण(?:\s*\([A-Za-z]\))?|तर्क(?:\s*\([A-Za-z]\))?|कारणम्(?:\s*\([A-Za-z]\))?|Reason(?:\s*\([A-Za-z]\))?|\(R\))\s*[:\-–—ः.]\s*(.*?)$',
    caseSensitive: false,
    dotAll: true,
  );

  /// Parsing a stem is regex heavy and a 150 question paper re-parses the
  /// same stems on every rebuild, so results are cached.
  static final Map<String, ParsedQuestionContent> _cache =
      <String, ParsedQuestionContent>{};
  static const int _cacheLimit = 600;

  static ParsedQuestionContent parse(String rawText) {
    final cached = _cache[rawText];
    if (cached != null) return cached;
    final parsed = _parseUncached(rawText);
    if (_cache.length >= _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    _cache[rawText] = parsed;
    return parsed;
  }

  static ParsedQuestionContent _parseUncached(String rawText) {
    var text = rawText.trim();
    if (text.isEmpty) return const PlainQuestionContent('');

    // Pre-clean any accidental markdown headers, question number leaks (**Q114.** or Q114:), options labels, or checkmarks
    text = text
        .replaceAll(RegExp(r'^\s*(?:\*\*|#{1,6}\s*)?Q(?:uestion)?\.?\s*\d+[\.\:\*]?\s*', caseSensitive: false, multiLine: true), '')
        .replaceAll(RegExp(r'^\s*#{1,6}\s*(?:Q\.?\s*)?\d*[\.\:\-]?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*\*\*Options\s*(?:/\s*विकल्प)?\*\*\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[✅✓]'), '')
        .replaceAll(RegExp(r'^\s*#{1,6}\s*'), '')
        .replaceAllMapped(
          RegExp(r'\*\*\s*(अभिकथन|कारण|दावा|तर्क|कथनम्|कारणम्|कथन|Assertion|Reason)(?:\s*\(([A-Za-z0-9]+)\))?\s*[:\-–—ः.]?\s*\*\*', caseSensitive: false),
          (m) => '${m[1]} ${m[2] != null ? "(${m[2]}):" : ":"}',
        )
        .replaceAll('**', '')
        .trim();

    // Canonicalise inline labels (कथन-1, कथन १, …) and preserve line breaks.
    text = QuestionLayoutParser.normalize(text);

    // 1. Try Markdown Table parsing
    if (text.contains('|') && RegExp(r'\|\s*[-:]+[-| :]*\|').hasMatch(text)) {
      final lines = text.split('\n');
      int tableStartIndex = -1;
      int tableDividerIndex = -1;
      int tableEndIndex = -1;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('|') && line.endsWith('|')) {
          if (tableStartIndex == -1) {
            tableStartIndex = i;
          }
          if (tableDividerIndex == -1 && RegExp(r'^\|[\s\-:|]+\|$').hasMatch(line.replaceAll(' ', ''))) {
            tableDividerIndex = i;
          }
          tableEndIndex = i;
        } else if (tableStartIndex != -1 && tableEndIndex != -1 && tableDividerIndex != -1) {
          // Table ended
          break;
        }
      }

      if (tableStartIndex != -1 && tableDividerIndex != -1 && tableDividerIndex > tableStartIndex) {
        final introLines = lines.sublist(0, tableStartIndex).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        final intro = introLines.isNotEmpty ? introLines.join('\n') : null;

        final headerLine = lines[tableStartIndex].trim();
        final rawHeaders = headerLine
            .split('|')
            .map((c) => c.trim().replaceAll('**', ''))
            .toList();
        // Remove empty first/last elements from split
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
            if (cells.isNotEmpty) {
              rows.add(cells);
            }
          }
        }

        final postLines = lines.sublist(tableEndIndex + 1).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        final postTable = postLines.isNotEmpty ? postLines.join('\n') : null;

        if (headers.isNotEmpty && rows.isNotEmpty) {
          return TableQuestionContent(
            intro: intro,
            headers: headers,
            rows: rows,
            postTable: postTable,
          );
        }
      }
    }

    // 2. Universal match-the-following parser (inline and multi-line forms).
    final matchTable = QuestionLayoutParser.parseMatchTable(text);
    if (matchTable != null) {
      return MatchColumnContent(
        intro: matchTable.intro,
        pairs: [
          for (final row in matchTable.rows)
            (
              leftMarker: row.leftMarker,
              leftText: row.leftText,
              rightMarker: row.rightMarker,
              rightText: row.rightText,
            ),
        ],
        conclusion: matchTable.conclusion,
      );
    }

    // 2B. Fallback: Match-The-Column (Two-Column Side-by-Side Table)
    // Matches patterns like: (A) Malayalam (i) Goa (B) Konkani (ii) Kerala ...
    final matchItems = RegExp(r'(\((?:[A-Za-z0-9]+|[i-vI-V]+)\))\s*([^\(]+?)(?=\s*\((?:[A-Za-z0-9]+|[i-vI-V]+)\)|$)')
        .allMatches(text)
        .toList();
    if (matchItems.length >= 4) {
      final leftItems = <({String marker, String text})>[];
      final rightItems = <({String marker, String text})>[];
      for (final m in matchItems) {
        final marker = m.group(1)!.trim();
        final itemText = m.group(2)!.trim();
        final cleanMarker = marker.replaceAll(RegExp(r'[\(\)]'), '');
        if (RegExp(r'^[A-Fa-f]$').hasMatch(cleanMarker)) {
          leftItems.add((marker: marker, text: itemText));
        } else if (RegExp(r'^[i-vI-V0-9]+$').hasMatch(cleanMarker)) {
          rightItems.add((marker: marker, text: itemText));
        }
      }

      if (leftItems.length >= 2 && leftItems.length == rightItems.length) {
        final firstMarkerIdx = text.indexOf(leftItems[0].marker);
        final introPart = firstMarkerIdx > 0 ? text.substring(0, firstMarkerIdx).trim() : null;
        final pairs = <({String leftMarker, String leftText, String rightMarker, String rightText})>[];
        for (int i = 0; i < leftItems.length; i++) {
          pairs.add((
            leftMarker: leftItems[i].marker,
            leftText: leftItems[i].text,
            rightMarker: rightItems[i].marker,
            rightText: rightItems[i].text,
          ));
        }

        String? conclusion;
        final last = pairs.removeLast();
        final cm = _conclusionPattern.firstMatch(last.rightText);
        if (cm != null) {
          pairs.add((
            leftMarker: last.leftMarker,
            leftText: last.leftText,
            rightMarker: last.rightMarker,
            rightText: cm.group(1)!.trim(),
          ));
          conclusion = cm.group(2)!.trim();
        } else {
          pairs.add(last);
        }

        return MatchColumnContent(
          intro: (introPart != null && introPart.isNotEmpty) ? introPart : null,
          pairs: pairs,
          conclusion: (conclusion != null && conclusion.isNotEmpty) ? conclusion : null,
        );
      }
    }

    // 3. Try Assertion-Reason parsing
    final arMatch = _arPattern.firstMatch(text);
    if (arMatch != null) {
      final intro = arMatch.group(1)?.trim();
      var aLabel = arMatch.group(2)!.trim();
      var aText = arMatch.group(3)!.trim().replaceAll(RegExp(r'^[\s:\-–—ः.\*]+'), '').replaceAll(RegExp(r'[\s:\-–—ः.\*]+$'), '').replaceAll('**', '').replaceAll('*', '').trim();
      var rLabel = arMatch.group(4)!.trim();
      var rText = arMatch.group(5)!.trim().replaceAll(RegExp(r'^[\s:\-–—ः.\*]+'), '').replaceAll(RegExp(r'[\s:\-–—ः.\*]+$'), '').replaceAll('**', '').replaceAll('*', '').trim();
      String? conclusion;

      if (aLabel == '(A)' || aLabel == 'A') {
        aLabel = 'अभिकथन (A)';
      }
      if (rLabel == '(R)' || rLabel == 'R') {
        rLabel = 'कारण (R)';
      }

      final cm = _conclusionPattern.firstMatch(rText);
      if (cm != null) {
        rText = cm.group(1)!.trim().replaceAll(RegExp(r'[\s:\-–—ः.\*]+$'), '').trim();
        conclusion = cm.group(2)!.trim();
      }

      if (aText.isNotEmpty && rText.isNotEmpty) {
        return AssertionReasonContent(
          intro: (intro != null && intro.isNotEmpty) ? intro : null,
          assertionLabel: aLabel,
          assertionText: aText,
          reasonLabel: rLabel,
          reasonText: rText,
          conclusion: (conclusion != null && conclusion.isNotEmpty) ? conclusion : null,
        );
      }
    }

    // 4. Try Explicit Statements parsing (कथन (A), कथन (B) or Statement (A), Statement (B))
    // This avoids chopping intro text like 'नीचे दिए गए कथनों (A) और (B) पर विचार कीजिए'
    final explicitStmtMatches = RegExp(
      r'(?:^|[\s\.\:\-])(कथन\s*\(([A-Za-z0-9अ-ह]+)\)|कथन\s*([A-Za-z0-9अ-ह]+)|Statement\s*\(([A-Za-z0-9अ-ह]+)\)|Statement\s*([A-Za-z0-9अ-ह]+))\s*[:\-–—\.]\s*',
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
      final cm = _conclusionPattern.firstMatch(last.text);
      if (cm != null) {
        statements.add((marker: last.marker, text: cm.group(1)!.trim()));
        conclusion = cm.group(2)!.trim();
      } else {
        statements.add(last);
      }

      return MultiStatementContent(
        intro: (intro.isNotEmpty) ? intro : null,
        statements: statements,
        conclusion: (conclusion != null && conclusion.isNotEmpty) ? conclusion : null,
      );
    }

    // 4B. Generic parenthesized statements: (A)/(B)/(C), (i)/(ii)/(iii),
    // (1)/(2)/(3).  This is intentionally restricted to stems that look like
    // statement questions so options embedded in ordinary stems are not
    // chopped up.  Error-spotting stems use (A)…(D) for sentence parts, not
    // statements, and must stay plain.
    final isErrorSpotting = RegExp(
      r'(?:which\s+part.*?error|error\s+in\s+the\s+sentence|find\s+(?:out\s+)?the\s+error|identify\s+the\s+error|वाक्य\s+के\s+किस\s+भाग|किस\s+भाग\s+में\s+त्रुटि|त्रुटि\s+.*?भाग)',
      caseSensitive: false,
      dotAll: true,
    ).hasMatch(text);
    final hasStmtIntro = RegExp(
      r'(?:कथन|कथनों|विचार|पढ़िए|सत्य|सही|गलत|कूट|निम्नलिखित|निम्न|Statement|Statements|Consider|Following|Which)',
      caseSensitive: false,
    ).hasMatch(text);

    if (hasStmtIntro && !isErrorSpotting) {
      final styles = <RegExp>[
        RegExp(r'\(([A-Ea-e])\)\s*'),
        RegExp(r'\(([ivxIVX]{1,4})\)\s*'),
        RegExp(r'\(([1-9])\)\s*'),
      ];
      List<RegExpMatch>? picked;
      for (final re in styles) {
        final ms = re.allMatches(text).toList();
        if (ms.length < 3) continue;
        final values = ms.map((m) => m.group(1)!.toLowerCase()).toList();
        const roman = ['i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x'];
        var sequential = true;
        if (values.every((v) => RegExp(r'^\d+$').hasMatch(v))) {
          for (var i = 0; i < values.length; i++) {
            if (int.parse(values[i]) != i + 1) sequential = false;
          }
        } else if (values.every((v) => RegExp(r'^[a-e]$').hasMatch(v))) {
          for (var i = 0; i < values.length; i++) {
            if (values[i] != String.fromCharCode(97 + i)) sequential = false;
          }
        } else if (values.every(roman.contains)) {
          for (var i = 0; i < values.length; i++) {
            if (values[i] != roman[i]) sequential = false;
          }
        } else {
          sequential = false;
        }
        if (sequential) {
          picked = ms;
          break;
        }
      }

      if (picked != null) {
        final intro = text.substring(0, picked.first.start).trim();
        final statements = <({String marker, String text})>[];
        for (var i = 0; i < picked.length; i++) {
          final start = picked[i].end;
          final end = i + 1 < picked.length ? picked[i + 1].start : text.length;
          statements.add((
            marker: '(${picked[i].group(1)})',
            text: text.substring(start, end).trim(),
          ));
        }
        String? conclusion;
        final last = statements.removeLast();
        final cm = _conclusionPattern.firstMatch(last.text);
        if (cm != null) {
          statements.add((marker: last.marker, text: cm.group(1)!.trim()));
          conclusion = cm.group(2)!.trim();
        } else {
          statements.add(last);
        }
        if (statements.length >= 2) {
          return MultiStatementContent(
            intro: intro.isNotEmpty ? intro : null,
            statements: statements,
            conclusion: (conclusion != null && conclusion.isNotEmpty) ? conclusion : null,
          );
        }
      }
    }

    // 5. Try Newline-separated Multi-Statement (only if statements start on separate lines)
    if (text.contains('\n')) {
      final lines = text.split('\n');
      final markerRegex = RegExp(r'^\(((?:[A-Ea-e]|[i-v]+|[1-5]))\)\s*[:\-–—]?\s*(.*)$');
      final statements = <({String marker, String text})>[];
      final introLines = <String>[];
      bool insideList = false;

      for (final l in lines) {
        final trimmed = l.trim();
        final m = markerRegex.firstMatch(trimmed);
        if (m != null) {
          insideList = true;
          statements.add((marker: '(${m.group(1)})', text: m.group(2)!.trim()));
        } else if (insideList && statements.isNotEmpty) {
          final last = statements.removeLast();
          statements.add((marker: last.marker, text: '${last.text} $trimmed'.trim()));
        } else {
          introLines.add(trimmed);
        }
      }

      if (statements.length >= 2) {
        final intro = introLines.where((s) => s.isNotEmpty).join('\n');
        String? conclusion;
        final last = statements.removeLast();
        final cm = _conclusionPattern.firstMatch(last.text);
        if (cm != null) {
          statements.add((marker: last.marker, text: cm.group(1)!.trim()));
          conclusion = cm.group(2)!.trim();
        } else {
          statements.add(last);
        }

        return MultiStatementContent(
          intro: (intro.isNotEmpty) ? intro : null,
          statements: statements,
          conclusion: (conclusion != null && conclusion.isNotEmpty) ? conclusion : null,
        );
      }
    }

    return PlainQuestionContent(text);
  }
}

/// Premium Structured Question Stem Widget
/// Renders questions cleanly without "khichdi" - separates statements, tables, match columns,
/// assertion/reason badges, and conclusions with full native LaTeX math support.
class FormattedQuestionStem extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool isDark;
  final bool isTranslation;

  const FormattedQuestionStem({
    super.key,
    required this.text,
    this.style,
    required this.isDark,
    this.isTranslation = false,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ??
        (isTranslation
            ? AppTypography.bodyMedium(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ).copyWith(height: 1.45)
            : AppTypography.questionText(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ));

    final parsed = QuestionContentParser.parse(text);

    return switch (parsed) {
      PlainQuestionContent(text: final plain) => SmartMathText(
          plain,
          style: defaultStyle,
        ),

      TableQuestionContent(
        intro: final intro,
        headers: final headers,
        rows: final rows,
        postTable: final postTable,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (intro != null) ...[
              SmartMathText(intro, style: defaultStyle),
              const SizedBox(height: 12),
            ],
            _buildTable(headers, rows, defaultStyle),
            if (postTable != null) ...[
              const SizedBox(height: 12),
              FormattedQuestionStem(
                text: postTable,
                style: defaultStyle,
                isDark: isDark,
                isTranslation: isTranslation,
              ),
            ],
          ],
        ),

      MatchColumnContent(
        intro: final intro,
        pairs: final pairs,
        conclusion: final conclusion,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (intro != null) ...[
              SmartMathText(intro, style: defaultStyle),
              const SizedBox(height: AppSpacing.md),
            ],
            _buildMatchTable(pairs, defaultStyle),
            if (conclusion != null) ...[
              const SizedBox(height: AppSpacing.md),
              SmartMathText(
                conclusion,
                style: defaultStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: (defaultStyle.fontSize ?? 15) - 0.5,
                ),
              ),
            ],
          ],
        ),

      AssertionReasonContent(
        intro: final intro,
        assertionLabel: final aLabel,
        assertionText: final aText,
        reasonLabel: final rLabel,
        reasonText: final rText,
        conclusion: final conclusion,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (intro != null) ...[
              SmartMathText(intro, style: defaultStyle),
              const SizedBox(height: AppSpacing.md),
            ],

            // Assertion Card
            _buildStatementBox(
              label: aLabel,
              content: aText,
              badgeColor: isDark ? AppColors.goldBright : AppColors.sealGold,
              badgeBg: isDark ? AppColors.primaryDark : AppColors.sealGoldSubtle,
              borderColor: isDark ? AppColors.warningDark : AppColors.goldBright,
              style: defaultStyle,
            ),
            const SizedBox(height: 8),

            // Reason Card
            _buildStatementBox(
              label: rLabel,
              content: rText,
              badgeColor: isDark ? AppColors.accentBright : AppColors.accent,
              badgeBg: isDark ? AppColors.primary : AppColors.accentSoft,
              borderColor: isDark ? AppColors.accent : AppColors.accentSoft,
              style: defaultStyle,
            ),

            if (conclusion != null) ...[
              const SizedBox(height: AppSpacing.md),
              SmartMathText(
                conclusion,
                style: defaultStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: (defaultStyle.fontSize ?? 15) - 0.5,
                ),
              ),
            ],
          ],
        ),

      MultiStatementContent(
        intro: final intro,
        statements: final stmts,
        conclusion: final conclusion,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (intro != null) ...[
              SmartMathText(intro, style: defaultStyle),
              const SizedBox(height: AppSpacing.md),
            ],

            // Statements list
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.darkTextPrimary,
                borderRadius: AppRadius.roundedSm,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.borderStrong,
                  width: 1,
                ),
              ),
              child: Column(
                children: List.generate(stmts.length, (idx) {
                  final stmt = stmts[idx];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: idx == stmts.length - 1 ? 0 : AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCardElevated : AppColors.borderStrong,
                            borderRadius: AppRadius.roundedSm,
                          ),
                          child: Text(
                            stmt.marker,
                            style: AppTypography.labelSmall(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SmartMathText(
                            stmt.text,
                            style: defaultStyle.copyWith(
                              fontSize: (defaultStyle.fontSize ?? 15) - 0.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            if (conclusion != null) ...[
              const SizedBox(height: AppSpacing.md),
              SmartMathText(
                conclusion,
                style: defaultStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: (defaultStyle.fontSize ?? 15) - 0.5,
                ),
              ),
            ],
          ],
        ),
    };
  }

  Widget _buildStatementBox({
    required String label,
    required String content,
    required Color badgeColor,
    required Color badgeBg,
    required Color borderColor,
    required TextStyle style,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardElevated : AppColors.lightSurface,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: AppRadius.roundedSm,
            ),
            child: Text(
              label,
              style: AppTypography.labelSmall(color: badgeColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SmartMathText(
              content,
              style: style.copyWith(
                fontSize: (style.fontSize ?? 15) - 0.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<String> headers, List<List<String>> rows, TextStyle baseStyle) {
    final borderColor = isDark ? AppColors.lightTextSecondary : AppColors.lightBorder;
    final headerBg = isDark ? AppColors.primaryLight : AppColors.primarySubtle;
    final rowZebraBg = isDark ? AppColors.primary : AppColors.lightCard;
    final rowAltBg = isDark ? AppColors.darkCard : AppColors.darkTextPrimary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadius.roundedSm,
        border: Border.all(color: borderColor, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(color: borderColor, width: 0.8),
            verticalInside: BorderSide(color: borderColor, width: 0.8),
          ),
          columnWidths: {
            for (int i = 0; i < headers.length; i++) i: const IntrinsicColumnWidth(),
          },
          children: [
            // Header Row
            TableRow(
              decoration: BoxDecoration(color: headerBg),
              children: headers.map((h) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: SmartMathText(
                    h,
                    style: baseStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: (baseStyle.fontSize ?? 15) - 1.0,
                    ),
                  ),
                );
              }).toList(),
            ),
            // Data Rows
            ...rows.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              final bg = idx % 2 == 0 ? rowZebraBg : rowAltBg;
              return TableRow(
                decoration: BoxDecoration(color: bg),
                children: List.generate(headers.length, (colIdx) {
                  final text = colIdx < row.length ? row[colIdx] : '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: SmartMathText(
                      text,
                      style: baseStyle.copyWith(
                        fontSize: (baseStyle.fontSize ?? 15) - 1.0,
                        height: 1.4,
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchTable(
    List<({String leftMarker, String leftText, String rightMarker, String rightText})> pairs,
    TextStyle baseStyle,
  ) {
    final borderColor = isDark ? AppColors.lightTextSecondary : AppColors.lightBorder;
    final headerBg = isDark ? AppColors.primaryLight : AppColors.primarySubtle;
    final rowZebraBg = isDark ? AppColors.primary : AppColors.lightCard;
    final rowAltBg = isDark ? AppColors.darkCard : AppColors.darkTextPrimary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardElevated : AppColors.lightCard,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(color: borderColor, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: borderColor, width: 0.8),
          verticalInside: BorderSide(color: borderColor, width: 1.0),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
        },
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(color: headerBg),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'स्तम्भ I / सूची I',
                  style: AppTypography.caption(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.deskGray,
                  ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'स्तम्भ II / सूची II',
                  style: AppTypography.caption(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.deskGray,
                  ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          // Data Rows
          ...List.generate(pairs.length, (idx) {
            final p = pairs[idx];
            final rowBg = idx.isEven ? rowZebraBg : rowAltBg;
            return TableRow(
              decoration: BoxDecoration(color: rowBg),
              children: [
                // Left Item
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primaryLight : AppColors.indigoSoft,
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Text(
                          p.leftMarker,
                          style: AppTypography.labelSmall(
                            color: isDark ? AppColors.indigoText : AppColors.indigoDeep,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SmartMathText(
                          p.leftText,
                          style: baseStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: (baseStyle.fontSize ?? 15) - 0.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right Item
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.tealDark : AppColors.accentSoft,
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Text(
                          p.rightMarker,
                          style: AppTypography.labelSmall(
                            color: isDark ? AppColors.accentBright : AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SmartMathText(
                          p.rightText,
                          style: baseStyle.copyWith(
                            fontSize: (baseStyle.fontSize ?? 15) - 0.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
