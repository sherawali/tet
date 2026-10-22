import '../services/language_service.dart';
import '../services/exam_service.dart';
import '../services/section_catalog.dart';
import '../services/exam_rules.dart';
import '../services/bank_facts.dart';

class AppStrings {
  static bool get _isHi => LanguageService.instance.isHindi;
  static bool get isHindi => _isHi;
  static bool get _isCtet => ExamService.instance.isCtet;
  static int get currentExamYear => DateTime.now().year;

  // ── Exam, paper and subject-stream context ───────────────────────────
  // One wording for the exam, one for the paper and one for the paper-2
  // stream.  Every screen title is built from these three, so a candidate
  // can never mix a UTET paper-1 question with a CTET paper-2 one.
  static String get examName => _isCtet ? 'CTET' : 'UTET';

  /// The paper the candidate is working on (1 or 2).
  static int get currentPaperNumber => ExamService.instance.selectedPaper;

  /// The one wording for a paper: "पेपर-1" / "Paper-1".
  static String paperName(int paper) => _isHi ? 'पेपर-$paper' : 'Paper-$paper';

  /// The active paper-2 stream. Empty on paper 1.
  static String get activeStreamName => ExamService.instance.isPaper2
      ? (ExamService.instance.isSocialStream
          ? streamSocialStudies
          : streamMathScience)
      : '';

  /// "CTET पेपर-2 · गणित एवं विज्ञान" - exam, paper and (paper 2) stream.
  static String get examPaperStreamLabel {
    final base = '$examName ${paperName(currentPaperNumber)}';
    final stream = activeStreamName;
    return stream.isEmpty ? base : '$base · $stream';
  }

  /// Builds a screen title that always names the exam, the paper and the
  /// paper-2 stream, so no two papers ever look the same on screen.
  static String screenTitle(String hi, String en) =>
      _isHi ? '$examPaperStreamLabel · $hi' : '$examPaperStreamLabel · $en';

  /// The exam pattern gives every language section the same number of
  /// questions, so the count lives in one place only.
  static const int languageSectionQuestions = 30;

  // Debug only (never shipped in a release build)
  static String get debugProPassTitle => _isHi ? 'Pro Pass (Debug)' : 'Pro Pass (Debug)';
  static String get debugProPassDesc => _isHi
      ? 'बिना पैमेंट के paid और free दोनों रूप देखें। Debug build में ही दिखता है।'
      : 'See the paid and the free experience without paying. Shown in debug builds only.';
  static String get debugProPassPaid => _isHi
      ? 'सभी पेपर खुले हैं (paid view)'
      : 'All papers are open (paid view)';
  static String get debugProPassSwitchSub => _isHi
      ? 'स्विच ON = paid view, OFF = free view'
      : 'Switch ON = paid view, OFF = free view';
  static String get debugProPassFree => _isHi
      ? 'सिर्फ मुफ़्त पेपर (free view)'
      : 'Only the free paper (free view)';

  // App Header
  static String get appTitle => '$examName ${paperName(currentPaperNumber)}';
  static String get appSubtitle => isPaper2
      ? (_isHi
          ? '$currentExamYear डिजिटल प्रश्न-पुस्तिका · $activeStreamName'
          : '$currentExamYear Digital Booklet · $activeStreamName')
      : (_isHi
          ? '$currentExamYear डिजिटल प्रश्न-पुस्तिका पोर्टल'
          : '$currentExamYear Digital Booklet Portal');
  static String get bankSyncTooltip => _isHi ? 'बैंक अपडेट करें' : 'Update Bank Online';
  static String get langToggleLabel => _isHi ? 'ENG' : 'हिन्दी';

  // Bank Strip
  static String get offlineBankTitle => _isHi ? 'ऑफलाइन बैंक' : 'Offline Bank';
  static String get offlineBadge => _isHi ? '100% ऑफलाइन' : '100% Offline';
  static String bankInfo(int total, int pyq, int subjects) => _isHi
      ? '$total कुल प्रश्न · $pyq विगत वर्ष प्रश्न · $subjects विषय'
      : '$total Total Questions · $pyq Previous Year Questions · $subjects Subjects';

  // Splash Screen
  static String get splashTitle =>
      _isHi ? 'UTET एवं CTET शिक्षक पात्रता परीक्षा' : 'UTET & CTET Teacher Eligibility Test';
  static String get splashSubtitle => _isHi
      ? 'UTET एवं CTET $currentExamYear डिजिटल प्रश्न-पुस्तिका एवं परीक्षा विश्लेषण पोर्टल'
      : 'UTET & CTET $currentExamYear Digital Question Booklet & Exam Analysis Portal';
  /// The paper the app will open with, shown on the splash screen.
  static String get splashTargetLabel => _isHi
      ? 'वर्तमान लक्ष्य : $examPaperStreamLabel'
      : 'Current target : $examPaperStreamLabel';
  static String get splashCheckingBank => _isHi ? 'ऑफलाइन बैंक की जाँच हो रही है...' : 'Verifying offline bank...';
  static String splashAvailable(int count) => _isHi
      ? '$count प्रश्न ऑफलाइन उपलब्ध हैं!'
      : '$count questions available offline!';
  static String get splashDownloading => _isHi
      ? 'पहली बार के लिए प्रश्न डाउनलोड हो रहे हैं...'
      : 'Downloading questions for the first time...';
  static String get splashNoInternet => _isHi
      ? 'इंटरनेट कनेक्शन नहीं मिला। कृपया इंटरनेट चालू करके पुनः प्रयास करें।'
      : 'No internet connection. Please check your network and retry.';
  static String get splashRetryBtn => _isHi ? 'पुनः प्रयास करें' : 'Retry Sync';

  // Hero Card
  static String get hitRibbon => _isCtet
      ? (_isHi ? 'NCERT एवं CBSE पाठ्यक्रम पर पूर्णतः आधारित' : '100% Based on NCERT & CBSE Curriculum')
      : (_isHi ? 'विगत वर्षों के परीक्षा पैटर्न पर पूर्णतः आधारित' : '100% Based on Previous Exam Pattern');
  static String get heroTitle => _isHi
      ? '$examPaperStreamLabel · $currentExamYear मुख्य मॉडल प्रश्न-पत्र'
      : '$examPaperStreamLabel · $currentExamYear Flagship Model Test Paper';
  static String get heroDesc => _isCtet
      ? (_isHi
          ? 'केन्द्रीय परीक्षा पाठ्यक्रम पर आधारित सम्पूर्ण ${BankFacts.questionsPerPaper} प्रश्नों का प्रामाणिक मॉडल प्रश्न-पत्र।'
          : 'Complete ${BankFacts.questionsPerPaper}-question authentic model test paper based on the standard pattern.')
      : (_isHi
          ? 'उत्तराखण्ड परीक्षा पैटर्न पर आधारित सम्पूर्ण ${BankFacts.questionsPerPaper} प्रश्नों का प्रामाणिक मॉडल प्रश्न-पत्र।'
          : 'Complete ${BankFacts.questionsPerPaper}-question authentic model test paper based on the Uttarakhand pattern.');
  static String get heroTotalQuestions => _isHi
      ? '${BankFacts.questionsPerPaper} बहुविकल्पीय प्रश्न'
      : '${BankFacts.questionsPerPaper} MCQs';
  static String get heroTime {
    final total = BankFacts.questionsPerPaper;
    final h = total ~/ 60;
    final m = total % 60;
    if (_isHi) {
      return m == 0 ? 'समय : $h घंटे' : 'समय : $h घंटे $m मिनट';
    }
    return m == 0 ? 'Time : $h Hrs' : 'Time : $h Hrs $m Min';
  }
  static String get heroMarks => _isHi
      ? 'पूर्णांक : ${BankFacts.questionsPerPaper} अंक'
      : 'Marks : ${BankFacts.questionsPerPaper}';
  static String get heroBtn => _isHi
      ? '📖 मॉडल प्रश्न-पत्र हल करें'
      : '📖 Open & Solve Model Test Paper';

