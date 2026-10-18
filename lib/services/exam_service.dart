import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/test_session.dart';
import '../screens/cbt_exam_screen.dart';
import '../screens/html_booklet_screen.dart';

enum AppExam {
  utet,
  ctet,
}

enum AppPaper {
  paper1, // कक्षा 1-5 (प्राथमिक स्तर / Primary Level)
  paper2, // कक्षा 6-8 (उच्च प्राथमिक / Junior Level)
}

enum AppStream {
  mathScience, // गणित एवं विज्ञान (Mathematics & Science · 60 प्रश्न)
  socialStudies, // सामाजिक अध्ययन (Social Studies · 60 प्रश्न)
}

enum AppTestMode {
  cbt,      // 📱 CBT मोड (1 प्रश्न प्रति स्क्रीन · अनुशंसित)
  booklet,  // 📄 प्रश्न-पुस्तिका मोड (OMR पेपर)
}

enum BookletEngine {
  native, // ⚡ नेटिव फ़्लटर (120 FPS · अल्ट्रा-फास्ट · डिफ़ॉल्ट)
  html,   // 🌐 HTML वेबव्यू (क्लासिक प्रिंट बैकअप)
}

class ExamService {
  static final ExamService instance = ExamService._internal();
  ExamService._internal();

  static const String _prefExamKey = 'selected_exam_target';
  static const String _prefPaperKey = 'selected_exam_paper';
  static const String _prefStreamKey = 'selected_paper2_stream';
  static const String _prefTestModeKey = 'selected_test_mode';
  static const String _prefBookletEngineKey = 'selected_booklet_engine';
  static const String _prefLang1Key = 'selected_tet_lang1';
  static const String _prefLang2Key = 'selected_tet_lang2';

  final ValueNotifier<AppExam> currentExam = ValueNotifier<AppExam>(AppExam.utet);
  final ValueNotifier<AppPaper> currentPaper = ValueNotifier<AppPaper>(AppPaper.paper1);
  final ValueNotifier<AppStream> currentStream = ValueNotifier<AppStream>(AppStream.mathScience);
  final ValueNotifier<AppTestMode> currentTestMode = ValueNotifier<AppTestMode>(AppTestMode.booklet);
  final ValueNotifier<BookletEngine> bookletEngine = ValueNotifier<BookletEngine>(BookletEngine.native);
  final ValueNotifier<String> currentLang1 = ValueNotifier<String>('hindi');
  final ValueNotifier<String> currentLang2 = ValueNotifier<String>('english');

  bool get isCbtMode => currentTestMode.value == AppTestMode.cbt;
  bool get isBookletMode => currentTestMode.value == AppTestMode.booklet;
  bool get isNativeBookletEngine => bookletEngine.value == BookletEngine.native;
  bool get isHtmlBookletEngine => bookletEngine.value == BookletEngine.html;
  bool get isSocialStream => currentStream.value == AppStream.socialStudies;
  bool get isMathScienceStream => currentStream.value == AppStream.mathScience;

  bool get isUtet => currentExam.value == AppExam.utet;
  bool get isCtet => currentExam.value == AppExam.ctet;

  bool get isPaper1 => currentPaper.value == AppPaper.paper1;
  bool get isPaper2 => currentPaper.value == AppPaper.paper2;
  int get selectedPaper => isPaper1 ? 1 : 2;
  AppStream get activeStream => currentStream.value;

  String get paperCode => isPaper1 ? '1' : '2';

  /// Exact exam code mapped to database: 'utet1', 'utet2', 'ctet1', 'ctet2'
  String get examCode => '${isUtet ? "utet" : "ctet"}$paperCode';

  String get shortName => isUtet ? 'UTET' : 'CTET';

  String get paperBadge => isPaper1 ? 'Paper-I' : 'Paper-II';

  String get shortNameWithPaper => '$shortName $paperBadge';

  String get paperTitleHindi => isPaper1 ? 'पेपर-I (कक्षा 1–5 प्राथमिक)' : 'पेपर-II (कक्षा 6–8 उच्च प्राथमिक/जूनियर)';
  String get paperTitleEnglish => isPaper1 ? 'Paper-I (Class 1–5 Primary)' : 'Paper-II (Class 6–8 Upper Primary)';

  String get targetClassHindi => isPaper1 ? 'प्राथमिक स्तर (कक्षा I–V)' : 'उच्च प्राथमिक स्तर (कक्षा VI–VIII)';
  String get targetClassEnglish => isPaper1 ? 'Primary Level (Class I–V)' : 'Upper Primary Level (Class VI–VIII)';

  String get fullNameHindi =>
      isUtet ? 'उत्तराखण्ड शिक्षक पात्रता परीक्षा ($shortNameWithPaper)' : 'केन्द्रीय शिक्षक पात्रता परीक्षा ($shortNameWithPaper)';

  String get fullNameEnglish =>
      isUtet ? 'Uttarakhand Teacher Eligibility Test ($shortNameWithPaper)' : 'Central Teacher Eligibility Test ($shortNameWithPaper)';

  String get boardTitleHindi =>
      isUtet ? 'उत्तराखण्ड विद्यालयी शिक्षा परिषद्, रामनगर' : 'केन्द्रीय माध्यमिक शिक्षा बोर्ड (CBSE), दिल्ली';

  String get boardTitleEnglish =>
      isUtet ? 'Uttarakhand Board of School Education' : 'Central Board of Secondary Education (CBSE)';

  String get bookletSealTitle =>
      isUtet ? 'GOVERNMENT OF UTTARAKHAND · UTET ${DateTime.now().year}' : 'CENTRAL BOARD OF SECONDARY EDUCATION · CTET ${DateTime.now().year}';

