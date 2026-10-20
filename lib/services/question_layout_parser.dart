/// Shared, Flutter-free parser helpers for complex exam question stems.
///
/// The SQLite vault stores many "structured" questions as one long line
/// (for example `कथन-1: ... कथन-2: ...` or `कॉलम A ... कॉलम B ...`).
/// Both the HTML booklet renderer and the native Flutter renderer need the
/// same interpretation, otherwise the same question looks different in the
/// two booklet engines.  This file contains only pure Dart so it can be used
/// from either layer.
library;

/// One row of a match-the-following table.
typedef MatchPair = ({
  String leftMarker,
  String leftText,
  String rightMarker,
  String rightText,
});

/// Parsed match-the-following data.
class MatchTableData {
  final String? intro;
  final List<MatchPair> rows;
  final String? conclusion;

  const MatchTableData({
    this.intro,
    required this.rows,
    this.conclusion,
  });
}

class QuestionLayoutParser {
  QuestionLayoutParser._();

  /// Trailing instruction such as "सही कूट चुनिए" / "Choose the correct code".
  static final RegExp conclusionPattern = RegExp(
    r'^(.*?)\s*([–—\-:ः]*\s*(?:सही\s*(?:विकल्प|उत्तर|कूट|कोड)|दिए\s*गए\s*विकल्प(?:ों)?|निम्नलिखित\s*(?:में\s*से\s*)?सही|उपर्युक्त|उपरोक्त|नीचे\s*दिए|इनमें\s*से|इनमें|Choose\s*the\s*correct|Select\s*the\s*correct|Select\s*from\s*the|Which\s*of\s*the\s*above|Code\s*:|Codes\s*:|कूट\s*:|कोड\s*:)[^\n]*)$',
    caseSensitive: false,
    dotAll: true,
  );

  static const Map<String, String> _devanagariDigits = {
    '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
    '५': '5', '६': '6', '७': '7', '८': '8', '९': '9',
  };