  // Booklet Sets
  static String get completeBookletsHeading => _isHi
      ? '$examPaperStreamLabel · सम्पूर्ण प्रश्न-पुस्तिकाएं (${BankFacts.questionsPerPaper} प्रश्न · ${BankFacts.questionsPerPaper} मिनट)'
      : '$examPaperStreamLabel · Complete Exam Booklets (${BankFacts.questionsPerPaper} Qs · ${BankFacts.questionsPerPaper} Mins)';

  static String get setQTitle => _isHi ? 'सेट-Q : सर्वाधिक पूछे गए प्रश्न' : 'SET-Q : Frequently Repeated Questions';
  static String get setQSub => _isHi ? '2+ वर्ष चक्रीय व उच्च अंकदायी प्रश्न' : '2+ Years Recurring & High-Yield Questions';
  static String get setQTag => _isHi ? '🔥 उच्च दोहराव' : '🔥 High Recurrence';

  static String get setRTitle => _isHi ? 'सेट-R : केवल पूर्व वर्ष प्रश्न' : 'SET-R : Past Year Questions';
  static String setRSub(int pyqCount, String years) => _isHi
      ? '$pyqCount प्रामाणिक ${_isCtet ? "CTET" : "UTET"} प्रश्न बैंक ($years)'
      : '$pyqCount Authentic ${_isCtet ? "CTET" : "UTET"} Questions ($years)';
  static String get setRTag => _isHi ? '📜 पूर्व वर्ष प्रश्न' : '📜 Past Year Questions';

  static String get setSTitle => _isHi ? 'सेट-S : नवीन संभावित प्रश्न' : 'SET-S : Fresh Potential Questions';
  static String get setSSub => _isHi ? 'नए शिक्षणशास्त्र व सैद्धांतिक केस प्रश्न' : 'New pedagogy & conceptual case questions';
  static String get setSTag => _isHi ? '✨ फ्रेश अभ्यास' : '✨ Fresh Practice';

  static String get setTTitle => _isHi ? 'सेट-T : सम्पूर्ण मिश्रित परीक्षा' : 'SET-T : Complete Balanced Mock Test';
  static String get setTSub => _isHi ? 'मानक परीक्षा पैटर्न अनुरूप संतुलित ब्लूप्रिंट' : 'Standard exam pattern balanced blueprint';
  static String get setTTag => _isHi ? '⚖️ संतुलित' : '⚖️ Balanced';

  // Subject Booklets
  static String get subjectBookletsHeading => _isHi
      ? '$examPaperStreamLabel · खण्ड-वार अभ्यास पुस्तिकाएं (${BankFacts.subjectSetQuestions} प्रश्न · ${BankFacts.subjectSetQuestions} मिनट)'
      : '$examPaperStreamLabel · Subject-wise Practice Booklets (${BankFacts.subjectSetQuestions} Qs · ${BankFacts.subjectSetQuestions} Mins)';

  static String get pastHistoryHeading =>
      screenTitle('पिछले टेस्ट का रिकॉर्ड', 'Past Test History');
  static String get doubleBackExit => _isHi ? 'ऐप बंद करने के लिए दोबारा बैक दबाएं' : 'Press back again to exit app';

  // Navigation Bar
  static String get navBooklets => _isHi ? 'प्रश्न-पुस्तिका' : 'Booklets';
  static String get navSubjects => _isHi ? 'विषय अभ्यास' : 'Subjects';
  static String get navHistory => _isHi ? 'इतिहास' : 'History';
  static String get navSettings => _isHi ? 'सेटिंग्स' : 'Settings';

  // Subject Practice Portal
  static String get subjectPracticeHeading =>
      screenTitle('खण्ड-वार अभ्यास पुस्तिकाएं', 'Subject-wise Practice Booklets');
  static String get subjectPracticeDesc => _isHi
      ? 'प्रत्येक विषय में ${BankFacts.subjectSetQuestions} प्रामाणिक प्रश्न और ${BankFacts.subjectSetQuestions} मिनट का समय'
      : '${BankFacts.subjectSetQuestions} authentic questions & ${BankFacts.subjectSetQuestions} minutes for each subject';
  static String get subjectCardTime => _isHi
      ? '${BankFacts.subjectSetQuestions} प्रश्न · ${BankFacts.subjectSetQuestions} मिनट'
      : '${BankFacts.subjectSetQuestions} Qs · ${BankFacts.subjectSetQuestions} Mins';
  static String get startSubjectTestBtn => _isHi ? 'हल शुरू करें ▾' : 'Start Practice ▾';

  // Test History
  static String get historyTitle =>
      screenTitle('पिछले टेस्ट का रिकॉर्ड', 'Past Test History');
  static String historySummary(int count, int pass) => _isHi
      ? 'कुल टेस्ट: $count · उत्तीर्ण: $pass'
      : 'Total Tests: $count · Qualified: $pass';
  static String get historyEmptyTitle => _isHi ? 'कोई पिछला टेस्ट रिकॉर्ड नहीं मिला' : 'No Test History Found';
  static String get historyEmptyDesc => _isHi
      ? 'आपने अभी तक कोई टेस्ट नहीं दिया है। $examPaperStreamLabel $currentExamYear मॉडल प्रश्न-पत्र से अभ्यास की शुरुआत करें।'
      : 'You have not attempted any test yet. Begin with the $examPaperStreamLabel $currentExamYear model test paper.';
  static String get historyStartCta =>
      _isHi ? '📖 मॉडल प्रश्न-पत्र हल करें' : '📖 Solve Model Test Paper';
  static String historyMockType(String mode) => _isHi ? 'मॉक टेस्ट ($mode)' : 'Mock Test ($mode)';
  static String get historyQualified => _isHi ? 'उत्तीर्ण' : 'Qualified';
  static String get historyPracticeNeeded => _isHi ? 'अभ्यास आवश्यक' : 'Needs Practice';

