/// Mock Generation Modes & Configuration
enum MockMode {
  predicted, // 🎯 अनुमानित पेपर (High p_score)
  repeat, // 🔁 बार-बार आने वाले (2+ years repeated)
  pyq, // 📜 केवल PYQ (Authentic past papers)
  fresh, // ✨ फ्रेश अभ्यास (Fresh conceptual questions)
  mixed, // ⚖️ मिश्रित (Balanced daily practice)
}

extension MockModeDetails on MockMode {
  String get titleHindi {
    switch (this) {
      case MockMode.predicted:
        return '🎯 अनुमानित प्रश्न-पत्र';
      case MockMode.repeat:
        return '🔁 बार-बार आने वाले प्रश्न';
      case MockMode.pyq:
        return '📜 केवल PYQ';
      case MockMode.fresh:
        return '✨ ताज़े विषय अभ्यास';
      case MockMode.mixed:
        return '⚖️ मिश्रित प्रश्न-पत्र';
    }
  }

  String get shortTitle {
    switch (this) {
      case MockMode.predicted:
        return 'अनुमानित';
      case MockMode.repeat:
        return 'बार-बार आने वाले';
      case MockMode.pyq:
        return 'केवल PYQ';
      case MockMode.fresh:
        return 'फ्रेश प्रश्न';
      case MockMode.mixed:
        return 'मिश्रित';
    }
  }

  String get description {
    switch (this) {
      case MockMode.predicted:
        return 'विगत वर्षों के गहन विश्लेषण से चुने गए उच्च संभावना वाले प्रश्न — परीक्षा से पहले रामबाण।';
      case MockMode.repeat:
        return 'जो टॉपिक्स और कॉन्सेप्ट 2 या अधिक बार परीक्षा में दोहराए गए हैं — सबसे तेज़ रिवीजन।';
      case MockMode.pyq:
        return 'विगत वर्षों के प्रामाणिक बोर्ड प्रश्न-पत्रों से सीधे चयनित प्रश्न।';
      case MockMode.fresh:
        return 'वही महत्वपूर्ण टॉपिक्स, पर नए प्रश्न ताकि रटने की बजाय समझ की परख हो सके।';
      case MockMode.mixed:
        return 'विगत वर्ष प्रश्न + नवीन मॉडल प्रश्न — दैनिक अभ्यास के लिए सर्वोत्तम।';
    }
  }

  double get power {
    switch (this) {
      case MockMode.predicted:
        return 3.0;
      case MockMode.repeat:
        return 4.0;
      case MockMode.pyq:
        return 2.0;
      case MockMode.fresh:
        return 0.5;
      case MockMode.mixed:
        return 1.5;
    }
  }
}

class MockConfig {
  final MockMode mode;
  final String exam; // 'utet1' or 'ctet1'
  final String? sectionFilter; // null for full 150Q test, or 'cdp', 'hindi', etc.
  final int totalQuestions; // 150 for full, 30 for single section
  final int timeLimitMinutes; // 150 min for full, 30 for single section
  final int seed;

  const MockConfig({
    required this.mode,
    this.exam = 'utet1',
    this.sectionFilter,
    this.totalQuestions = 150,
    this.timeLimitMinutes = 150,
    required this.seed,
  });
}
