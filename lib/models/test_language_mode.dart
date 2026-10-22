/// Three distinct language presentation modes for exam booklet, CBT player, and solutions
enum TestLanguageMode {
  onlyHindi,   // केवल हिन्दी (Pure Hindi question & options, no English clutter)
  bilingual,   // हिन्दी + English (Clear Hindi first, followed by distinct separate English)
  onlyEnglish, // Only English (English medium question & options)
}

extension TestLanguageModeExt on TestLanguageMode {
  String get badgeLabel {
    switch (this) {
      case TestLanguageMode.onlyHindi:
        return 'हिन्दी';
      case TestLanguageMode.bilingual:
        return 'HI + EN';
      case TestLanguageMode.onlyEnglish:
        return 'English';
    }
  }

  String get title {
    switch (this) {
      case TestLanguageMode.onlyHindi:
        return 'केवल हिन्दी';
      case TestLanguageMode.bilingual:
        return 'हिन्दी + अंग्रेज़ी (द्विभाषी)';
      case TestLanguageMode.onlyEnglish:
        return 'केवल अंग्रेज़ी';
    }
  }

  String get description {
    switch (this) {
      case TestLanguageMode.onlyHindi:
        return 'प्रश्न एवं सभी विकल्प केवल हिन्दी में देखें';
      case TestLanguageMode.bilingual:
        return 'पहले हिन्दी, फिर नीचे साफ़ अंग्रेज़ी अनुवाद';
      case TestLanguageMode.onlyEnglish:
        return 'प्रश्न एवं विकल्प अंग्रेज़ी भाषा में देखें';
    }
  }
}