  // Settings Screen
  static String get settingsTitle =>
      screenTitle('ऐप सेटिंग्स एवं भाषा', 'App Settings & Language');
  static String get settingsLangHeader => _isHi ? 'भाषा चयन / App Language' : 'App Language / भाषा चयन';
  static String get settingsLangDesc => _isHi
      ? 'पूरी ऐप की भाषा एक क्लिक में हिन्दी या अंग्रेजी में बदलें'
      : 'Switch the entire app interface between Hindi and English';
  static String get settingsBankHeader => _isHi ? 'ऑफलाइन डेटाबेस व प्रश्न बैंक' : 'Offline Database & Question Bank';
  static String get settingsBankDesc => _isHi
      ? 'क्लाउड सर्वर से सीधा जुड़ा हुआ। नए प्रश्न व सुधार तुरंत फोन में सुरक्षित होते हैं। 100% ऑफलाइन अभ्यास।'
      : 'Direct cloud sync. Latest questions and verified fixes are saved to your device for 100% offline practice.';
  static String get settingsBankSyncBtn => _isHi ? 'ताज़ा सिंक' : 'Sync Now';
  static String get dbCleanResyncBtn => _isHi ? '🔄 पूर्ण री-सिंक' : '🔄 Full Re-sync';
  static String get dbOptimizeBtn => _isHi ? '⚡ स्टोरेज ऑप्टिमाइज़' : '⚡ Optimize Storage';
  static String get dbCleanDialogTitle => _isHi ? 'डेटाबेस साफ़ व पूर्ण री-सिंक?' : 'Clean & Full Re-sync?';
  static String get dbCleanDialogDesc => _isHi
      ? 'क्या आप प्रश्न बैंक का कैश साफ़ कर नए प्रश्न पुनः डाउनलोड करना चाहते हैं?\n\n• सभी नए प्रश्न व सुधार डाउनलोड होंगे।\n• आपका पिछला टेस्ट इतिहास और गलतियों का रिकॉर्ड 100% सुरक्षित रहेगा।'
      : 'Do you want to clear question bank cache and re-download fresh questions?\n\n• All updated questions & corrections will be fetched.\n• Your past test history and mistake records will remain 100% safe.';
  static String get dbCleanConfirmBtn => _isHi ? 'हाँ, साफ़ व डाउनलोड करें' : 'Yes, Clean & Download';
  static String get dbCancelBtn => _isHi ? 'रद्द करें' : 'Cancel';
  static String get dbOptimizingToast => _isHi ? 'डेटाबेस को ऑप्टिमाइज़ किया जा रहा है...' : 'Optimizing database...';
  static String get dbOptimizeDoneTitle => _isHi ? '⚡ स्टोरेज 100% ऑप्टिमाइज़्ड!' : '⚡ Storage 100% Optimized!';
  static String dbOptimizeDoneDesc(String savedKb) => _isHi
      ? 'डेटाबेस इंडेक्स रीबिल्ड कर $savedKb KB स्टोरेज मुक्त किया गया। टेस्ट लोडिंग और सर्च अब सुपरफ़ास्ट होगी।'
      : 'All database indexes rebuilt and $savedKb KB unused storage space reclaimed. Test loading and search is now blazing fast.';
  static String get dbStorageSizeLabel => _isHi ? 'लोकल स्टोरेज' : 'Local Storage';
  static String get dbLastSyncedLabel => _isHi ? 'अंतिम सिंक' : 'Last Synced';
  static String get dbNeverSynced => _isHi ? 'अभी नहीं' : 'Not yet';
  static String get settingsSyncChecking => _isHi ? 'ऑनलाइन नए प्रश्नों की जाँच हो रही है...' : 'Checking for new questions online...';
  static String get settingsSyncSuccess => _isHi ? '✅ बैंक सफलतापूर्वक अपडेट हो गया!' : '✅ Question bank updated successfully!';
  static String settingsSyncError(String e) => _isHi ? 'सिंक में समस्या: $e' : 'Sync error: $e';
  static String get settingsModelHeader => _isHi ? 'विशेषज्ञ परीक्षा विश्लेषण ($currentExamYear)' : 'Exam Specialist Analysis ($currentExamYear)';
  static String get settingsModelDesc => _isHi
      ? 'विगत वर्षों के सभी प्रश्न-पत्रों और मुख्य कोर टॉपिक्स का गहन विश्लेषण एवं सटीक ब्लूप्रिंट।'
      : 'In-depth analytical assessment of all past year papers and high-yield core topics.';
  static String get settingsAbout => _isHi ? 'TET Mock Master v1.0 · 100% ऑफलाइन' : 'TET Mock Master v1.0 · 100% Offline';

  // Sync Feedback Bilingual Strings
  static String syncSuccessAddedTitle(int count) => _isHi
      ? '🎉 $count नए प्रश्न जोड़े गए!'
      : '🎉 $count New Questions Added!';
  static String syncSuccessAddedDesc(int totalCount) => _isHi
      ? 'आपका प्रश्न बैंक अब कुल $totalCount प्रामाणिक प्रश्नों के साथ नवीनतम है। CTET एवं UTET दोनों परीक्षाओं की सामग्री अब उपलब्ध है।'
      : 'Your question bank is now up-to-date with $totalCount authentic questions. Complete material for CTET & UTET is ready.';
  static String get syncUpToDateTitle => _isHi
      ? '✅ प्रश्न बैंक पूर्णतः अद्यतन है!'
      : '✅ Question Bank is Fully Up-to-Date!';
  static String syncUpToDateDesc(int totalCount) => _isHi
      ? 'आपके फोन में सभी $totalCount प्रश्न, विगत वर्ष के PYQ एवं गद्यांश पहले से ही सुरक्षित हैं। कोई नया संशोधन लंबित नहीं है।'
      : 'All $totalCount questions, past PYQs, and passages are safely stored on your device. Everything is up-to-date.';
  static String get syncErrorTitle => _isHi
      ? '⚠️ नेटवर्क सिंक में समस्या आई'
      : '⚠️ Sync Connection Issue';
  static String syncErrorDesc(String? msg) => _isHi
      ? (msg ?? 'कृपया इंटरनेट कनेक्शन जाँचें और पुनः प्रयास करें। ऑफलाइन प्रश्न बैंक पूरी तरह सुरक्षित है।')
      : (msg ?? 'Please check your internet connection and try again. Your offline question bank is completely safe.');
  static String syncTotalQuestionsChip(int total) => _isHi
      ? '📚 कुल प्रश्न: $total'
      : '📚 Total Questions: $total';
  static String get syncOfflineChip => _isHi
      ? '⚡ 100% ऑफ़लाइन अभ्यास'
      : '⚡ 100% Offline Access';
  static String get syncContinueBtn => _isHi
      ? 'अभ्यास जारी रखें'
      : 'Continue Practice';
  static String dbTotalQuestionsChip(int total) => _isHi
      ? '📚 कुल प्रश्न: $total'
      : '📚 Total Questions: $total';
  static String dbSpaceFreedChip(String savedKb) => _isHi
      ? '⚡ मुक्त स्पेस: $savedKb KB'
      : '⚡ Space Freed: $savedKb KB';
  static String dbOrphanDeletedChip(int count) => _isHi
      ? '🧹 साफ़ किए गए: $count'
      : '🧹 Cleaned: $count';

  // Home Loading and Errors
  static String get loadingGenerating => _isHi
      ? 'मानक ब्लूप्रिंट से प्रश्न-पुस्तिका तैयार हो रही है...'
      : 'Preparing question booklet according to standard blueprint...';
  static String loadError(String e) => _isHi ? 'टेस्ट लोड करने में समस्या: $e' : 'Failed to load test: $e';

  // Booklet Exam Screen
  static String get exitExamTitle => _isHi ? 'परीक्षा विराम / बाहर निकलें' : 'Pause Exam / Exit';
  static String exitExamRemaining(int total, int answered, int remaining) => _isHi
      ? 'कुल $total में से $answered हल किए, $remaining शेष'
      : 'Answered $answered of $total, $remaining remaining';
  static String get continueTestBtn => _isHi ? 'हल करना जारी रखें' : 'Continue Test';
  static String get submitViewResultBtn => _isHi ? 'सबमिट करें और परिणाम देखें' : 'Submit & View Result';
  static String get discardDirectExitBtn => _isHi ? 'बिना परिणाम के सीधे बाहर जाएं / रद्द करें' : 'Discard & Exit Without Result';

  static String get bookletAnswered => _isHi ? 'हल किए: ' : 'Answered: ';
  static String get bookletRemaining => _isHi ? '  |  शेष: ' : '  |  Remaining: ';
  static String get bookletTotal => _isHi ? '  |  कुल प्रश्न: ' : '  |  Total: ';
  static String get bookletProgress => _isHi ? '  |  प्रगति: ' : '  |  Progress: ';
  static String get submitBtn => _isHi ? 'जमा' : 'Submit';

