import 'dart:convert';

/// Question Model matching the CDN pack schema and SQLite store
class Question {
  final String id; // 'k' hash
  final String exams; // 'e' (utet1, ctet1)
  final String section; // 's' (cdp, hindi, english, math, evs)
  final int topicIndex; // 't' index in manifest topics
  final String? topicName; // resolved topic title
  final int difficulty; // 'd' (1, 2, 3)
  final String qHindi; // 'qh'
  final List<String> optionsHindi; // 'oh' [a, b, c, d]
  final String? qEnglish; // 'qe'
  final List<String>? optionsEnglish; // 'oe'
  final int answer; // 'a' (0=A, 1=B, 2=C, 3=D)
  final double pScore; // 'p' mathematical probability score
  final String? years; // 'y' repeated years (e.g. "2021,2025")
  final String? sourceTag; // clean extracted source exam info e.g. "UTET 12 Nov 2013", "CTET 2018"
  final String? passageId; // 'pid'
  final int? seqInPassage; // 'n'
  final int? questionNumber; // optional question number (1-150) from official paper appearances

  const Question({
    required this.id,
    required this.exams,
    required this.section,
    required this.topicIndex,
    this.topicName,
    required this.difficulty,
    required this.qHindi,
    required this.optionsHindi,
    this.qEnglish,
    this.optionsEnglish,
    required this.answer,
    required this.pScore,
    this.years,
    this.sourceTag,
    this.passageId,
    this.seqInPassage,
    this.questionNumber,
  });

  bool get isBilingual =>
      qEnglish != null &&
      qEnglish!.trim().isNotEmpty &&
      qHindi.trim().toLowerCase() != qEnglish!.trim().toLowerCase() &&
      hasDevanagari;
  bool get hasEnglish => isBilingual;
  bool get hasDevanagari => RegExp(r'[\u0900-\u097F]').hasMatch(qHindi);
  bool get isPyq => (years != null && years!.trim().isNotEmpty) || (sourceTag != null && sourceTag!.trim().isNotEmpty);

  /// Formatted official source badge (e.g. "UTET 12 Nov 2013", "CTET 2018", or "UTET 2021,2025")
  String? get displayTag {
    if (sourceTag != null && sourceTag!.trim().isNotEmpty) {
      final tag = sourceTag!.trim();
      if (RegExp(r'CTET\s*(?:Bank|CDP|PW|Sets|Practice|Questions)', caseSensitive: false).hasMatch(tag)) {
        final yMatch = RegExp(r'(20\d\d|19\d\d)').firstMatch(tag);
        if (yMatch != null) return 'CTET ${yMatch.group(1)}';
        if (years != null && years!.trim().isNotEmpty) {
          return 'CTET $years';
        }
        return 'CTET PYQ';
      }
      return tag;
    }
    if (years != null && years!.trim().isNotEmpty) {
      final examPrefix = exams.toLowerCase().contains('ctet') ? 'CTET' : 'UTET';
      return '$examPrefix $years';
    }
    return null;
  }

