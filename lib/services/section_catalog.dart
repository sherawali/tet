/// Single source of truth for the section codes that the vault uses.
///
/// The vault stores eleven section codes (`cdp`, `hindi`, `english`,
/// `hindi_2`, `english_1`, `lang1_hindi`, `lang2_english`, `math`, `evs`,
/// `math_science`, `social_studies`).  Every screen that shows a section
/// name must use this catalogue, otherwise a raw code such as
/// `LANG1_HINDI` leaks into the user interface.
class SectionCatalog {
  const SectionCatalog._();

  /// Canonical order used by the subject grid and the result analysis.
  static const List<String> order = <String>[
    'cdp',
    'hindi',
    'english',
    'hindi_2',
    'english_1',
    'lang1_hindi',
    'lang2_english',
    'math',
    'evs',
    'math_science',
    'social_studies',
  ];

  static const Map<String, ({String hi, String en})> _labels =
      <String, ({String hi, String en})>{
    'cdp': (
      hi: 'बाल विकास एवं शिक्षा विज्ञान',
      en: 'Child Development and Pedagogy'
    ),
    'hindi': (hi: 'हिन्दी भाषा प्रथम', en: 'Hindi Language I'),
    'english': (hi: 'अंग्रेजी भाषा द्वितीय', en: 'English Language II'),
    'hindi_2': (hi: 'हिन्दी भाषा द्वितीय', en: 'Hindi Language II'),
    'english_1': (hi: 'अंग्रेजी भाषा प्रथम', en: 'English Language I'),
    'lang1_hindi': (hi: 'भाषा प्रथम – हिन्दी', en: 'Language I – Hindi'),
    'lang2_english': (hi: 'भाषा द्वितीय – अंग्रेज़ी', en: 'Language II – English'),
    'math': (hi: 'गणित', en: 'Mathematics'),
    'evs': (hi: 'पर्यावरण अध्ययन', en: 'Environmental Studies'),
    'math_science': (hi: 'गणित एवं विज्ञान', en: 'Mathematics & Science'),
    'social_studies': (hi: 'सामाजिक अध्ययन', en: 'Social Studies'),
    // Legacy codes that older papers still use.
    'science': (hi: 'सामान्य विज्ञान', en: 'General Science'),
    'social': (hi: 'सामाजिक अध्ययन', en: 'Social Science'),
    'sst': (hi: 'सामाजिक अध्ययन', en: 'Social Science'),
    'sanskrit': (hi: 'संस्कृत भाषा द्वितीय', en: 'Sanskrit Language II'),
  };

  /// The label of a section code in both languages.
  static ({String hi, String en}) label(String code) {
    final key = code.toLowerCase().trim();
    return _labels[key] ??
        (hi: _pretty(key), en: _pretty(key));
  }

  /// The label of a section code in the requested language.
  static String name(String code, {required bool hindi}) {
    final l = label(code);
    return hindi ? l.hi : l.en;
  }

  /// Short label used on chips and badges.
  static String short(String code) {
    switch (code.toLowerCase()) {
      case 'cdp':
        return 'CDP';
      case 'math':
        return 'MATH';
      case 'evs':
        return 'EVS';
      case 'math_science':
        return 'M&S';
      case 'social_studies':
        return 'SST';
      case 'lang1_hindi':
        return 'हिंदी';
      case 'lang2_english':
        return 'English';
      default:
        return code.toUpperCase();
    }
  }

  /// Sections that can appear in a paper of the given level.
  static List<String> forPaper(int paper) {
    if (paper == 2) {
      return const <String>[
        'cdp',
        'lang1_hindi',
        'lang2_english',
        'math_science',
        'social_studies',
        'hindi_2',
        'english_1',
        'hindi',
        'english',
      ];
    }
    return const <String>[
      'cdp',
      'hindi',
      'english',
      'lang1_hindi',
      'lang2_english',
      'math',
      'evs',
    ];
  }

  static String _pretty(String code) {
    if (code.isEmpty) return '';
    return code.replaceAll('_', ' ').toUpperCase();
  }
}