  String get hitRateNoticeHindi => isUtet
      ? '★ विगत वर्ष बोर्ड परीक्षा पैटर्न पर 100% आधारित'
      : '★ NCERT & CBSE बोर्ड पैटर्न पर 100% आधारित';

  String get hitRateNoticeEnglish => isUtet
      ? '★ 100% Based on Exam Pattern & Standard Blueprint'
      : '★ 100% Based on NCERT & CBSE Board Pattern';

  String get lang1LabelHindi => currentLang1.value == 'english' ? 'अंग्रेजी (English)' : 'हिन्दी (Hindi)';
  String get lang1LabelEnglish => currentLang1.value == 'english' ? 'English' : 'Hindi';

  String get lang2LabelHindi {
    switch (currentLang2.value) {
      case 'hindi':
        return 'हिन्दी (Hindi)';
      case 'sanskrit':
        return 'संस्कृत (Sanskrit)';
      default:
        return 'अंग्रेजी (English)';
    }
  }

  String get lang2LabelEnglish {
    switch (currentLang2.value) {
      case 'hindi':
        return 'Hindi';
      case 'sanskrit':
        return 'Sanskrit';
      default:
        return 'English';
    }
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final examStr = prefs.getString(_prefExamKey) ?? 'utet';
      currentExam.value = examStr == 'ctet' ? AppExam.ctet : AppExam.utet;

      final paperStr = prefs.getString(_prefPaperKey) ?? 'paper1';
      currentPaper.value = paperStr == 'paper2' ? AppPaper.paper2 : AppPaper.paper1;

      final streamStr = prefs.getString(_prefStreamKey) ?? 'mathScience';
      currentStream.value = streamStr == 'socialStudies' ? AppStream.socialStudies : AppStream.mathScience;

      final testModeStr = prefs.getString(_prefTestModeKey) ?? 'booklet';
      currentTestMode.value = testModeStr == 'cbt' ? AppTestMode.cbt : AppTestMode.booklet;

      final engineStr = prefs.getString(_prefBookletEngineKey) ?? 'native';
      bookletEngine.value = engineStr == 'html' ? BookletEngine.html : BookletEngine.native;

      final l1Str = prefs.getString(_prefLang1Key) ?? 'hindi';
      final l2Str = prefs.getString(_prefLang2Key) ?? 'english';
      currentLang1.value = l1Str;
      currentLang2.value = (l2Str == l1Str) ? (l1Str == 'hindi' ? 'english' : 'hindi') : l2Str;
    } catch (_) {
      currentExam.value = AppExam.utet;
      currentPaper.value = AppPaper.paper1;
      currentStream.value = AppStream.mathScience;
      currentTestMode.value = AppTestMode.booklet;
      bookletEngine.value = BookletEngine.native;
      currentLang1.value = 'hindi';
      currentLang2.value = 'english';
    }
  }

  Future<void> setStream(AppStream stream) async {
    currentStream.value = stream;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefStreamKey, stream == AppStream.socialStudies ? 'socialStudies' : 'mathScience');
    } catch (_) {}
  }

  Future<void> setExam(AppExam exam) async {
    currentExam.value = exam;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefExamKey, exam == AppExam.ctet ? 'ctet' : 'utet');
    } catch (_) {}
  }

  Future<void> setPaper(AppPaper paper) async {
    currentPaper.value = paper;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPaperKey, paper == AppPaper.paper2 ? 'paper2' : 'paper1');
    } catch (_) {}
  }

  Future<void> setTestMode(AppTestMode mode) async {
    currentTestMode.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTestModeKey, mode == AppTestMode.booklet ? 'booklet' : 'cbt');
    } catch (_) {}
  }

  Future<void> setBookletEngine(BookletEngine engine) async {
    bookletEngine.value = engine;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefBookletEngineKey, engine == BookletEngine.html ? 'html' : 'native');
    } catch (_) {}
  }

  Future<void> toggleBookletEngine() async {
    final next = isNativeBookletEngine ? BookletEngine.html : BookletEngine.native;
    await setBookletEngine(next);
  }

  Future<void> setLang1(String lang) async {
    currentLang1.value = lang;
    if (currentLang2.value == lang) {
      currentLang2.value = (lang == 'hindi') ? 'english' : 'hindi';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLang1Key, currentLang1.value);
      await prefs.setString(_prefLang2Key, currentLang2.value);
    } catch (_) {}
  }

  Future<void> setLang2(String lang) async {
    currentLang2.value = lang;
    if (currentLang1.value == lang) {
      currentLang1.value = (lang == 'english') ? 'hindi' : 'english';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLang1Key, currentLang1.value);
      await prefs.setString(_prefLang2Key, currentLang2.value);
    } catch (_) {}
  }

  Future<void> toggleExam() async {
    final next = isUtet ? AppExam.ctet : AppExam.utet;
    await setExam(next);
  }

  Future<void> togglePaper() async {
    final next = isPaper1 ? AppPaper.paper2 : AppPaper.paper1;
    await setPaper(next);
  }

  Future<void> toggleTestMode() async {
    final next = isCbtMode ? AppTestMode.booklet : AppTestMode.cbt;
    await setTestMode(next);
  }

  /// Builds the appropriate exam screen (CBT or Booklet) based on user preference
  Widget buildExamScreen({
    required TestSession session,
    int initialQuestionIndex = 0,
  }) {
    if (currentTestMode.value == AppTestMode.booklet) {
      return HtmlBookletScreen(session: session);
    }
    return CbtExamScreen(
      session: session,
      initialQuestionIndex: initialQuestionIndex,
    );
  }
}