  factory Question.fromPackJson(Map<String, dynamic> json, {String? topic}) {
    List<String> parseOptions(dynamic val) {
      if (val is List) {
        return val.map((e) => e?.toString() ?? '').toList();
      }
      return [];
    }

    // 1. Clean Question Hindi & extract leaked metadata if any
    final qhClean = QuestionSanitizer.clean(json['qh'] as String? ?? '');
    String? detectedTag = qhClean.tag;
    String? detectedYear = qhClean.year;

    // 2. Clean Options Hindi & extract leaked metadata if any
    final List<String> rawOh = parseOptions(json['oh']);
    final List<String> cleanedOh = [];
    for (final opt in rawOh) {
      final res = QuestionSanitizer.clean(opt);
      cleanedOh.add(res.cleaned);
      if (res.tag != null && (detectedTag == null || detectedTag.isEmpty)) {
        detectedTag = res.tag;
      }
      if (res.year != null && (detectedYear == null || detectedYear.isEmpty)) {
        detectedYear = res.year;
      }
    }

    // 3. Clean Question English & extract leaked metadata if any
    final qeClean = QuestionSanitizer.clean(json['qe'] as String?);
    if (qeClean.tag != null && (detectedTag == null || detectedTag.isEmpty)) {
      detectedTag = qeClean.tag;
    }
    if (qeClean.year != null && (detectedYear == null || detectedYear.isEmpty)) {
      detectedYear = qeClean.year;
    }

    // 4. Clean Options English & extract leaked metadata if any
    List<String>? cleanedOe;
    if (json['oe'] != null) {
      cleanedOe = [];
      final parsedOe = parseOptions(json['oe']);
      for (int i = 0; i < parsedOe.length; i++) {
        final res = QuestionSanitizer.clean(parsedOe[i]);
        final cleanedText = res.cleaned.trim();
        // Fall back to Hindi option if English is blank
        if (cleanedText.isEmpty && i < cleanedOh.length) {
          cleanedOe.add(cleanedOh[i]);
        } else {
          cleanedOe.add(res.cleaned);
        }
        if (res.tag != null && (detectedTag == null || detectedTag.isEmpty)) {
          detectedTag = res.tag;
        }
        if (res.year != null && (detectedYear == null || detectedYear.isEmpty)) {
          detectedYear = res.year;
        }
      }
    }

    final rawYears = json['y'] as String?;
    final finalYears = (rawYears != null && rawYears.trim().isNotEmpty)
        ? rawYears
        : detectedYear;

    final norm = _normalizeBilingual(
      rawQh: qhClean.cleaned,
      rawQe: qeClean.cleaned.isNotEmpty ? qeClean.cleaned : null,
      rawOh: cleanedOh,
      rawOe: cleanedOe,
    );

    return Question(
      id: json['k'] as String? ?? '',
      exams: json['e'] as String? ?? '',
      section: json['s'] as String? ?? '',
      topicIndex: (json['t'] as num?)?.toInt() ?? 0,
      topicName: topic,
      difficulty: (json['d'] as num?)?.toInt() ?? 2,
      qHindi: norm.qh,
      optionsHindi: norm.oh,
      qEnglish: norm.qe,
      optionsEnglish: norm.oe,
      answer: (json['a'] as num?)?.toInt() ?? 0,
      pScore: (json['p'] as num?)?.toDouble() ?? 0.0,
      years: finalYears,
      sourceTag: detectedTag,
      passageId: json['pid'] as String?,
      seqInPassage: (json['n'] as num?)?.toInt(),
    );
  }