  // Result Screen
  static String get resultsTitle =>
      screenTitle('परीक्षा परिणाम एवं विश्लेषण', 'Exam Results & Analysis');
  static String get passGeneral => _isHi
      ? '🎉 बधाई! आप उत्तीर्ण हैं (${(ExamRules.generalPassRatio * 100).round()}%+)'
      : '🎉 Congratulations! You Passed (${(ExamRules.generalPassRatio * 100).round()}%+)';
  static String get passReserved => _isHi
      ? '⭐ आरक्षित वर्ग में उत्तीर्ण (${(ExamRules.reservedPassRatio * 100).round()}%+)'
      : '⭐ Qualified in Reserved Category (${(ExamRules.reservedPassRatio * 100).round()}%+)';
  static String get needMorePractice => _isHi ? '🎯 और अभ्यास की आवश्यकता है' : '🎯 More Practice Needed';
  static String get rePracticeTitle => _isHi ? 'गलत प्रश्नों का पुनः अभ्यास' : 'Re-practice Incorrect Questions';
  static String rePracticeSub(int count) => _isHi
      ? '$count प्रश्नों में गलतियाँ हुईं। दोबारा हल करके 100% सटीक बनाएं।'
      : '$count questions were answered incorrectly. Re-attempt to achieve 100% accuracy.';
  static String rePracticeBtn(int count) => _isHi
      ? '🔁 गलत प्रश्न दोबारा हल करें ($count प्रश्न)'
      : '🔁 Re-solve Incorrect Questions ($count Qs)';
  static String get guidanceTitle => _isHi ? 'विशेषज्ञ मार्गदर्शन एवं सही सलाह' : 'Expert Guidance & Recommendations';
  static String get sectionBreakdownTitle => _isHi ? 'विषयवार प्रदर्शन' : 'Section-wise Performance Breakdown';
  static String get topicAnalysisTitle => _isHi ? 'टॉपिक-वार विश्लेषण' : 'Topic-wise Analysis';
  static String get viewSolutionsBtn => _isHi ? '📖 विस्तृत उत्तर कुंजी एवं हल' : '📖 Detailed Answer Key & Solutions';
  static String get backHomeBtn => _isHi ? 'मुख्य पृष्ठ पर वापस जाएं' : 'Return to Home Screen';

  // Solution Screen
  static String get solutionsTitle => screenTitle(
      'विस्तृत उत्तर कुंजी एवं हल',
      'Answer Key & Detailed Solutions');
  static String get solFilterAll => _isHi ? 'सभी' : 'All';
  static String get solFilterIncorrect => _isHi ? 'गलत' : 'Incorrect';
  static String get solFilterUnattempted => _isHi ? 'छोड़े गए' : 'Unattempted';
  static String get solFilterCorrect => _isHi ? 'सही' : 'Correct';
  static String get solNoQuestionsInCategory => _isHi ? 'इस श्रेणी में कोई प्रश्न नहीं है' : 'No questions in this category';
  static String solQuestionNum(int num) => _isHi ? 'प्रश्न $num' : 'Question $num';
  static String get solBadgeUnattempted => _isHi ? 'छोड़ा गया' : 'Unattempted';
  static String get solBadgeCorrect => _isHi ? '✅ सही (+1)' : '✅ Correct (+1)';
  static String get solBadgeIncorrect => _isHi ? '❌ गलत (0)' : '❌ Incorrect (0)';
  static String solProbScore(double score) => _isHi
      ? 'संभावना अंक: ${(score * 100).toStringAsFixed(0)}%'
      : 'Probability: ${(score * 100).toStringAsFixed(0)}%';

  // Result Extra Tokens
  static String resultMarksPct(double pct) => _isHi ? '${pct.toStringAsFixed(1)}% अंक' : '${pct.toStringAsFixed(1)}% Marks';
  static String resultAccuracy(double acc) => _isHi ? 'सटीकता: ${acc.toStringAsFixed(0)}%' : 'Accuracy: ${acc.toStringAsFixed(0)}%';
  static String resultTime(int mins) => _isHi ? '$mins मिनट समय' : '$mins Mins Time';
  static String get correctShort => _isHi ? 'सही' : 'Correct';
  static String get wrongShort => _isHi ? 'गलत' : 'Wrong';
  static String get unattemptedShort => _isHi ? 'शेष' : 'Skipped';
  static String get accuracyShort => _isHi ? 'सटीकता' : 'Accuracy';
  static String get topWeakTopicsWarning => _isHi ? '⚠️ इन मुख्य टॉपिक्स पर तुरंत ध्यान दें:' : '⚠️ Focus on these key weak topics:';
  static String get generalQuestionFallback => _isHi ? 'सामान्य प्रश्न' : 'General Question';

  static bool get isPaper2 => ExamService.instance.isPaper2;
  static String get paperBadge => ExamService.instance.paperBadge;

  // Section Names (Pure Hindi vs Pure English)
  static String sectionName(String sec) =>
      SectionCatalog.name(sec, hindi: _isHi);

  // Paper Selector Strings
  /// The paper switcher always says the same thing, in every screen.
  static String get paper1Label =>
      _isHi ? '${paperName(1)} (कक्षा 1–5)' : '${paperName(1)} (Classes 1–5)';
  static String get paper2Label =>
      _isHi ? '${paperName(2)} (कक्षा 6–8)' : '${paperName(2)} (Classes 6–8)';
  static String get paper1Tab => '📘 $paper1Label';
  static String get paper2Tab => '📙 $paper2Label';
  static String get paperSelectorHeader => _isHi ? 'पेपर चयन' : 'Select Paper';
  static String get paperSelectorDesc => _isHi
      ? '${paperName(1)} (कक्षा 1–5) या ${paperName(2)} (कक्षा 6–8) चुनें'
      : 'Choose ${paperName(1)} (Classes 1–5) or ${paperName(2)} (Classes 6–8)';

  // Gateway Cards on Home Booklets
  static String get gatewayPyqTitle => _isHi
      ? '$examPaperStreamLabel · विगत वर्ष प्रश्न-पत्र संग्रह'
      : '$examPaperStreamLabel · Previous Year Solved Papers';
  static String get gatewayPyqSub => _isHi
      ? 'विगत वर्षों के सभी प्रामाणिक प्रश्न-पत्र'
      : 'All previous year board papers';
  static String get gatewayMocksTitle => _isHi
      ? '$examPaperStreamLabel · $currentExamYear मॉडल प्रश्न-पत्र'
      : '$examPaperStreamLabel · $currentExamYear Model Test Papers';
  static String get gatewayMocksSub => _isHi
      ? '${BankFacts.paperCount} सम्पूर्ण प्रामाणिक मॉडल प्रश्न-पत्र'
      : '${BankFacts.paperCount} complete authentic model test papers';

  // PYQ Section
  static String get pyqVaultTitle =>
      screenTitle('विगत वर्ष प्रश्न-पत्र', 'Previous Year Solved Papers');
  static String get pyqVaultSubtitle => _isCtet
      ? (_isHi
          ? 'केन्द्रीय शिक्षक पात्रता परीक्षा ($examName) के विगत वर्ष प्रश्न-पत्र'
          : 'Previous year question papers of $examName')
      : (_isHi
          ? 'उत्तराखण्ड शिक्षक पात्रता परीक्षा ($examName) के विगत वर्ष प्रश्न-पत्र'
          : 'Previous year question papers of $examName');
  static String get pyqVaultBadge =>
      _isHi ? 'विगत वर्ष प्रश्न-पत्र' : 'Previous Year Solved Paper';
  static String pyqVaultCardTitle(String year) => _isHi
      ? '$examPaperStreamLabel · $year विगत वर्ष प्रश्न-पत्र'
      : '$examPaperStreamLabel · $year Previous Year Solved Paper';
  static String pyqVaultCardDesc(int count) => _isHi
      ? '$count प्रामाणिक पूर्व वर्ष प्रश्न · ${BankFacts.subjectCount} विषय'
      : '$count Authentic Questions · ${BankFacts.subjectCount} Subjects';
  static String get startPyqExamBtn => _isHi ? '📖 प्रश्न-पत्र हल करें' : '📖 Solve Paper';

  // Mock Series Screen
  static String get mockSeriesTitle => _isHi
      ? '$examPaperStreamLabel · $currentExamYear मॉडल प्रश्न-पत्र'
      : '$examPaperStreamLabel · $currentExamYear Model Test Papers';
  static String get mockSeriesSubtitle {
    final total = BankFacts.format(
      BankFacts.paperCount * BankFacts.questionsPerPaper,
    );
    return _isHi
        ? 'मानक परीक्षा पैटर्न पर आधारित $total प्रश्नों की ${BankFacts.paperCount} प्रामाणिक मॉडल प्रश्न-पत्र शृंखला'
        : '$total-question series of ${BankFacts.paperCount} authentic model test papers curated on the standard exam pattern';
  }
  static String mockSeriesCardTitle(int num) => _isHi
      ? 'सेट-${num.toString().padLeft(2, '0')} · $examPaperStreamLabel · $currentExamYear मॉडल प्रश्न-पत्र'
      : 'SET-${num.toString().padLeft(2, '0')} · $examPaperStreamLabel · $currentExamYear Model Test Paper';
  static String get mockSeriesCardDesc => _isHi
      ? '${BankFacts.questionsPerPaper} बहुविकल्पीय प्रश्न · ${BankFacts.questionsPerPaper} मिनट · पूर्णांक ${BankFacts.questionsPerPaper}'
      : '${BankFacts.questionsPerPaper} MCQs · ${BankFacts.questionsPerPaper} Minutes · ${BankFacts.questionsPerPaper} Marks';
  static String get freshMockGenerateBtn => _isHi
      ? '⚡ नया असीमित मॉडल प्रश्न-पत्र तैयार करें'
      : '⚡ Generate Fresh Practice Mock';