  /// Normalises inline structured stems without flattening their line breaks.
  ///
  /// * `कथन-1:` / `कथन 1:` / `कथन १:` become `कथन (1):`
  /// * subsequent `कथन (...)` labels start on their own line so the older
  ///   newline based parsers also keep working.
  /// * Spaces/tabs are collapsed per line, but `\n` is preserved.
  static String normalize(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Canonical kathan labels.  Handles hyphenated and Devanagari-digit forms.
    text = text.replaceAllMapped(
      RegExp(
        r'(कथन|अभिकथन|Statement)\s*[-–—]?\s*([०-९0-9]{1,2}|[A-Za-z]|[अ-ह])\s*[:：]',
        caseSensitive: false,
      ),
      (m) {
        var label = m.group(2)!;
        for (final entry in _devanagariDigits.entries) {
          label = label.replaceAll(entry.key, entry.value);
        }
        return '${m.group(1)} ($label):';
      },
    );

    // Put every explicit kathan/statement label on its own line.
    text = text.replaceAllMapped(
      RegExp(
        r'([^\n])\s+(?=(?:कथन|Statement)\s*\([^)]{1,3}\)\s*[:：\-–—.])',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n',
    );

    // Keep paragraph structure, remove noisy indentation.
    final lines = text.split('\n').map((line) {
      return line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    });
    text = lines.join('\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text;
  }

  /// Matches a list marker such as `(1)`, `1.`, `(i)`, `i.`, `(A)`, `A.`,
  /// `(अ)`, `अ.`.  A marker must either be parenthesised or be followed by a
  /// dot / closing bracket so ordinary words are not treated as markers.
  static final RegExp _markerPattern = RegExp(
    r'(?:\(\s*([A-Za-z]|[0-9]{1,2}|i{1,3}|iv|vi{0,3}|ix|xi{0,2}|[अ-ह])\s*\)'
    r'|(?:^|[\s।;,])([A-Za-z]|[0-9]{1,2}|i{1,3}|iv|vi{0,3}|ix|xi{0,2}|[अ-ह])\s*[.)])'
    r'\s*',
    caseSensitive: false,
  );

  /// Column headers such as `कॉलम A`, `सूची-II:`, `Column (B) (Examples)`.
  /// The optional trailing `(description)` is only consumed when it is longer
  /// than a list marker, so `कॉलम 'A': (1) …` does not swallow item `(1)`.
  static final RegExp columnHeaderPattern = RegExp(
    r'''(?:सूची|स्तम्भ|स्तंभ|कॉलम|तालिका|List|Column)\s*[-–—:'"“”‘’]*\s*\(?\s*(?:I{1,2}|1|2|A|B|अ|ब)\s*\)?\s*[-–—:'"“”‘’]*\s*(?:\((?![^)]{0,3}\))[^)]*\))?\s*[:\-–—.]?''',
    caseSensitive: false,
  );

  static bool _isMatchStem(String text) {
    if (RegExp(r'(?:सुमेलित|मिलान|युग्म|जोड़ा|जोड़े|Match)', caseSensitive: false)
        .hasMatch(text)) {
      return true;
    }
    if (columnHeaderPattern.hasMatch(text)) return true;
    // `1. X – (a) Y` style pair lists are unambiguous even without the word
    // "match", provided at least two dashed pairs exist.
    final dashed = RegExp(
      r'(?:\(\s*[A-Za-z0-9अ-ह]+\s*\)|[A-Za-z0-9अ-ह]+[.)])\s*[^–—\-]{1,120}?\s*[–—\-→=]\s*'
      r'(?:\(\s*[A-Za-z0-9अ-ह]+\s*\)|[A-Za-z0-9अ-ह]+[.)])',
      caseSensitive: false,
    ).allMatches(text).length;
    return dashed >= 2;
  }

  static String _familyOf(String raw) {
    final s = raw.trim();
    if (RegExp(r'^[0-9]+$').hasMatch(s)) return 'digit';
    if (RegExp(r'^[अ-ह]$').hasMatch(s)) return 'deva';
    final lower = s.toLowerCase();
    const roman = {
      'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x', 'xi', 'xii',
    };
    if (roman.contains(lower)) {
      if (s.length > 1) return 'roman';
      if ('ivxIVX'.contains(s)) return 'roman';
    }
    return 'alpha';
  }

  static String _cleanCell(String value) {
    var s = value.replaceAll(columnHeaderPattern, ' ');
    // A second column heading can be glued to the last item of the first list:
    // "(d) बहुलीकरण; प्राप्त पदार्थ: (i) ...".  Drop that trailing heading.
    s = s.replaceAll(RegExp(r'[;]\s*[^:]{1,40}:\s*$'), '');
    // Some papers repeat the match instruction after the last pair.
    s = s.replaceAll(RegExp(r'\s*(?:की|के|का)\s+मदों.*$'), '');
    s = s.replaceAll(RegExp(r'\s*(?:सही\s+)?मिलान\s*(?:है|कीजिए|करें)\s*[–—\-:.]?\s*$'), '');
    s = s
        .replaceAll(RegExp(r'''^[\s—–\-:;।,'"“”‘’]+'''), '')
        .replaceAll(RegExp(r'''[\s—–\-:;।,'"“”‘’]+$'''), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    return s;
  }

  static int? _sequenceIndex(String raw) {
    final s = raw.trim().toLowerCase();
    if (RegExp(r'^[0-9]+$').hasMatch(s)) return int.parse(s);
    const roman = {
      'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6,
      'vii': 7, 'viii': 8, 'ix': 9, 'x': 10, 'xi': 11, 'xii': 12,
    };
    if (roman.containsKey(s)) return roman[s];
    if (s.length == 1) {
      final code = s.codeUnitAt(0);
      if (code >= 97 && code <= 122) return code - 96;
    }
    return null;
  }

  /// True when the tokens form one ordered column (A,B,C… / i,ii,iii… / 1,2,3…).
  static bool _isSequentialColumn(List<_MatchToken> tokens) {
    if (tokens.length < 2) return false;
    final family = tokens.first.family;
    if (tokens.any((t) => t.family != family)) return false;
    if (family == 'deva') return true;
    final indices = tokens.map((t) => _sequenceIndex(t.rawMarker)).toList();
    if (indices.any((e) => e == null)) return false;
    for (var i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1]! + 1) return false;
    }
    return true;
  }

  static (String, String)? _splitDashedPair(String text) {
    final m = RegExp(r'^(.{1,200}?)\s*(?:–|—|−|→|=|\s-\s)\s*(.{1,200})$')
        .firstMatch(text.trim());
    if (m == null) return null;
    final left = _cleanCell(m.group(1)!);
    final right = _cleanCell(m.group(2)!);
    if (left.isEmpty || right.isEmpty) return null;
    return (left, right);
  }

  /// Parses a match-the-following stem into table rows.
  ///
  /// Supports all formats found in the vault:
  /// * `(A) X (i) Y (B) Z (ii) W`
  /// * `1. X – (a) Y   2. Z – (b) W`
  /// * `कॉलम A: (1) X (2) Y ... कॉलम B: (a) ...`
  /// * `सूची-I: (i) ... सूची-II: (a) ...`
  /// * `स्तम्भ 'अ': (i) ... स्तम्भ 'ब': (a) ...`
  static MatchTableData? parseMatchTable(String raw) {
    final text = raw.trim();
    if (text.isEmpty || !_isMatchStem(text)) return null;

    // Ranges occupied by column headings.  Their `(A)` / `(B)` markers must
    // not be mistaken for table items.
    final headerRanges = <(int, int)>[
      for (final m in columnHeaderPattern.allMatches(text)) (m.start, m.end),
    ];
    bool insideHeader(int offset) =>
        headerRanges.any((r) => offset >= r.$1 && offset < r.$2);

    final tokens = <_MatchToken>[];
    for (final m in _markerPattern.allMatches(text)) {
      final rawMarker = (m.group(1) ?? m.group(2))!.trim();
      // The non-parenthesised branch includes one leading separator in the
      // match.  Use the actual marker position when checking header ranges.
      final markerStart = text.indexOf(rawMarker, m.start);
      if (insideHeader(markerStart < 0 ? m.start : markerStart)) continue;
      final isParen = m.group(1) != null;
      tokens.add(_MatchToken(
        marker: isParen ? '($rawMarker)' : '$rawMarker.',
        rawMarker: rawMarker,
        family: _familyOf(rawMarker),
        start: m.start,
        end: m.end,
      ));
    }

    if (tokens.length < 4) return null;

    for (var i = 0; i < tokens.length; i++) {
      final end = i + 1 < tokens.length ? tokens[i + 1].start : text.length;
      tokens[i].text = _cleanCell(text.substring(tokens[i].end, end));
    }

    final rows = <MatchPair>[];

    final evenTokens = <_MatchToken>[];
    final oddTokens = <_MatchToken>[];
    for (var i = 0; i < tokens.length; i++) {
      (i.isEven ? evenTokens : oddTokens).add(tokens[i]);
    }

    if (_isSequentialColumn(evenTokens) && _isSequentialColumn(oddTokens)) {
      // Alternating columns, e.g. A/i/B/ii/… or 1/(a)/2/(b)/… .  The two
      // columns may have different lengths (a match question often adds an
      // extra distractor to column II).
      final rowCount = evenTokens.length > oddTokens.length
          ? evenTokens.length
          : oddTokens.length;
      for (var i = 0; i < rowCount; i++) {
        rows.add((
          leftMarker: i < evenTokens.length ? evenTokens[i].marker : '',
          leftText: i < evenTokens.length ? evenTokens[i].text : '',
          rightMarker: i < oddTokens.length ? oddTokens[i].marker : '',
          rightText: i < oddTokens.length ? oddTokens[i].text : '',
        ));
      }
    } else {
      // Two contiguous lists, e.g. (1)(2)(3)(4) followed by (a)(b)(c)(d).
      final runs = <List<_MatchToken>>[];
      for (final token in tokens) {
        if (runs.isEmpty || runs.last.last.family != token.family) {
          runs.add([token]);
        } else {
          runs.last.add(token);
        }
      }
      if (runs.length == 2) {
        final rowCount =
            runs[0].length > runs[1].length ? runs[0].length : runs[1].length;
        for (var i = 0; i < rowCount; i++) {
          rows.add((
            leftMarker: i < runs[0].length ? runs[0][i].marker : '',
            leftText: i < runs[0].length ? runs[0][i].text : '',
            rightMarker: i < runs[1].length ? runs[1][i].marker : '',
            rightText: i < runs[1].length ? runs[1][i].text : '',
          ));
        }
      } else if (runs.length == 1) {
        // Each item is already a pair: "1. खट्टा दूध – लैक्टिक अम्ल".
        final split = <(String, String)?>[
          for (final token in runs[0]) _splitDashedPair(token.text),
        ];
        if (split.isNotEmpty && split.every((e) => e != null)) {
          for (var i = 0; i < runs[0].length; i++) {
            final pair = split[i]!;
            rows.add((
              leftMarker: runs[0][i].marker,
              leftText: pair.$1,
              rightMarker: '',
              rightText: pair.$2,
            ));
          }
        }
      }
    }

    if (rows.length < 2) return null;

    // Anything after the last right-hand item is either a conclusion
    // instruction or noise.
    var lastRight = rows.last.rightText;
    String? conclusion;
    var trailing = '';
    final cm = conclusionPattern.firstMatch(lastRight);
    if (cm != null) {
      lastRight = _cleanCell(cm.group(1)!);
      conclusion = cm.group(2)!.trim();
    } else {
      final tail = RegExp(r'^(.*?)((?:कूट|कोड|Codes?|Choose|Select|उत्तर)\s*[:：].*)$',
              caseSensitive: false, dotAll: true)
          .firstMatch(lastRight);
      if (tail != null) {
        lastRight = _cleanCell(tail.group(1)!);
        trailing = tail.group(2)!.trim();
      }
    }
    rows[rows.length - 1] = (
      leftMarker: rows.last.leftMarker,
      leftText: rows.last.leftText,
      rightMarker: rows.last.rightMarker,
      rightText: lastRight,
    );
    conclusion ??= trailing.isEmpty ? null : trailing;

    final intro = text.substring(0, tokens.first.start).trim();
    return MatchTableData(
      intro: intro.isEmpty ? null : intro,
      rows: rows,
      conclusion: (conclusion != null && conclusion.isNotEmpty)
          ? conclusion
          : null,
    );
  }
}

class _MatchToken {
  final String marker;
  final String rawMarker;
  final String family;
  final int start;
  final int end;
  String text = '';

  _MatchToken({
    required this.marker,
    required this.rawMarker,
    required this.family,
    required this.start,
    required this.end,
  });
}