  factory Question.fromOfficialJson(Map<String, dynamic> json) {
    final rawOh = json['options_hi'];
    final List<String> oh = rawOh is List ? rawOh.map((e) => e?.toString() ?? '').toList() : [];
    final rawOe = json['options_en'];
    final List<String>? oe = rawOe is List ? rawOe.map((e) => e?.toString() ?? '').toList() : null;

    return Question(
      id: json['id'] as String? ?? '',
      exams: json['exams'] as String? ?? 'utet1',
      section: json['section'] as String? ?? '',
      topicIndex: (json['topic_index'] as num?)?.toInt() ?? 0,
      topicName: json['topic'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 2,
      qHindi: json['q_hi'] as String? ?? '',
      optionsHindi: oh,
      qEnglish: json['q_en'] as String?,
      optionsEnglish: oe,
      answer: (json['ans'] as num?)?.toInt() ?? 0,
      pScore: (json['p_score'] as num?)?.toDouble() ?? 0.8,
      years: json['years'] as String?,
      sourceTag: json['source'] as String?,
      passageId: json['pid'] as String?,
      seqInPassage: (json['pseq'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'exams': exams,
      'section': section,
      'topic_index': topicIndex,
      'topic_name': topicName,
      'difficulty': difficulty,
      'q_hindi': qHindi,
      'options_hindi': jsonEncode(optionsHindi),
      'q_english': qEnglish,
      'options_english': optionsEnglish != null ? jsonEncode(optionsEnglish) : null,
      'answer': answer,
      'p_score': pScore,
      'years': years,
      'source_tag': sourceTag,
      'passage_id': passageId,
      'seq_in_passage': seqInPassage,
    };
  }

  /// Full serializable representation used by completed-test history.
  ///
  /// The key names intentionally match the SQLite columns so the same
  /// [Question.fromDbMap] parser can safely reload old and new history rows.
  Map<String, dynamic> toJson() {
    return {
      ...toDbMap(),
      'question_number': questionNumber,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) =>
      Question.fromDbMap(json);

  factory Question.fromDbMap(Map<String, dynamic> map) {
    List<String> decodeOptions(dynamic raw) {
      if (raw == null) return [];
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
      return [];
    }

    final rawQh = map['q_hindi'] as String? ?? '';
    final qhClean = QuestionSanitizer.clean(rawQh);
    String? detectedTag = map['source_tag'] as String? ?? qhClean.tag;
    String? detectedYear = qhClean.year;

    final rawOh = decodeOptions(map['options_hindi']);
    final List<String> cleanedOh = [];
    for (final opt in rawOh) {
      final res = QuestionSanitizer.clean(opt);
      cleanedOh.add(res.cleaned);
      if (res.tag != null && (detectedTag == null || detectedTag.isEmpty)) {
        detectedTag = res.tag;
      }
      if (res.year != null && (detectedYear == null || detectedYear.isEmpty)) {
        detectedYear = res.year;
      }
    }

    final rawQe = map['q_english'] as String?;
    final qeClean = QuestionSanitizer.clean(rawQe);
    if (qeClean.tag != null && (detectedTag == null || detectedTag.isEmpty)) {
      detectedTag = qeClean.tag;
    }
    if (qeClean.year != null && (detectedYear == null || detectedYear.isEmpty)) {
      detectedYear = qeClean.year;
    }

    List<String>? cleanedOe;
    if (map['options_english'] != null) {
      cleanedOe = [];
      final parsedOe = decodeOptions(map['options_english']);
      for (int i = 0; i < parsedOe.length; i++) {
        final res = QuestionSanitizer.clean(parsedOe[i]);
        final cleanedText = res.cleaned.trim();
        // Fall back to Hindi option if English is blank
        if (cleanedText.isEmpty && i < cleanedOh.length) {
          cleanedOe.add(cleanedOh[i]);
        } else {
          cleanedOe.add(res.cleaned);
        }
        if (res.tag != null && (detectedTag == null || detectedTag.isEmpty)) {
          detectedTag = res.tag;
        }
        if (res.year != null && (detectedYear == null || detectedYear.isEmpty)) {
          detectedYear = res.year;
        }
      }
    }

    final rawYears = map['years'] as String?;
    final finalYears = (rawYears != null && rawYears.trim().isNotEmpty)
        ? rawYears
        : detectedYear;

    final norm = _normalizeBilingual(
      rawQh: qhClean.cleaned,
      rawQe: qeClean.cleaned.isNotEmpty ? qeClean.cleaned : null,
      rawOh: cleanedOh,
      rawOe: cleanedOe,
    );

    return Question(
      id: map['id'] as String? ?? '',
      exams: map['exams'] as String? ?? '',
      section: map['section'] as String? ?? '',
      topicIndex: (map['topic_index'] as num?)?.toInt() ?? 0,
      topicName: map['topic_name'] as String?,
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 2,
      qHindi: norm.qh,
      optionsHindi: norm.oh,
      qEnglish: norm.qe,
      optionsEnglish: norm.oe,
      answer: (map['answer'] as num?)?.toInt() ?? 0,
      pScore: (map['p_score'] as num?)?.toDouble() ?? 0.0,
      years: finalYears,
      sourceTag: detectedTag,
      passageId: map['passage_id'] as String?,
      seqInPassage: (map['seq_in_passage'] as num?)?.toInt(),
      questionNumber: (map['question_number'] as num?)?.toInt(),
    );
  }

  static ({String qh, String? qe, List<String> oh, List<String>? oe}) _normalizeBilingual({
    required String rawQh,
    required String? rawQe,
    required List<String> rawOh,
    required List<String>? rawOe,
  }) {
    String finalQh = rawQh;
    String? finalQe = rawQe;
    final List<String> finalOh = List<String>.from(rawOh);
    List<String>? finalOe = rawOe != null ? List<String>.from(rawOe) : null;

    // Check if options are inverted (Hindi contains only ASCII, English contains Devanagari)
    if (finalOe != null && finalOe.length == finalOh.length) {
      final ohHasDev = finalOh.any((s) => s.runes.any((r) => r >= 0x0900 && r <= 0x097F));
      final oeHasDev = finalOe.any((s) => s.runes.any((r) => r >= 0x0900 && r <= 0x097F));
      final ohHasAscii = finalOh.any((s) => s.contains(RegExp(r'[a-zA-Z]')));

      if (!ohHasDev && ohHasAscii && oeHasDev) {
        final temp = List<String>.from(finalOh);
        finalOh.clear();
        finalOh.addAll(finalOe);
        finalOe = temp;
      }
    }

    // Check if question stems are inverted
    if (finalQe != null && finalQe.trim().isNotEmpty) {
      final qhHasDev = finalQh.runes.any((r) => r >= 0x0900 && r <= 0x097F);
      final qeHasDev = finalQe.runes.any((r) => r >= 0x0900 && r <= 0x097F);
      final qhHasAscii = finalQh.contains(RegExp(r'[a-zA-Z]'));

      if (!qhHasDev && qhHasAscii && qeHasDev) {
        final temp = finalQh;
        finalQh = finalQe;
        finalQe = temp;
      }
    }

    return (qh: finalQh, qe: finalQe, oh: finalOh, oe: finalOe);
  }
}

/// Sanitizes questions & options by extracting leaked exam/year tags and placing them in their proper place
class QuestionSanitizer {
  static final RegExp _tagPattern = RegExp(
    r'[\s–—-]*(?:(?:\(|\[|\{)?\s*\b(?:UT|UK|UP|Hariyana|Haryana|HTET|Rajsthan|Rajasthan|Punjab|PSTET|Bihar|BTET|MP|MPTET|CTET)\b\s*[-_]?\s*(?:TET|Paper|IInd|Ist|I|II|Class|\d{4})[^\n]*?(?:19\d\d|20\d\d)[^\n]*?(?:\)|\]|\})?|(?:UT\s*TET|CTET|UPTET|HTET|REET)\b[^\n]*?(?:Paper|Class|Held|\d{4})[^\n]*|CTET[^\n]*?(?:PW|Sets|Solved)[^\n]*)',
    caseSensitive: false,
  );

  static final RegExp _yearPattern = RegExp(r'(19\d\d|20\d\d)');

  static String stripHtml(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    var t = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        // Keep paragraph / line structure instead of flattening everything
        // into a single line.  Exam stems rely on these breaks for kathan,
        // match-the-following and multi-statement layout.
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(?:p|div|li|tr|h[1-6])\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    // Defensive cleanup of markdown headers, options labels, and leaked checkmarks
    t = t.replaceAll(RegExp(r'^\s*#{1,6}\s*(?:Q\.?\s*)?\d*[\.\:\-]?\s*', multiLine: true), '');
    t = t.replaceAll(RegExp(r'\s*\*\*Options\s*(?:/\s*विकल्प)?\*\*\s*', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'[✅✓]'), '');
    t = t.replaceAll(RegExp(r'^\s*\([A-Da-d1-4]\)\s*[\.\:\-]\s+(?=[अ-हA-Za-z])'), '');
    t = t.replaceAll(RegExp(r'^\s*#{1,6}\s*'), '');

    final lines = t.split('\n').map((line) {
      return line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    });
    t = lines.join('\n');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }

  static ({String cleaned, String? tag, String? year}) clean(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (cleaned: raw ?? '', tag: null, year: null);
    }
    final text = stripHtml(raw);
    final match = _tagPattern.firstMatch(text);
    if (match == null) {
      return (cleaned: text, tag: null, year: null);
    }

    final rawTag = match.group(0)!.trim().replaceAll(RegExp(r'^[–—\-()[\]{}\s]+|[–—\-()[\]{}\s]+$'), '');
    final cleaned = text.substring(0, match.start).trim().replaceAll(RegExp(r'[–—\-:\s]+$'), '');

    final yMatch = _yearPattern.firstMatch(rawTag);
    final year = yMatch?.group(1);

    String tag = rawTag
        .replaceAll(RegExp(r'\(Class\s*\(?[I|1|2|V|X|\-]+\)?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'Paper\s*[-_]?\s*(?:I|II|1|2|IInd|Ist)', caseSensitive: false), '')
        .replaceAll(RegExp(r'भाषा\s*[-_]?\s*\d+'), '')
        .replaceAll(RegExp(r'UT\s*TET', caseSensitive: false), 'UTET')
        .replaceAll(RegExp(r'Hariyana\s*TET', caseSensitive: false), 'HTET')
        .replaceAll(RegExp(r'Rajsthan\s*TET', caseSensitive: false), 'REET')
        .replaceAll(RegExp(r'Punjab\s*TET', caseSensitive: false), 'PSTET')
        .replaceAll(RegExp(r'Held on', caseSensitive: false), '')
        .replaceAll(RegExp(r'Solved Paper.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'Practice Sets.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'CTET\s*Bank.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'PW\s*Sets.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^[–—\-:,()[\]{}\s]+|[–—\-:,()[\]{}\s]+$'), '');

    if (tag.isEmpty && year != null) {
      tag = 'PYQ $year';
    }

    return (cleaned: cleaned, tag: tag.isNotEmpty ? tag : null, year: year);
  }
}