  /// Formats paper titles with 100% pure language separation
  static String formatPaperTitle(Map<String, dynamic> form, {bool? isHindi}) {
    final isHi = isHindi ?? _isHi;
    final fid = (form['id'] as String? ?? '').toLowerCase();
    final exam = (form['exam'] as String? ?? (fid.contains('ctet') ? 'ctet' : 'utet')).toUpperCase();
    final paper = form['paper'] is int ? form['paper'] as int : (fid.contains('p2') ? 2 : 1);
    final setCode = (form['set_code']?.toString() ?? '').toUpperCase();
    final rawTitle = form['title']?.toString() ?? '';

    final paperStr = isHi ? 'पेपर-$paper' : 'Paper-$paper';
    // The paper-2 stream belongs to the paper name, so a stream paper is
    // never mistaken for the other one.
    final streamTag = isHi
        ? (fid.contains('sst-mock')
            ? '(सामाजिक अध्ययन)'
            : '(गणित एवं विज्ञान)')
        : (fid.contains('sst-mock')
            ? '(Social Studies)'
            : '(Mathematics & Science)');

    // 1. UTET Paper 1 Fullmock Board Paper
    if (fid == 'utet-p1-fullmock') {
      return isHi
          ? '$exam $paperStr · 2023 आधिकारिक बोर्ड प्रश्न-पत्र'
          : '$exam $paperStr · 2023 Official Board Solved Paper';
    }

    // 2. UTET Paper 1 Mocks
    if (fid.startsWith('utet-p1-set')) {
      final numM = RegExp(r'(\d+)').firstMatch(setCode) ??
          RegExp(r'set(\d+)').firstMatch(fid) ??
          RegExp(r'set-([a-z])').firstMatch(fid);
      final String num;
      if (numM != null) {
        final val = numM.group(1)!;
        num = int.tryParse(val) != null
            ? val.padLeft(2, '0')
            : (val.codeUnitAt(0) - 'a'.codeUnitAt(0)).toString().padLeft(2, '0');
      } else {
        num = '01';
      }
      return isHi
          ? '$exam $paperStr · $currentExamYear मॉडल प्रश्न-पत्र $num'
          : '$exam $paperStr · $currentExamYear Model Test Paper $num';
    }

    // 3. UTET Paper 2 Board Papers
    if (fid.startsWith('utet-p2-set')) {
      final yearM = RegExp(r'20\d\d').firstMatch(setCode) ?? RegExp(r'20\d\d').firstMatch(rawTitle);
      final year = yearM?.group(0) ?? '2023';
      final setM = RegExp(r'set-([a-g])', caseSensitive: false).firstMatch(fid) ??
          RegExp(r'set-?([a-g])', caseSensitive: false).firstMatch(setCode) ??
          RegExp(r'set-?([a-g])', caseSensitive: false).firstMatch(rawTitle);
      final setLetter = setM?.group(1)?.toUpperCase() ?? 'A';
      return isHi
          ? '$exam $paperStr · $year (सेट-$setLetter) बोर्ड प्रश्न-पत्र'
          : '$exam $paperStr · $year (Set-$setLetter) Board Solved Paper';
    }

    // 4. CTET Paper 1 PYQs
    if (fid.startsWith('ctet-p1-') && fid.endsWith('-pyq')) {
      final yearM = RegExp(r'20\d\d').firstMatch(fid);
      final year = yearM?.group(0) ?? '$currentExamYear';
      return isHi
          ? '$exam $paperStr · $year विगत वर्ष प्रश्न-पत्र'
          : '$exam $paperStr · $year Previous Year Solved Paper';
    }

    // 5. CTET Paper 1 Mocks
    if (fid.startsWith('ctet-p1-mock-')) {
      final numM = RegExp(r'mock-(\d+)').firstMatch(fid) ?? RegExp(r'(\d+)').firstMatch(setCode);
      final num = numM != null ? numM.group(1)!.padLeft(2, '0') : '01';
      return isHi
          ? '$exam $paperStr · $currentExamYear मॉडल प्रश्न-पत्र $num'
          : '$exam $paperStr · $currentExamYear Model Test Paper $num';
    }

    // 6. CTET Paper 2 Math & Science Mocks
    if (fid.contains('ms-mock')) {
      final numM = RegExp(r'mock-(\d+)').firstMatch(fid) ?? RegExp(r'(\d+)').firstMatch(setCode);
      final num = numM != null ? numM.group(1)!.padLeft(2, '0') : '01';
      return isHi
          ? '$exam $paperStr · $streamTag · $currentExamYear मॉडल प्रश्न-पत्र $num'
          : '$exam $paperStr · $streamTag · $currentExamYear Model Test Paper $num';
    }

    // 7. CTET Paper 2 Social Studies Mocks
    if (fid.contains('sst-mock')) {
      final numM = RegExp(r'mock-(\d+)').firstMatch(fid) ?? RegExp(r'(\d+)').firstMatch(setCode);
      final num = numM != null ? numM.group(1)!.padLeft(2, '0') : '01';
      return isHi
          ? '$exam $paperStr · $streamTag · $currentExamYear मॉडल प्रश्न-पत्र $num'
          : '$exam $paperStr · $streamTag · $currentExamYear Model Test Paper $num';
    }

    // Fallback Translation for any custom or dynamic forms
    if (rawTitle.isEmpty) {
      return isHi
          ? '$exam $paperStr · अभ्यास प्रश्न-पत्र'
          : '$exam $paperStr · Practice Paper';
    }

    if (isHi) {
      return rawTitle
          .replaceAll(RegExp(r'Paper[- ]*I\b', caseSensitive: false), 'पेपर-1')
          .replaceAll(RegExp(r'Paper[- ]*II\b', caseSensitive: false), 'पेपर-2')
          .replaceAll(RegExp(r'Paper[- ]*1\b', caseSensitive: false), 'पेपर-1')
          .replaceAll(RegExp(r'Paper[- ]*2\b', caseSensitive: false), 'पेपर-2')
          .replaceAll(RegExp(r'Model Paper\b', caseSensitive: false), 'मॉडल प्रश्न-पत्र')
          .replaceAll(RegExp(r'Model Booklet\b', caseSensitive: false), 'मॉडल प्रश्न-पत्र')
          .replaceAll('मॉडल पेपर', 'मॉडल प्रश्न-पत्र')
          .replaceAll('मॉडल प्रश्न-पुस्तिका', 'मॉडल प्रश्न-पत्र')
          .replaceAll('बोर्ड पेपर', 'बोर्ड प्रश्न-पत्र')
          .replaceAll('विगत वर्ष पेपर', 'विगत वर्ष प्रश्न-पत्र')
          .replaceAll('Set-', 'सेट-')
          .replaceAll('Set ', 'सेट ');
    } else {
      return rawTitle
          .replaceAll('आधिकारिक बोर्ड प्रश्न-पत्र', 'Official Board Solved Paper')
          .replaceAll('आधिकारिक बोर्ड पेपर', 'Official Board Solved Paper')
          .replaceAll('बोर्ड प्रश्न-पत्र', 'Board Solved Paper')
          .replaceAll('बोर्ड पेपर', 'Board Solved Paper')
          .replaceAll('विगत वर्ष प्रश्न-पत्र', 'Previous Year Solved Paper')
          .replaceAll('विगत वर्ष पेपर', 'Previous Year Solved Paper')
          .replaceAll('मॉडल प्रश्न-पत्र', 'Model Test Paper')
          .replaceAll('मॉडल प्रश्न-पुस्तिका', 'Model Test Paper')
          .replaceAll('मॉडल पेपर', 'Model Test Paper')
          .replaceAll('मॉडल पेपर', 'Model Test Paper')
          .replaceAll('गणित एवं विज्ञान', 'Mathematics & Science')
          .replaceAll('सामाजिक अध्ययन', 'Social Studies')
          .replaceAll('पेपर-1', 'Paper-1')
          .replaceAll('पेपर-2', 'Paper-2')
          .replaceAll('सेट-', 'Set-')
          .replaceAll('सेट ', 'Set ');
    }
  }

