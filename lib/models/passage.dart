/// Reading comprehension passage model
class Passage {
  final String id;
  final String kind; // prose, poem
  final String dirText; // Direction instructions (e.g. "प्रश्न 31 से 35 तक...")
  final String body; // Full text/poem

  const Passage({
    required this.id,
    required this.kind,
    required this.dirText,
    required this.body,
  });

  static String _cleanHtml(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    var t = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return t;
  }

  static String _cleanDir(String? dir) {
    var d = _cleanHtml(dir);
    // Remove any remaining <b> or </b> remnants and duplicate prefixes
    d = d.replaceAll(RegExp(r'<\/?b>', caseSensitive: false), '');
    d = d.replaceFirst(RegExp(r'^(?:निर्देश|Directions?)\s*[:：\-–—\s]*', caseSensitive: false), '');
    // Strip bracketed text containing digits e.g. (प्रश्न 91 से 96), (Q. Nos. 91 to 99), (121-128)
    d = d.replaceAll(RegExp(r'\([^)]*\d+[^)]*\)'), '');
    // English: "and answer questions 91-99" -> "and answer the questions that follow."
    d = d.replaceAll(RegExp(r'and\s+answer\s+(?:the\s+)?questions?\s*\d+\s*(?:–|-|to)\s*\d+\.?', caseSensitive: false), 'and answer the questions that follow.');
    // Sanskrit: प्रश्नानां 91-99 -> प्रश्नानां
    d = d.replaceAll(RegExp(r'प्रश्नानां\s*\d+[–\-to\s]+\d+'), 'प्रश्नानां');
    // Hindi: प्रश्न 121-128 -> प्रश्नों के उत्तर दीजिए
    d = d.replaceAll(RegExp(r'प्रश्न\s*\d+[–\-to\s\d]+(?:के\s+उत्तर\s+दीजिए)?'), 'प्रश्नों के उत्तर दीजिए');
    d = d.replaceAll(RegExp(r'\s*,\s*by selecting', caseSensitive: false), ' by selecting');
    d = d.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return d;
  }

  bool get isPoem => kind.toLowerCase() == 'poem';

  /// Guaranteed clean directive text without HTML or prefixes
  String get cleanDirText => _cleanDir(dirText);

  /// Guaranteed clean body with poetry verses preserved
  String get cleanBody => _cleanHtml(body);

  /// User-facing display directive with standard exam instruction
  String get displayDir {
    final cd = cleanDirText;
    if (cd.isNotEmpty) return cd;
    return isPoem
        ? 'दी गई कविता/काव्यांश को पढ़कर पूछे गए प्रश्नों के सर्वाधिक उपयुक्त विकल्प चुनिए।'
        : 'दिए गए गद्यांश को पढ़कर पूछे गए प्रश्नों के सर्वाधिक उपयुक्त विकल्प चुनिए।';
  }

  factory Passage.fromJson(Map<String, dynamic> json) {
    final rawDir = json['d'] as String? ?? json['dir_text'] as String? ?? json['dirText'] as String? ?? '';
    final rawBody = json['b'] as String? ?? json['body'] as String? ?? '';
    return Passage(
      id: json['id'] as String? ?? json['pid'] as String? ?? '',
      kind: json['k'] as String? ?? json['kind'] as String? ?? 'prose',
      dirText: _cleanDir(rawDir),
      body: _cleanHtml(rawBody),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kind': kind,
      'dirText': cleanDirText,
      'body': cleanBody,
    };
  }

  factory Passage.fromMap(Map<String, dynamic> map) {
    final rawDir = map['dirText'] as String? ?? map['dir_text'] as String? ?? '';
    final rawBody = map['body'] as String? ?? '';
    return Passage(
      id: map['id'] as String? ?? '',
      kind: map['kind'] as String? ?? 'prose',
      dirText: _cleanDir(rawDir),
      body: _cleanHtml(rawBody),
    );
  }
}