  /// Clean two-line stamp breakdown: top label and bottom number/letter
  static ({String top, String bottom}) getStampParts(String rawSet, {bool? isHindi}) {
    final isHi = isHindi ?? _isHi;
    final s = rawSet.trim().toUpperCase();

    // Year PYQ (e.g. '2023', '2021-C')
    if (RegExp(r'20\d\d').hasMatch(s)) {
      return (top: isHi ? 'वर्ष' : 'YEAR', bottom: s);
    }

    // Mock Test (e.g. 'MOCK 01', 'M-01')
    if (s.startsWith('MOCK') || s.startsWith('M-')) {
      final num = s.replaceAll(RegExp(r'[^0-9]'), '');
      return (top: isHi ? 'मॉडल' : 'MOCK', bottom: num.isNotEmpty ? num : '01');
    }

    // Math & Science Stream (e.g. 'MS-01')
    if (s.startsWith('MS-') || s.startsWith('MS ')) {
      final num = s.replaceAll(RegExp(r'[^0-9]'), '');
      return (top: isHi ? 'गणित-वि.' : 'M&S', bottom: num.isNotEmpty ? num : '01');
    }

    // Social Studies Stream (e.g. 'SST-01')
    if (s.startsWith('SST-') || s.startsWith('SST ')) {
      final num = s.replaceAll(RegExp(r'[^0-9]'), '');
      return (top: isHi ? 'सामाजिक' : 'SST', bottom: num.isNotEmpty ? num : '01');
    }

    // Set A, B, C...
    if (s.startsWith('SET-') || s.startsWith('SET ')) {
      final rest = s.replaceAll(RegExp(r'^SET[- ]*'), '');
      return (top: isHi ? 'सेट' : 'SET', bottom: rest);
    }

    // Generic
    return (top: isHi ? 'पेपर' : 'PAPER', bottom: s);
  }

  /// Formats stamp badge text into single line (e.g. 'MOCK 01' -> 'मॉडल 01')
  static String formatSetBadge(String rawSet, {bool? isHindi}) {
    final parts = getStampParts(rawSet, isHindi: isHindi);
    return '${parts.top} ${parts.bottom}';
  }

  // Paper-2 streams (Mathematics & Science / Social Studies)
  static String get streamSwitcherLabel =>
      _isHi ? 'विषय वर्ग (खंड IV)' : 'Subject Stream (Section IV)';
  static String get streamMathScience =>
      _isHi ? 'गणित एवं विज्ञान' : 'Mathematics & Science';
  static String get streamSocialStudies =>
      _isHi ? 'सामाजिक अध्ययन' : 'Social Studies';
  static String get streamBoth =>
      _isHi ? 'दोनों विषय वर्ग' : 'Both Streams';
  static String streamQuestions(int count) =>
      _isHi ? '$count प्रश्न' : '$count Qs';
  static String get streamChanged =>
      _isHi ? 'विषय वर्ग बदल दिया गया' : 'Subject stream changed';

  // ── Screen titles ────────────────────────────────────────────────────
  // Every one of them names the exam, the paper and - for paper 2 - the
  // subject stream, so a candidate always knows what they are solving.

  /// Home · Booklets tab.
  static String get homeBookletsTitle =>
      screenTitle('प्रश्न-पुस्तिकाएं', 'Booklets');

  /// Home · Subjects tab.
  static String get homeSubjectsTitle =>
      screenTitle('विषय अभ्यास', 'Subject Practice');

  /// Home · History tab.
  static String get homeHistoryTitle => historyTitle;

  /// Home · Settings tab.
  static String get homeSettingsTitle => settingsTitle;

  /// The heading above the paper list on the home screen.
  static String paperListHeading(int count) => _isHi
      ? '$examPaperStreamLabel · $currentExamYear मॉडल प्रश्न-पत्र ($count सेट)'
      : '$examPaperStreamLabel · $currentExamYear Model Test Papers ($count Sets)';

  /// The CBT exam screen.
  static String get cbtExamTitle => screenTitle('CBT परीक्षा', 'CBT Exam');

  /// The CBT exam screen, empty paper state.
  static String get examEmptyStateTitle => screenTitle('परीक्षा', 'Exam');

  /// The reported questions screen.
  static String get reportedQuestionsTitle =>
      screenTitle('रिपोर्ट की गई प्रश्न', 'Reported Questions');

  static String get streamShortMathScience => _isHi ? 'गणित-विज्ञान' : 'M&S';
  static String get streamShortSocialStudies => _isHi ? 'सामाजिक' : 'SST';

  static String papersCountDesc(int count, int size) => _isHi
      ? '$count प्रश्न-पत्र · हर एक में $size प्रश्न'
      : '$count papers · $size questions each';

  static String get allPapersHeading =>
      _isHi ? '?? ???? ?? ??? ??????-????' : 'All Papers Of This Level';

  static String get examPaperLabel {
    final exam = _isCtet ? 'CTET' : 'UTET';
    return '$exam ${paperName(currentPaperNumber)}';
  }

  static String boardPaperSubtitle(int size) => _isHi
      ? '$size प्रश्न · $size मिनट · सत्यापित उत्तर सहित बोर्ड पेपर'
      : '$size questions · $size minutes · board paper with verified answers';

  // ---- bilingual wording for the buttons and cards ------------------------
  static String get verifiedTestPapersHeading =>
      _isHi ? 'प्रामाणिक बने-बनाए टेस्ट पेपर्स' : 'Verified Ready-Made Test Papers';
  static String verifiedTestPapersDesc(int count, int size) => _isHi
      ? '$count सम्पूर्ण $size-प्रश्नों वाले मॉडल पेपर्स उपलब्ध हैं।'
      : '$count complete mock papers with $size questions each.';
  static String get freshSetButton => _isHi
      ? '⚡ फ्रेश 30-प्रश्न सेट जनरेट करें'
      : '⚡ Generate a fresh 30-question set';
  static String get freshSetLocked => _isHi
      ? '🔒 फ्रेश 30-प्रश्न सेट (पास से अनलॉक करें)'
      : '🔒 Fresh 30-question set (unlock with the pass)';
  static String get buildingSet => _isHi ? 'सेट बन रहा है...' : 'Building the set...';
  static String get unlockLabel => _isHi ? 'अनलॉक' : 'Unlock';
  static String get solveLabel => _isHi ? 'हल करें' : 'Solve';
  static String get drillLabel => _isHi ? 'ड्रिल' : 'Drill';
  static String get changeStreamLabel =>
      _isHi ? 'स्ट्रीम बदलें ⇄' : 'Change stream ⇄';
  static String topicsCount(int count) =>
      _isHi ? '$count विषय' : '$count topics';
  static String get resultPassedHeadline =>
      _isHi ? 'बहुत बढ़िया! आपने पास कर लिया' : 'Well done, you passed!';
  static String get resultPassedAdvice => _isHi
      ? 'अपनी गति बनाए रखें। कमजोर विषयों को दोबारा पढ़ें ताकि स्कोर और मजबूत हो।'
      : 'Keep the pace. Revise the weak sections once more to make the score even stronger.';
  static String get resultReservedHeadline => _isHi
      ? 'आप रिज़र्व सीट के साथ पास हैं'
      : 'You passed on the reserved seat';
  static String resultReservedAdvice(int needed) => _isHi
      ? 'सामान्य वर्ग पार करने के लिए केवल $needed और अंक चाहिए। नीचे दिए कमजोर टॉपिक्स का पुनः अभ्यास करें।'
      : 'You need only $needed more marks for the general seat. Revise the weak topics below.';
  static String mockPaperSubtitle(int size) => _isHi
      ? '$size प्रश्न · $size मिनट · पूर्ण प्रामाणिक मॉक'
      : '$size questions · $size minutes · fully verified mock';

  // Subject Practice Hub
  static String subjectPracticeHubTitle(String sec) =>
      screenTitle('$sec अभ्यास हब', '$sec Practice Hub');
  static String subjectPracticeHubDesc(int total) => _isHi
      ? 'बैंक में कुल $total प्रामाणिक प्रश्न उपलब्ध हैं'
      : 'Total $total authentic questions available in bank';
  static String subjectSetTitle(int num) => _isHi
      ? 'सेट-$num : ${BankFacts.subjectSetQuestions} प्रश्न अभ्यास'
      : 'Set-$num : ${BankFacts.subjectSetQuestions} Questions Practice';
  static String get topicsDrillHeading => _isHi ? 'टॉपिक-वार गहन अभ्यास' : 'Topic-wise Focused Drills';
  static String get startPracticeBtn => _isHi ? 'हल शुरू करें ▾' : 'Start Practice ▾';
  static String topicDrillTitle(String topic) => _isHi ? '$topic ड्रिल' : '$topic Drill';
  static String topicDrillSub(int count) => _isHi ? '$count प्रश्न' : '$count Questions';
  static String get subjectCardSetsInfo =>
      _isHi ? 'अभ्यास सेट्स · टॉपिक ड्रिल' : 'Practice Sets · Topic Drills';

  /// The same line with the real number of sets the bank can offer.
  static String subjectCardSetsInfoFor(int sets) => _isHi
      ? '$sets अभ्यास सेट्स · टॉपिक ड्रिल'
      : '$sets Practice Sets · Topic Drills';

  // Premium & In-App Purchase Gate (IAP)
  static String get premiumPassTitle =>
      _isHi ? 'UTET एवं CTET $currentExamYear प्रो पास' : 'UTET & CTET $currentExamYear Pro Pass';
  static String get premiumPassSubtitle => _isHi
      ? 'एक मॉडल प्रश्न-पत्र पूर्णतः निःशुल्क है। बाकी सभी ${BankFacts.paperCount}+ मॉडल प्रश्न-पत्र, विगत वर्ष प्रश्न-पत्र और ${BankFacts.format(BankFacts.questionCount)}+ प्रश्न आजीवन अनलॉक करें।'
      : 'One model test paper is completely free. Unlock all ${BankFacts.paperCount}+ model test papers, previous year solved papers, and ${BankFacts.format(BankFacts.questionCount)}+ questions forever.';

  static String get proPackMasterTitle => _isHi ? 'मास्टर ऑल-एक्सेस प्रो पास' : 'Master All-Access Pro Pass';
  static String get proPackMasterSub => _isHi
      ? 'दोनों पेपर (पेपर-1 + पेपर-2), UTET और CTET, सभी ${BankFacts.paperCount}+ टेस्ट, ${BankFacts.format(BankFacts.questionCount)}+ प्रश्न व आजीवन अपडेट'
      : 'Both papers (Paper-1 + Paper-2), UTET & CTET, all ${BankFacts.paperCount}+ full tests, ${BankFacts.format(BankFacts.questionCount)}+ questions & lifetime updates';
  static String get proPackMasterPrice =>
      _isHi ? '₹599 (80% तक छूट)' : '₹599 (Up to 80% Off)';
  static String get proPackMasterTag => _isHi ? '⭐ सर्वोत्तम मूल्य · शिक्षकों की पसंद' : '⭐ Best Value · Most Popular';

  static String get proPackSingleTitle => _isHi ? 'एकल पेपर प्रो पास' : 'Single Paper Pro Pass';
  static String get proPackSingleSub => _isHi
      ? 'चयनित पेपर के सभी ${BankFacts.paperCount}+ टेस्ट, सम्पूर्ण समाधान एवं विस्तृत विश्लेषण'
      : 'All ${BankFacts.paperCount}+ full tests, complete solutions & analytics for selected paper';
  static String get proPackSinglePrice => _isHi ? '₹299' : '₹299';
  static String get proPackSingleTag => _isHi ? 'छात्र पैक' : 'Student Pack';

  static String get premiumFeature1 => _isHi
      ? '${BankFacts.paperCount}+ सम्पूर्ण ${BankFacts.questionsPerPaper}-प्रश्नों के मॉडल प्रश्न-पत्र'
      : '${BankFacts.paperCount}+ full ${BankFacts.questionsPerPaper}-question model test papers';
  static String get premiumFeature2 => _isHi
      ? 'विगत वर्षों के ${BankFacts.pyqCount}+ प्रामाणिक बोर्ड प्रश्न-पत्र'
      : '${BankFacts.pyqCount}+ authentic previous year board papers';
  static String get premiumFeature3 => _isHi ? 'विस्तृत व्याख्या सहित सम्पूर्ण हल व सटीक विश्लेषण' : 'Detailed Explanations & Performance Analytics';
  static String get premiumFeature4 => _isHi ? '100% विज्ञापन-मुक्त · बिना इंटरनेट आजीवन पूर्ण एक्सेस' : '100% Ad-Free · Complete Offline Access for Life';

  static String get premiumUnlockBtn => _isHi ? '👑 प्रो पास अनलॉक करें' : '👑 Unlock Pro Pass';
  static String get premiumRestoreBtn => _isHi ? 'खरीद पुनर्स्थापित करें' : 'Restore Purchases';
  static String get premiumCloseBtn => _isHi ? 'बंद करें' : 'Close';
  static String get premiumFreeBadge => _isHi ? 'निःशुल्क' : 'FREE';
  static String get premiumLockedBadge => _isHi ? '🔒 प्रो पास' : '🔒 Pro Pass';
  static String get premiumSuccessToast => _isHi
      ? '🎉 बधाई! ऑल-एक्सेस प्रो पास सफलतापूर्वक अनलॉक हो गया।'
      : '🎉 Congratulations! All-Access Pro Pass unlocked successfully.';
  static String get premiumActiveStatus => _isHi ? '👑 प्रो पास सक्रिय' : '👑 Pro Pass Active';
  static String get premiumPriceBadge => _isHi ? '👑 प्रो पास उपलब्ध · ₹299 से शुरू' : '👑 Pro Pass Available · From ₹299';
  static String get premiumCancelledToast => _isHi ? 'भुगतान रद्द कर दिया गया।' : 'Payment was cancelled.';
  static String get premiumErrorToast => _isHi ? 'भुगतान पूरा नहीं हो सका। कृपया पुनः प्रयास करें।' : 'Payment could not be completed. Please try again.';
  static String get premiumPendingToast => _isHi ? 'भुगतान प्रक्रिया में है। पुष्टि होते ही पास सक्रिय हो जाएगा।' : 'Payment is pending. Your pass will be activated upon confirmation.';
  static String get premiumNoPurchasesFound => _isHi ? 'कोई पूर्व खरीद नहीं मिली।' : 'No previous purchases found.';

  // Congratulations Dialog
  static String get congratulationsTitle => _isHi ? 'बधाई हो! प्रो पास सक्रिय हो गया' : 'Congratulations! Pro Pass Activated';
  static String get congratulationsSub => _isHi
      ? 'आपकी प्रो सदस्यता सफलतापूर्वक सक्रिय कर दी गई है। अब आप सभी ${BankFacts.paperCount}+ प्रश्न-पुस्तिकाओं और विगत वर्ष पेपर्स को बिना किसी रोक-टोक के हल कर सकते हैं।'
      : 'Your Pro membership is now active. You have full unlimited access to all ${BankFacts.paperCount}+ exam booklets and previous year papers.';
  static String get startPreparingBtn => _isHi ? 'तैयारी शुरू करें' : 'Start Preparing';

  // Sanskrit Upcoming Notice
  static String get sanskritUpcomingTitle => _isHi ? 'संस्कृत भाषा जल्द उपलब्ध होगी' : 'Sanskrit Language Coming Soon';
  static String get sanskritUpcomingDesc => _isHi
      ? 'हमारी विषय विशेषज्ञ टीम आगामी अपडेट में संस्कृत भाषा द्वितीय के प्रामाणिक प्रश्न-पत्र जोड़ रही है। कृपया आगामी ऐप अपडेट की प्रतीक्षा करें।'
      : 'Our subject experts are curating authentic Sanskrit Language II question sets for the upcoming update. Please look forward to the next app update.';
  static String get understoodBtn => _isHi ? 'समझ गया' : 'Understood';

  // In-App Update (IAU)
  static String get updateAvailableTitle => _isHi ? 'नया ऐप अपडेट उपलब्ध है!' : 'New App Update Available!';
  static String get updateAvailableDesc => _isHi
      ? 'परीक्षा तैयारी के लिए नवीनतम प्रश्न और सुधार जोड़े गए हैं।'
      : 'Latest exam questions and enhancements have been added.';
  static String get updateNowBtn => _isHi ? 'अभी अपडेट करें' : 'Update Now';
  static String get updateLaterBtn => _isHi ? 'बाद में' : 'Later';
  static String get checkUpdateBtn => _isHi ? 'ऐप अपडेट की जाँच करें' : 'Check for Updates';
  static String get checkingUpdate => _isHi ? 'जाँच हो रही है...' : 'Checking for updates...';
  static String get appUpToDate => _isHi ? 'आपका ऐप नवीनतम संस्करण पर है।' : 'Your app is up to date.';
  static String get updateFound => _isHi ? 'नया संस्करण उपलब्ध है!' : 'New update available!';

  // In-App Review (IAR)
  static String get reviewPromptTitle => _isHi ? 'क्या आपको हमारी परीक्षा प्रश्न-पुस्तिकाएं पसंद आईं?' : 'Loving our Exam Booklets?';
  static String get reviewPromptDesc => _isHi
      ? 'आपका 5-स्टार रिव्यू हमें और बेहतर प्रामाणिक प्रश्न तैयार करने में मदद करता है।'
      : 'Your 5-star review helps us curate even better authentic questions.';
  static String get rateOnPlayStoreBtn => _isHi ? '⭐ Play Store पर रेट करें' : '⭐ Rate on Play Store';

  // Settings & Navigation Labels
  static String get targetExamHeading => _isHi ? 'लक्षित परीक्षा' : 'Target Examination';
  static String get examLevelHeading => _isHi ? 'पेपर स्तर' : 'Paper Level';
  static String get streamHeading =>
      _isHi ? 'विषय वर्ग (खंड IV)' : 'Subject Stream (Section IV)';
  static String get myReportsTooltip =>
      _isHi ? 'रिपोर्ट की गई प्रश्न' : 'Reported Questions';
  static String get langCardTitle => _isHi ? 'परीक्षा भाषा चयन' : 'Exam Language Selection';
  static String get langCardSubtitle => _isHi ? 'परीक्षा नियमानुसार अपनी भाषा I और भाषा II चुनें' : 'Select your Language I & Language II per exam pattern';
  static String get lang1Heading => _isHi
      ? 'भाषा प्रथम — $languageSectionQuestions प्रश्न'
      : 'Language I — $languageSectionQuestions Questions';
  static String get lang2Heading => _isHi
      ? 'भाषा द्वितीय — $languageSectionQuestions प्रश्न'
      : 'Language II — $languageSectionQuestions Questions';
  static String get langHindiLabel => _isHi ? 'हिन्दी' : 'Hindi';
  static String get langEnglishLabel => _isHi ? 'अंग्रेजी' : 'English';
  static String get langSanskritLabel => _isHi ? 'संस्कृत' : 'Sanskrit';
  static String get langNotice => _isHi ? 'परीक्षा नियमानुसार भाषा I और भाषा II अलग-अलग होनी अनिवार्य हैं।' : 'Per exam guidelines, Language I and Language II must be different.';

  // Question Report Sheet
  static String get reportSheetTitle =>
      _isHi ? 'प्रश्न पर आपत्ति / सुधार की रिपोर्ट' : 'Report an Issue or Correction';
  static String get reportWrongAnswer => _isHi ? 'उत्तर गलत है' : 'Wrong Answer Key';
  static String get reportIncompleteQuestion => _isHi ? 'अधूरा या अस्पष्ट प्रश्न' : 'Incomplete or Unclear Question';
  static String get reportTypo => _isHi ? 'टाइपिंग या वर्तनी की अशुद्धि' : 'Typo or Spelling Mistake';
  static String get reportOther => _isHi ? 'अन्य समस्या' : 'Other Issue';
  static String get reportSolved => _isHi ? 'हल हो गया' : 'Solved';
  static String get reportPending => _isHi ? 'समीक्षा जारी है' : 'Under Review';
  static String get reportSubmitBtn => _isHi ? 'रिपोर्ट दर्ज करें' : 'Submit Report';
  static String get reportSubmittedSuccess => _isHi ? 'आपकी रिपोर्ट दर्ज कर ली गई है। धन्यवाद!' : 'Your report has been submitted. Thank you!';

  // CBT & Solution Extra Tokens
  static String get questionPaletteTitle => _isHi ? 'प्रश्न पैलेट' : 'Question Palette';
  static String get selectLangTitle => _isHi ? 'भाषा चुनें' : 'Select Language';
  static String get recurringWeaknesses => _isHi ? 'बार-बार होने वाली गलतियाँ' : 'Recurring Weaknesses';
  static String get targetedRevisionNeed => _isHi ? 'गहन अभ्यास की आवश्यकता' : 'Targeted Revision Needed';

  // Math & Diagrams
  static String get tapToZoom => _isHi ? 'बड़ा देखने के लिए टैप करें' : 'Tap to Zoom';
  static String get diagramLabel => _isHi ? 'चित्र' : 'Diagram';
  static String get numberLineLabel => _isHi ? 'संख्या रेखा' : 'Number Line';
  static String get prismLabel => _isHi ? 'त्रिभुजाकार प्रिज्म' : 'Triangular Prism';
  static String get shadedRegionLabel => _isHi ? 'छायांकित भाग' : 'Shaded Region';

  // Test Mode Settings
  static String get testModeHeader => _isHi ? 'डिफ़ॉल्ट टेस्ट मोड' : 'Default Test Mode';
  static String get testModeDesc => _isHi
      ? 'टेस्ट हल करने के लिए अपना पसंदीदा मोड चुनें'
      : 'Choose your preferred interface for solving tests';
  static String get cbtModeTitle => _isHi ? '📱 CBT मोड (1 प्रश्न प्रति स्क्रीन)' : '📱 CBT Mode (1 Question per Screen)';
  static String get cbtModeSub => _isHi
      ? 'कम्प्यूटर टेस्ट · बड़ा साफ़ फॉन्ट · पूर्ण स्क्रीन · आँखों के लिए सुगम'
      : 'Computer test · Large clear font · Full screen · Easy on the eyes';
  static String get bookletModeTitle => _isHi ? '📄 प्रश्न-पुस्तिका मोड' : '📄 Question Booklet';
  static String get bookletModeSub => _isHi
      ? 'मानक परीक्षा पेपर · ${BankFacts.questionsPerPaper} प्रश्न सूची · OMR शीट शैली'
      : 'Standard exam paper · ${BankFacts.questionsPerPaper} questions list · OMR sheet style';
}

