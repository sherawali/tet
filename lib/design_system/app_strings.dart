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

  // â”€â”€ Exam, paper and subject-stream context â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // One wording for the exam, one for the paper and one for the paper-2
  // stream.  Every screen title is built from these three, so a candidate
  // can never mix a UTET paper-1 question with a CTET paper-2 one.
  static String get examName => _isCtet ? 'CTET' : 'UTET';

  /// The paper the candidate is working on (1 or 2).
  static int get currentPaperNumber => ExamService.instance.selectedPaper;

  /// The one wording for a paper: "à¤ªà¥‡à¤ªà¤°-1" / "Paper-1".
  static String paperName(int paper) => _isHi ? 'à¤ªà¥‡à¤ªà¤°-$paper' : 'Paper-$paper';

  /// The active paper-2 stream. Empty on paper 1.
  static String get activeStreamName => ExamService.instance.isPaper2
      ? (ExamService.instance.isSocialStream
          ? streamSocialStudies
          : streamMathScience)
      : '';

  /// "CTET à¤ªà¥‡à¤ªà¤°-2 Â· à¤—à¤£à¤¿à¤¤ à¤à¤µà¤‚ à¤µà¤¿à¤œà¥à¤žà¤¾à¤¨" - exam, paper and (paper 2) stream.
  static String get examPaperStreamLabel {
    final base = '$examName ${paperName(currentPaperNumber)}';
    final stream = activeStreamName;
    return stream.isEmpty ? base : '$base Â· $stream';
  }

  /// Builds a screen title that always names the exam, the paper and the
  /// paper-2 stream, so no two papers ever look the same on screen.
  static String screenTitle(String hi, String en) =>
      _isHi ? '$examPaperStreamLabel Â· $hi' : '$examPaperStreamLabel Â· $en';

  /// The exam pattern gives every language section the same number of
  /// questions, so the count lives in one place only.
  static const int languageSectionQuestions = 30;

  // Debug only (never shipped in a release build)
  static String get debugProPassTitle => _isHi ? 'Pro Pass (Debug)' : 'Pro Pass (Debug)';
  static String get debugProPassDesc => _isHi
      ? 'à¤¬à¤¿à¤¨à¤¾ à¤ªà¥ˆà¤®à¥‡à¤‚à¤Ÿ à¤•à¥‡ paid à¤”à¤° free à¤¦à¥‹à¤¨à¥‹à¤‚ à¤°à¥‚à¤ª à¤¦à¥‡à¤–à¥‡à¤‚à¥¤ Debug build à¤®à¥‡à¤‚ à¤¹à¥€ à¤¦à¤¿à¤–à¤¤à¤¾ à¤¹à¥ˆà¥¤'
      : 'See the paid and the free experience without paying. Shown in debug builds only.';
  static String get debugProPassPaid => _isHi
      ? 'à¤¸à¤­à¥€ à¤ªà¥‡à¤ªà¤° à¤–à¥à¤²à¥‡ à¤¹à¥ˆà¤‚ (paid view)'
      : 'All papers are open (paid view)';
  static String get debugProPassSwitchSub => _isHi
      ? 'à¤¸à¥à¤µà¤¿à¤š ON = paid view, OFF = free view'
      : 'Switch ON = paid view, OFF = free view';
  static String get debugProPassFree => _isHi
      ? 'à¤¸à¤¿à¤°à¥à¤« à¤®à¥à¤«à¤¼à¥à¤¤ à¤ªà¥‡à¤ªà¤° (free view)'
      : 'Only the free paper (free view)';

  // App Header
  static String get appTitle => '$examName ${paperName(currentPaperNumber)}';
  static String get appSubtitle => isPaper2
      ? (_isHi
          ? '$currentExamYear à¤¡à¤¿à¤œà¤¿à¤Ÿà¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ Â· $activeStreamName'
          : '$currentExamYear Digital Booklet Â· $activeStreamName')
      : (_isHi
          ? '$currentExamYear à¤¡à¤¿à¤œà¤¿à¤Ÿà¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤ªà¥‹à¤°à¥à¤Ÿà¤²'
          : '$currentExamYear Digital Booklet Portal');
  static String get bankSyncTooltip => _isHi ? 'à¤¬à¥ˆà¤‚à¤• à¤…à¤ªà¤¡à¥‡à¤Ÿ à¤•à¤°à¥‡à¤‚' : 'Update Bank Online';
  static String get langToggleLabel => _isHi ? 'ENG' : 'à¤¹à¤¿à¤¨à¥à¤¦à¥€';

  // Bank Strip
  static String get offlineBankTitle => _isHi ? 'à¤‘à¤«à¤²à¤¾à¤‡à¤¨ à¤¬à¥ˆà¤‚à¤•' : 'Offline Bank';
  static String get offlineBadge => _isHi ? '100% à¤‘à¤«à¤²à¤¾à¤‡à¤¨' : '100% Offline';
  static String bankInfo(int total, int pyq, int subjects) => _isHi
      ? '$total à¤•à¥à¤² à¤ªà¥à¤°à¤¶à¥à¤¨ Â· $pyq à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨ Â· $subjects à¤µà¤¿à¤·à¤¯'
      : '$total Total Questions Â· $pyq Previous Year Questions Â· $subjects Subjects';

  // Splash Screen
  static String get splashTitle =>
      _isHi ? 'UTET à¤à¤µà¤‚ CTET à¤¶à¤¿à¤•à¥à¤·à¤• à¤ªà¤¾à¤¤à¥à¤°à¤¤à¤¾ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾' : 'UTET & CTET Teacher Eligibility Test';
  static String get splashSubtitle => _isHi
      ? 'UTET à¤à¤µà¤‚ CTET $currentExamYear à¤¡à¤¿à¤œà¤¿à¤Ÿà¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤à¤µà¤‚ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£ à¤ªà¥‹à¤°à¥à¤Ÿà¤²'
      : 'UTET & CTET $currentExamYear Digital Question Booklet & Exam Analysis Portal';
  /// The paper the app will open with, shown on the splash screen.
  static String get splashTargetLabel => _isHi
      ? 'à¤µà¤°à¥à¤¤à¤®à¤¾à¤¨ à¤²à¤•à¥à¤·à¥à¤¯ : $examPaperStreamLabel'
      : 'Current target : $examPaperStreamLabel';
  static String get splashCheckingBank => _isHi ? 'à¤‘à¤«à¤²à¤¾à¤‡à¤¨ à¤¬à¥ˆà¤‚à¤• à¤•à¥€ à¤œà¤¾à¤à¤š à¤¹à¥‹ à¤°à¤¹à¥€ à¤¹à¥ˆ...' : 'Verifying offline bank...';
  static String splashAvailable(int count) => _isHi
      ? '$count à¤ªà¥à¤°à¤¶à¥à¤¨ à¤‘à¤«à¤²à¤¾à¤‡à¤¨ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¹à¥ˆà¤‚!'
      : '$count questions available offline!';
  static String get splashDownloading => _isHi
      ? 'à¤ªà¤¹à¤²à¥€ à¤¬à¤¾à¤° à¤•à¥‡ à¤²à¤¿à¤ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¡à¤¾à¤‰à¤¨à¤²à¥‹à¤¡ à¤¹à¥‹ à¤°à¤¹à¥‡ à¤¹à¥ˆà¤‚...'
      : 'Downloading questions for the first time...';
  static String get splashNoInternet => _isHi
      ? 'à¤‡à¤‚à¤Ÿà¤°à¤¨à¥‡à¤Ÿ à¤•à¤¨à¥‡à¤•à¥à¤¶à¤¨ à¤¨à¤¹à¥€à¤‚ à¤®à¤¿à¤²à¤¾à¥¤ à¤•à¥ƒà¤ªà¤¯à¤¾ à¤‡à¤‚à¤Ÿà¤°à¤¨à¥‡à¤Ÿ à¤šà¤¾à¤²à¥‚ à¤•à¤°à¤•à¥‡ à¤ªà¥à¤¨à¤ƒ à¤ªà¥à¤°à¤¯à¤¾à¤¸ à¤•à¤°à¥‡à¤‚à¥¤'
      : 'No internet connection. Please check your network and retry.';
  static String get splashRetryBtn => _isHi ? 'à¤ªà¥à¤¨à¤ƒ à¤ªà¥à¤°à¤¯à¤¾à¤¸ à¤•à¤°à¥‡à¤‚' : 'Retry Sync';

  // Hero Card
  static String get hitRibbon => _isCtet
      ? (_isHi ? 'NCERT à¤à¤µà¤‚ CBSE à¤ªà¤¾à¤ à¥à¤¯à¤•à¥à¤°à¤® à¤ªà¤° à¤ªà¥‚à¤°à¥à¤£à¤¤à¤ƒ à¤†à¤§à¤¾à¤°à¤¿à¤¤' : '100% Based on NCERT & CBSE Curriculum')
      : (_isHi ? 'à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤·à¥‹à¤‚ à¤•à¥‡ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¥ˆà¤Ÿà¤°à¥à¤¨ à¤ªà¤° à¤ªà¥‚à¤°à¥à¤£à¤¤à¤ƒ à¤†à¤§à¤¾à¤°à¤¿à¤¤' : '100% Based on Previous Exam Pattern');
  static String get heroTitle => _isHi
      ? '$examPaperStreamLabel Â· $currentExamYear à¤®à¥à¤–à¥à¤¯ à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : '$examPaperStreamLabel Â· $currentExamYear Flagship Model Test Paper';
  static String get heroDesc => _isCtet
      ? (_isHi
          ? 'à¤•à¥‡à¤¨à¥à¤¦à¥à¤°à¥€à¤¯ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¤¾à¤ à¥à¤¯à¤•à¥à¤°à¤® à¤ªà¤° à¤†à¤§à¤¾à¤°à¤¿à¤¤ à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ ${BankFacts.questionsPerPaper} à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¤¾ à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°à¥¤'
          : 'Complete ${BankFacts.questionsPerPaper}-question authentic model test paper based on the standard pattern.')
      : (_isHi
          ? 'à¤‰à¤¤à¥à¤¤à¤°à¤¾à¤–à¤£à¥à¤¡ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¥ˆà¤Ÿà¤°à¥à¤¨ à¤ªà¤° à¤†à¤§à¤¾à¤°à¤¿à¤¤ à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ ${BankFacts.questionsPerPaper} à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¤¾ à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°à¥¤'
          : 'Complete ${BankFacts.questionsPerPaper}-question authentic model test paper based on the Uttarakhand pattern.');
  static String get heroTotalQuestions => _isHi
      ? '${BankFacts.questionsPerPaper} à¤¬à¤¹à¥à¤µà¤¿à¤•à¤²à¥à¤ªà¥€à¤¯ à¤ªà¥à¤°à¤¶à¥à¤¨'
      : '${BankFacts.questionsPerPaper} MCQs';
  static String get heroTime {
    final total = BankFacts.questionsPerPaper;
    final h = total ~/ 60;
    final m = total % 60;
    if (_isHi) {
      return m == 0 ? 'à¤¸à¤®à¤¯ : $h à¤˜à¤‚à¤Ÿà¥‡' : 'à¤¸à¤®à¤¯ : $h à¤˜à¤‚à¤Ÿà¥‡ $m à¤®à¤¿à¤¨à¤Ÿ';
    }
    return m == 0 ? 'Time : $h Hrs' : 'Time : $h Hrs $m Min';
  }
  static String get heroMarks => _isHi
      ? 'à¤ªà¥‚à¤°à¥à¤£à¤¾à¤‚à¤• : ${BankFacts.questionsPerPaper} à¤…à¤‚à¤•'
      : 'Marks : ${BankFacts.questionsPerPaper}';
  static String get heroBtn => _isHi
      ? 'ðŸ“– à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤¹à¤² à¤•à¤°à¥‡à¤‚'
      : 'ðŸ“– Open & Solve Model Test Paper';

  // Booklet Sets
  static String get completeBookletsHeading => _isHi
      ? '$examPaperStreamLabel Â· à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾à¤à¤‚ (${BankFacts.questionsPerPaper} à¤ªà¥à¤°à¤¶à¥à¤¨ Â· ${BankFacts.questionsPerPaper} à¤®à¤¿à¤¨à¤Ÿ)'
      : '$examPaperStreamLabel Â· Complete Exam Booklets (${BankFacts.questionsPerPaper} Qs Â· ${BankFacts.questionsPerPaper} Mins)';

  static String get setQTitle => _isHi ? 'à¤¸à¥‡à¤Ÿ-Q : à¤¸à¤°à¥à¤µà¤¾à¤§à¤¿à¤• à¤ªà¥‚à¤›à¥‡ à¤—à¤ à¤ªà¥à¤°à¤¶à¥à¤¨' : 'SET-Q : Frequently Repeated Questions';
  static String get setQSub => _isHi ? '2+ à¤µà¤°à¥à¤· à¤šà¤•à¥à¤°à¥€à¤¯ à¤µ à¤‰à¤šà¥à¤š à¤…à¤‚à¤•à¤¦à¤¾à¤¯à¥€ à¤ªà¥à¤°à¤¶à¥à¤¨' : '2+ Years Recurring & High-Yield Questions';
  static String get setQTag => _isHi ? 'ðŸ”¥ à¤‰à¤šà¥à¤š à¤¦à¥‹à¤¹à¤°à¤¾à¤µ' : 'ðŸ”¥ High Recurrence';

  static String get setRTitle => _isHi ? 'à¤¸à¥‡à¤Ÿ-R : à¤•à¥‡à¤µà¤² à¤ªà¥‚à¤°à¥à¤µ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨' : 'SET-R : Past Year Questions';
  static String setRSub(int pyqCount, String years) => _isHi
      ? '$pyqCount à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• ${_isCtet ? "CTET" : "UTET"} à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¬à¥ˆà¤‚à¤• ($years)'
      : '$pyqCount Authentic ${_isCtet ? "CTET" : "UTET"} Questions ($years)';
  static String get setRTag => _isHi ? 'ðŸ“œ à¤ªà¥‚à¤°à¥à¤µ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨' : 'ðŸ“œ Past Year Questions';

  static String get setSTitle => _isHi ? 'à¤¸à¥‡à¤Ÿ-S : à¤¨à¤µà¥€à¤¨ à¤¸à¤‚à¤­à¤¾à¤µà¤¿à¤¤ à¤ªà¥à¤°à¤¶à¥à¤¨' : 'SET-S : Fresh Potential Questions';
  static String get setSSub => _isHi ? 'à¤¨à¤ à¤¶à¤¿à¤•à¥à¤·à¤£à¤¶à¤¾à¤¸à¥à¤¤à¥à¤° à¤µ à¤¸à¥ˆà¤¦à¥à¤§à¤¾à¤‚à¤¤à¤¿à¤• à¤•à¥‡à¤¸ à¤ªà¥à¤°à¤¶à¥à¤¨' : 'New pedagogy & conceptual case questions';
  static String get setSTag => _isHi ? 'âœ¨ à¤«à¥à¤°à¥‡à¤¶ à¤…à¤­à¥à¤¯à¤¾à¤¸' : 'âœ¨ Fresh Practice';

  static String get setTTitle => _isHi ? 'à¤¸à¥‡à¤Ÿ-T : à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ à¤®à¤¿à¤¶à¥à¤°à¤¿à¤¤ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾' : 'SET-T : Complete Balanced Mock Test';
  static String get setTSub => _isHi ? 'à¤®à¤¾à¤¨à¤• à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¥ˆà¤Ÿà¤°à¥à¤¨ à¤…à¤¨à¥à¤°à¥‚à¤ª à¤¸à¤‚à¤¤à¥à¤²à¤¿à¤¤ à¤¬à¥à¤²à¥‚à¤ªà¥à¤°à¤¿à¤‚à¤Ÿ' : 'Standard exam pattern balanced blueprint';
  static String get setTTag => _isHi ? 'âš–ï¸ à¤¸à¤‚à¤¤à¥à¤²à¤¿à¤¤' : 'âš–ï¸ Balanced';

  // Subject Booklets
  static String get subjectBookletsHeading => _isHi
      ? '$examPaperStreamLabel Â· à¤–à¤£à¥à¤¡-à¤µà¤¾à¤° à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾à¤à¤‚ (${BankFacts.subjectSetQuestions} à¤ªà¥à¤°à¤¶à¥à¤¨ Â· ${BankFacts.subjectSetQuestions} à¤®à¤¿à¤¨à¤Ÿ)'
      : '$examPaperStreamLabel Â· Subject-wise Practice Booklets (${BankFacts.subjectSetQuestions} Qs Â· ${BankFacts.subjectSetQuestions} Mins)';

  static String get pastHistoryHeading =>
      screenTitle('à¤ªà¤¿à¤›à¤²à¥‡ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤•à¤¾ à¤°à¤¿à¤•à¥‰à¤°à¥à¤¡', 'Past Test History');
  static String get doubleBackExit => _isHi ? 'à¤à¤ª à¤¬à¤‚à¤¦ à¤•à¤°à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤¦à¥‹à¤¬à¤¾à¤°à¤¾ à¤¬à¥ˆà¤• à¤¦à¤¬à¤¾à¤à¤‚' : 'Press back again to exit app';

  // Navigation Bar
  static String get navBooklets => _isHi ? 'à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾' : 'Booklets';
  static String get navSubjects => _isHi ? 'à¤µà¤¿à¤·à¤¯ à¤…à¤­à¥à¤¯à¤¾à¤¸' : 'Subjects';
  static String get navHistory => _isHi ? 'à¤‡à¤¤à¤¿à¤¹à¤¾à¤¸' : 'History';
  static String get navSettings => _isHi ? 'à¤¸à¥‡à¤Ÿà¤¿à¤‚à¤—à¥à¤¸' : 'Settings';

  // Subject Practice Portal
  static String get subjectPracticeHeading =>
      screenTitle('à¤–à¤£à¥à¤¡-à¤µà¤¾à¤° à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾à¤à¤‚', 'Subject-wise Practice Booklets');
  static String get subjectPracticeDesc => _isHi
      ? 'à¤ªà¥à¤°à¤¤à¥à¤¯à¥‡à¤• à¤µà¤¿à¤·à¤¯ à¤®à¥‡à¤‚ ${BankFacts.subjectSetQuestions} à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤ªà¥à¤°à¤¶à¥à¤¨ à¤”à¤° ${BankFacts.subjectSetQuestions} à¤®à¤¿à¤¨à¤Ÿ à¤•à¤¾ à¤¸à¤®à¤¯'
      : '${BankFacts.subjectSetQuestions} authentic questions & ${BankFacts.subjectSetQuestions} minutes for each subject';
  static String get subjectCardTime => _isHi
      ? '${BankFacts.subjectSetQuestions} à¤ªà¥à¤°à¤¶à¥à¤¨ Â· ${BankFacts.subjectSetQuestions} à¤®à¤¿à¤¨à¤Ÿ'
      : '${BankFacts.subjectSetQuestions} Qs Â· ${BankFacts.subjectSetQuestions} Mins';
  static String get startSubjectTestBtn => _isHi ? 'à¤¹à¤² à¤¶à¥à¤°à¥‚ à¤•à¤°à¥‡à¤‚ â–¾' : 'Start Practice â–¾';

  // Test History
  static String get historyTitle =>
      screenTitle('à¤ªà¤¿à¤›à¤²à¥‡ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤•à¤¾ à¤°à¤¿à¤•à¥‰à¤°à¥à¤¡', 'Past Test History');
  static String historySummary(int count, int pass) => _isHi
      ? 'à¤•à¥à¤² à¤Ÿà¥‡à¤¸à¥à¤Ÿ: $count Â· à¤‰à¤¤à¥à¤¤à¥€à¤°à¥à¤£: $pass'
      : 'Total Tests: $count Â· Qualified: $pass';
  static String get historyEmptyTitle => _isHi ? 'à¤•à¥‹à¤ˆ à¤ªà¤¿à¤›à¤²à¤¾ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤°à¤¿à¤•à¥‰à¤°à¥à¤¡ à¤¨à¤¹à¥€à¤‚ à¤®à¤¿à¤²à¤¾' : 'No Test History Found';
  static String get historyEmptyDesc => _isHi
      ? 'à¤†à¤ªà¤¨à¥‡ à¤…à¤­à¥€ à¤¤à¤• à¤•à¥‹à¤ˆ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤¨à¤¹à¥€à¤‚ à¤¦à¤¿à¤¯à¤¾ à¤¹à¥ˆà¥¤ $examPaperStreamLabel $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤¸à¥‡ à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤•à¥€ à¤¶à¥à¤°à¥à¤†à¤¤ à¤•à¤°à¥‡à¤‚à¥¤'
      : 'You have not attempted any test yet. Begin with the $examPaperStreamLabel $currentExamYear model test paper.';
  static String get historyStartCta =>
      _isHi ? 'ðŸ“– à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤¹à¤² à¤•à¤°à¥‡à¤‚' : 'ðŸ“– Solve Model Test Paper';
  static String historyMockType(String mode) => _isHi ? 'à¤®à¥‰à¤• à¤Ÿà¥‡à¤¸à¥à¤Ÿ ($mode)' : 'Mock Test ($mode)';
  static String get historyQualified => _isHi ? 'à¤‰à¤¤à¥à¤¤à¥€à¤°à¥à¤£' : 'Qualified';
  static String get historyPracticeNeeded => _isHi ? 'à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤†à¤µà¤¶à¥à¤¯à¤•' : 'Needs Practice';

  // Settings Screen
  static String get settingsTitle =>
      screenTitle('à¤à¤ª à¤¸à¥‡à¤Ÿà¤¿à¤‚à¤—à¥à¤¸ à¤à¤µà¤‚ à¤­à¤¾à¤·à¤¾', 'App Settings & Language');
  static String get settingsLangHeader => _isHi ? 'à¤­à¤¾à¤·à¤¾ à¤šà¤¯à¤¨ / App Language' : 'App Language / à¤­à¤¾à¤·à¤¾ à¤šà¤¯à¤¨';
  static String get settingsLangDesc => _isHi
      ? 'à¤ªà¥‚à¤°à¥€ à¤à¤ª à¤•à¥€ à¤­à¤¾à¤·à¤¾ à¤à¤• à¤•à¥à¤²à¤¿à¤• à¤®à¥‡à¤‚ à¤¹à¤¿à¤¨à¥à¤¦à¥€ à¤¯à¤¾ à¤…à¤‚à¤—à¥à¤°à¥‡à¤œà¥€ à¤®à¥‡à¤‚ à¤¬à¤¦à¤²à¥‡à¤‚'
      : 'Switch the entire app interface between Hindi and English';
  static String get settingsBankHeader => _isHi ? 'à¤‘à¤«à¤²à¤¾à¤‡à¤¨ à¤¡à¥‡à¤Ÿà¤¾à¤¬à¥‡à¤¸ à¤µ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¬à¥ˆà¤‚à¤•' : 'Offline Database & Question Bank';
  static String get settingsBankDesc => _isHi
      ? 'à¤•à¥à¤²à¤¾à¤‰à¤¡ à¤¸à¤°à¥à¤µà¤° à¤¸à¥‡ à¤¸à¥€à¤§à¤¾ à¤œà¥à¤¡à¤¼à¤¾ à¤¹à¥à¤†à¥¤ à¤¨à¤ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤µ à¤¸à¥à¤§à¤¾à¤° à¤¤à¥à¤°à¤‚à¤¤ à¤«à¥‹à¤¨ à¤®à¥‡à¤‚ à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤ à¤¹à¥‹à¤¤à¥‡ à¤¹à¥ˆà¤‚à¥¤ 100% à¤‘à¤«à¤²à¤¾à¤‡à¤¨ à¤…à¤­à¥à¤¯à¤¾à¤¸à¥¤'
      : 'Direct cloud sync. Latest questions and verified fixes are saved to your device for 100% offline practice.';
  static String get settingsBankSyncBtn => _isHi ? 'à¤¤à¤¾à¤œà¤¼à¤¾ à¤¸à¤¿à¤‚à¤•' : 'Sync Now';
  static String get dbCleanResyncBtn => _isHi ? 'ðŸ”„ à¤ªà¥‚à¤°à¥à¤£ à¤°à¥€-à¤¸à¤¿à¤‚à¤•' : 'ðŸ”„ Full Re-sync';
  static String get dbOptimizeBtn => _isHi ? 'âš¡ à¤¸à¥à¤Ÿà¥‹à¤°à¥‡à¤œ à¤‘à¤ªà¥à¤Ÿà¤¿à¤®à¤¾à¤‡à¤œà¤¼' : 'âš¡ Optimize Storage';
  static String get dbCleanDialogTitle => _isHi ? 'à¤¡à¥‡à¤Ÿà¤¾à¤¬à¥‡à¤¸ à¤¸à¤¾à¤«à¤¼ à¤µ à¤ªà¥‚à¤°à¥à¤£ à¤°à¥€-à¤¸à¤¿à¤‚à¤•?' : 'Clean & Full Re-sync?';
  static String get dbCleanDialogDesc => _isHi
      ? 'à¤•à¥à¤¯à¤¾ à¤†à¤ª à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¬à¥ˆà¤‚à¤• à¤•à¤¾ à¤•à¥ˆà¤¶ à¤¸à¤¾à¤«à¤¼ à¤•à¤° à¤¨à¤ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¥à¤¨à¤ƒ à¤¡à¤¾à¤‰à¤¨à¤²à¥‹à¤¡ à¤•à¤°à¤¨à¤¾ à¤šà¤¾à¤¹à¤¤à¥‡ à¤¹à¥ˆà¤‚?\n\nâ€¢ à¤¸à¤­à¥€ à¤¨à¤ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤µ à¤¸à¥à¤§à¤¾à¤° à¤¡à¤¾à¤‰à¤¨à¤²à¥‹à¤¡ à¤¹à¥‹à¤‚à¤—à¥‡à¥¤\nâ€¢ à¤†à¤ªà¤•à¤¾ à¤ªà¤¿à¤›à¤²à¤¾ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤‡à¤¤à¤¿à¤¹à¤¾à¤¸ à¤”à¤° à¤—à¤²à¤¤à¤¿à¤¯à¥‹à¤‚ à¤•à¤¾ à¤°à¤¿à¤•à¥‰à¤°à¥à¤¡ 100% à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤ à¤°à¤¹à¥‡à¤—à¤¾à¥¤'
      : 'Do you want to clear question bank cache and re-download fresh questions?\n\nâ€¢ All updated questions & corrections will be fetched.\nâ€¢ Your past test history and mistake records will remain 100% safe.';
  static String get dbCleanConfirmBtn => _isHi ? 'à¤¹à¤¾à¤, à¤¸à¤¾à¤«à¤¼ à¤µ à¤¡à¤¾à¤‰à¤¨à¤²à¥‹à¤¡ à¤•à¤°à¥‡à¤‚' : 'Yes, Clean & Download';
  static String get dbCancelBtn => _isHi ? 'à¤°à¤¦à¥à¤¦ à¤•à¤°à¥‡à¤‚' : 'Cancel';
  static String get dbOptimizingToast => _isHi ? 'à¤¡à¥‡à¤Ÿà¤¾à¤¬à¥‡à¤¸ à¤•à¥‹ à¤‘à¤ªà¥à¤Ÿà¤¿à¤®à¤¾à¤‡à¤œà¤¼ à¤•à¤¿à¤¯à¤¾ à¤œà¤¾ à¤°à¤¹à¤¾ à¤¹à¥ˆ...' : 'Optimizing database...';
  static String get dbOptimizeDoneTitle => _isHi ? 'âš¡ à¤¸à¥à¤Ÿà¥‹à¤°à¥‡à¤œ 100% à¤‘à¤ªà¥à¤Ÿà¤¿à¤®à¤¾à¤‡à¤œà¤¼à¥à¤¡!' : 'âš¡ Storage 100% Optimized!';
  static String dbOptimizeDoneDesc(String savedKb) => _isHi
      ? 'à¤¡à¥‡à¤Ÿà¤¾à¤¬à¥‡à¤¸ à¤‡à¤‚à¤¡à¥‡à¤•à¥à¤¸ à¤°à¥€à¤¬à¤¿à¤²à¥à¤¡ à¤•à¤° $savedKb KB à¤¸à¥à¤Ÿà¥‹à¤°à¥‡à¤œ à¤®à¥à¤•à¥à¤¤ à¤•à¤¿à¤¯à¤¾ à¤—à¤¯à¤¾à¥¤ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤²à¥‹à¤¡à¤¿à¤‚à¤— à¤”à¤° à¤¸à¤°à¥à¤š à¤…à¤¬ à¤¸à¥à¤ªà¤°à¤«à¤¼à¤¾à¤¸à¥à¤Ÿ à¤¹à¥‹à¤—à¥€à¥¤'
      : 'All database indexes rebuilt and $savedKb KB unused storage space reclaimed. Test loading and search is now blazing fast.';
  static String get dbStorageSizeLabel => _isHi ? 'à¤²à¥‹à¤•à¤² à¤¸à¥à¤Ÿà¥‹à¤°à¥‡à¤œ' : 'Local Storage';
  static String get dbLastSyncedLabel => _isHi ? 'à¤…à¤‚à¤¤à¤¿à¤® à¤¸à¤¿à¤‚à¤•' : 'Last Synced';
  static String get dbNeverSynced => _isHi ? 'à¤…à¤­à¥€ à¤¨à¤¹à¥€à¤‚' : 'Not yet';
  static String get settingsSyncChecking => _isHi ? 'à¤‘à¤¨à¤²à¤¾à¤‡à¤¨ à¤¨à¤ à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¥€ à¤œà¤¾à¤à¤š à¤¹à¥‹ à¤°à¤¹à¥€ à¤¹à¥ˆ...' : 'Checking for new questions online...';
  static String get settingsSyncSuccess => _isHi ? 'âœ… à¤¬à¥ˆà¤‚à¤• à¤¸à¤«à¤²à¤¤à¤¾à¤ªà¥‚à¤°à¥à¤µà¤• à¤…à¤ªà¤¡à¥‡à¤Ÿ à¤¹à¥‹ à¤—à¤¯à¤¾!' : 'âœ… Question bank updated successfully!';
  static String settingsSyncError(String e) => _isHi ? 'à¤¸à¤¿à¤‚à¤• à¤®à¥‡à¤‚ à¤¸à¤®à¤¸à¥à¤¯à¤¾: $e' : 'Sync error: $e';
  static String get settingsModelHeader => _isHi ? 'à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£ ($currentExamYear)' : 'Exam Specialist Analysis ($currentExamYear)';
  static String get settingsModelDesc => _isHi
      ? 'à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤·à¥‹à¤‚ à¤•à¥‡ à¤¸à¤­à¥€ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°à¥‹à¤‚ à¤”à¤° à¤®à¥à¤–à¥à¤¯ à¤•à¥‹à¤° à¤Ÿà¥‰à¤ªà¤¿à¤•à¥à¤¸ à¤•à¤¾ à¤—à¤¹à¤¨ à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£ à¤à¤µà¤‚ à¤¸à¤Ÿà¥€à¤• à¤¬à¥à¤²à¥‚à¤ªà¥à¤°à¤¿à¤‚à¤Ÿà¥¤'
      : 'In-depth analytical assessment of all past year papers and high-yield core topics.';
  static String get settingsAbout => _isHi ? 'TET Mock Master v1.0 Â· 100% à¤‘à¤«à¤²à¤¾à¤‡à¤¨' : 'TET Mock Master v1.0 Â· 100% Offline';

  // Sync Feedback Bilingual Strings
  static String syncSuccessAddedTitle(int count) => _isHi
      ? 'ðŸŽ‰ $count à¤¨à¤ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤œà¥‹à¤¡à¤¼à¥‡ à¤—à¤!'
      : 'ðŸŽ‰ $count New Questions Added!';
  static String syncSuccessAddedDesc(int totalCount) => _isHi
      ? 'à¤†à¤ªà¤•à¤¾ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¬à¥ˆà¤‚à¤• à¤…à¤¬ à¤•à¥à¤² $totalCount à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¥‡ à¤¸à¤¾à¤¥ à¤¨à¤µà¥€à¤¨à¤¤à¤® à¤¹à¥ˆà¥¤ CTET à¤à¤µà¤‚ UTET à¤¦à¥‹à¤¨à¥‹à¤‚ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾à¤“à¤‚ à¤•à¥€ à¤¸à¤¾à¤®à¤—à¥à¤°à¥€ à¤…à¤¬ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¹à¥ˆà¥¤'
      : 'Your question bank is now up-to-date with $totalCount authentic questions. Complete material for CTET & UTET is ready.';
  static String get syncUpToDateTitle => _isHi
      ? 'âœ… à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¬à¥ˆà¤‚à¤• à¤ªà¥‚à¤°à¥à¤£à¤¤à¤ƒ à¤…à¤¦à¥à¤¯à¤¤à¤¨ à¤¹à¥ˆ!'
      : 'âœ… Question Bank is Fully Up-to-Date!';
  static String syncUpToDateDesc(int totalCount) => _isHi
      ? 'à¤†à¤ªà¤•à¥‡ à¤«à¥‹à¤¨ à¤®à¥‡à¤‚ à¤¸à¤­à¥€ $totalCount à¤ªà¥à¤°à¤¶à¥à¤¨, à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤•à¥‡ PYQ à¤à¤µà¤‚ à¤—à¤¦à¥à¤¯à¤¾à¤‚à¤¶ à¤ªà¤¹à¤²à¥‡ à¤¸à¥‡ à¤¹à¥€ à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤ à¤¹à¥ˆà¤‚à¥¤ à¤•à¥‹à¤ˆ à¤¨à¤¯à¤¾ à¤¸à¤‚à¤¶à¥‹à¤§à¤¨ à¤²à¤‚à¤¬à¤¿à¤¤ à¤¨à¤¹à¥€à¤‚ à¤¹à¥ˆà¥¤'
      : 'All $totalCount questions, past PYQs, and passages are safely stored on your device. Everything is up-to-date.';
  static String get syncErrorTitle => _isHi
      ? 'âš ï¸ à¤¨à¥‡à¤Ÿà¤µà¤°à¥à¤• à¤¸à¤¿à¤‚à¤• à¤®à¥‡à¤‚ à¤¸à¤®à¤¸à¥à¤¯à¤¾ à¤†à¤ˆ'
      : 'âš ï¸ Sync Connection Issue';
  static String syncErrorDesc(String? msg) => _isHi
      ? (msg ?? 'à¤•à¥ƒà¤ªà¤¯à¤¾ à¤‡à¤‚à¤Ÿà¤°à¤¨à¥‡à¤Ÿ à¤•à¤¨à¥‡à¤•à¥à¤¶à¤¨ à¤œà¤¾à¤à¤šà¥‡à¤‚ à¤”à¤° à¤ªà¥à¤¨à¤ƒ à¤ªà¥à¤°à¤¯à¤¾à¤¸ à¤•à¤°à¥‡à¤‚à¥¤ à¤‘à¤«à¤²à¤¾à¤‡à¤¨ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¬à¥ˆà¤‚à¤• à¤ªà¥‚à¤°à¥€ à¤¤à¤°à¤¹ à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤ à¤¹à¥ˆà¥¤')
      : (msg ?? 'Please check your internet connection and try again. Your offline question bank is completely safe.');
  static String syncTotalQuestionsChip(int total) => _isHi
      ? 'ðŸ“š à¤•à¥à¤² à¤ªà¥à¤°à¤¶à¥à¤¨: $total'
      : 'ðŸ“š Total Questions: $total';
  static String get syncOfflineChip => _isHi
      ? 'âš¡ 100% à¤‘à¤«à¤¼à¤²à¤¾à¤‡à¤¨ à¤…à¤­à¥à¤¯à¤¾à¤¸'
      : 'âš¡ 100% Offline Access';
  static String get syncContinueBtn => _isHi
      ? 'à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤œà¤¾à¤°à¥€ à¤°à¤–à¥‡à¤‚'
      : 'Continue Practice';
  static String dbTotalQuestionsChip(int total) => _isHi
      ? 'ðŸ“š à¤•à¥à¤² à¤ªà¥à¤°à¤¶à¥à¤¨: $total'
      : 'ðŸ“š Total Questions: $total';
  static String dbSpaceFreedChip(String savedKb) => _isHi
      ? 'âš¡ à¤®à¥à¤•à¥à¤¤ à¤¸à¥à¤ªà¥‡à¤¸: $savedKb KB'
      : 'âš¡ Space Freed: $savedKb KB';
  static String dbOrphanDeletedChip(int count) => _isHi
      ? 'ðŸ§¹ à¤¸à¤¾à¤«à¤¼ à¤•à¤¿à¤ à¤—à¤: $count'
      : 'ðŸ§¹ Cleaned: $count';

  // Home Loading and Errors
  static String get loadingGenerating => _isHi
      ? 'à¤®à¤¾à¤¨à¤• à¤¬à¥à¤²à¥‚à¤ªà¥à¤°à¤¿à¤‚à¤Ÿ à¤¸à¥‡ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤¤à¥ˆà¤¯à¤¾à¤° à¤¹à¥‹ à¤°à¤¹à¥€ à¤¹à¥ˆ...'
      : 'Preparing question booklet according to standard blueprint...';
  static String loadError(String e) => _isHi ? 'à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤²à¥‹à¤¡ à¤•à¤°à¤¨à¥‡ à¤®à¥‡à¤‚ à¤¸à¤®à¤¸à¥à¤¯à¤¾: $e' : 'Failed to load test: $e';

  // Booklet Exam Screen
  static String get exitExamTitle => _isHi ? 'à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤µà¤¿à¤°à¤¾à¤® / à¤¬à¤¾à¤¹à¤° à¤¨à¤¿à¤•à¤²à¥‡à¤‚' : 'Pause Exam / Exit';
  static String exitExamRemaining(int total, int answered, int remaining) => _isHi
      ? 'à¤•à¥à¤² $total à¤®à¥‡à¤‚ à¤¸à¥‡ $answered à¤¹à¤² à¤•à¤¿à¤, $remaining à¤¶à¥‡à¤·'
      : 'Answered $answered of $total, $remaining remaining';
  static String get continueTestBtn => _isHi ? 'à¤¹à¤² à¤•à¤°à¤¨à¤¾ à¤œà¤¾à¤°à¥€ à¤°à¤–à¥‡à¤‚' : 'Continue Test';
  static String get submitViewResultBtn => _isHi ? 'à¤¸à¤¬à¤®à¤¿à¤Ÿ à¤•à¤°à¥‡à¤‚ à¤”à¤° à¤ªà¤°à¤¿à¤£à¤¾à¤® à¤¦à¥‡à¤–à¥‡à¤‚' : 'Submit & View Result';
  static String get discardDirectExitBtn => _isHi ? 'à¤¬à¤¿à¤¨à¤¾ à¤ªà¤°à¤¿à¤£à¤¾à¤® à¤•à¥‡ à¤¸à¥€à¤§à¥‡ à¤¬à¤¾à¤¹à¤° à¤œà¤¾à¤à¤‚ / à¤°à¤¦à¥à¤¦ à¤•à¤°à¥‡à¤‚' : 'Discard & Exit Without Result';

  static String get bookletAnswered => _isHi ? 'à¤¹à¤² à¤•à¤¿à¤: ' : 'Answered: ';
  static String get bookletRemaining => _isHi ? '  |  à¤¶à¥‡à¤·: ' : '  |  Remaining: ';
  static String get bookletTotal => _isHi ? '  |  à¤•à¥à¤² à¤ªà¥à¤°à¤¶à¥à¤¨: ' : '  |  Total: ';
  static String get bookletProgress => _isHi ? '  |  à¤ªà¥à¤°à¤—à¤¤à¤¿: ' : '  |  Progress: ';
  static String get submitBtn => _isHi ? 'à¤œà¤®à¤¾' : 'Submit';

  // Result Screen
  static String get resultsTitle =>
      screenTitle('à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¤°à¤¿à¤£à¤¾à¤® à¤à¤µà¤‚ à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£', 'Exam Results & Analysis');
  static String get passGeneral => _isHi
      ? 'ðŸŽ‰ à¤¬à¤§à¤¾à¤ˆ! à¤†à¤ª à¤‰à¤¤à¥à¤¤à¥€à¤°à¥à¤£ à¤¹à¥ˆà¤‚ (${(ExamRules.generalPassRatio * 100).round()}%+)'
      : 'ðŸŽ‰ Congratulations! You Passed (${(ExamRules.generalPassRatio * 100).round()}%+)';
  static String get passReserved => _isHi
      ? 'â­ à¤†à¤°à¤•à¥à¤·à¤¿à¤¤ à¤µà¤°à¥à¤— à¤®à¥‡à¤‚ à¤‰à¤¤à¥à¤¤à¥€à¤°à¥à¤£ (${(ExamRules.reservedPassRatio * 100).round()}%+)'
      : 'â­ Qualified in Reserved Category (${(ExamRules.reservedPassRatio * 100).round()}%+)';
  static String get needMorePractice => _isHi ? 'ðŸŽ¯ à¤”à¤° à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤•à¥€ à¤†à¤µà¤¶à¥à¤¯à¤•à¤¤à¤¾ à¤¹à¥ˆ' : 'ðŸŽ¯ More Practice Needed';
  static String get rePracticeTitle => _isHi ? 'à¤—à¤²à¤¤ à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¤¾ à¤ªà¥à¤¨à¤ƒ à¤…à¤­à¥à¤¯à¤¾à¤¸' : 'Re-practice Incorrect Questions';
  static String rePracticeSub(int count) => _isHi
      ? '$count à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤®à¥‡à¤‚ à¤—à¤²à¤¤à¤¿à¤¯à¤¾à¤ à¤¹à¥à¤ˆà¤‚à¥¤ à¤¦à¥‹à¤¬à¤¾à¤°à¤¾ à¤¹à¤² à¤•à¤°à¤•à¥‡ 100% à¤¸à¤Ÿà¥€à¤• à¤¬à¤¨à¤¾à¤à¤‚à¥¤'
      : '$count questions were answered incorrectly. Re-attempt to achieve 100% accuracy.';
  static String rePracticeBtn(int count) => _isHi
      ? 'ðŸ” à¤—à¤²à¤¤ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¦à¥‹à¤¬à¤¾à¤°à¤¾ à¤¹à¤² à¤•à¤°à¥‡à¤‚ ($count à¤ªà¥à¤°à¤¶à¥à¤¨)'
      : 'ðŸ” Re-solve Incorrect Questions ($count Qs)';
  static String get guidanceTitle => _isHi ? 'à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž à¤®à¤¾à¤°à¥à¤—à¤¦à¤°à¥à¤¶à¤¨ à¤à¤µà¤‚ à¤¸à¤¹à¥€ à¤¸à¤²à¤¾à¤¹' : 'Expert Guidance & Recommendations';
  static String get sectionBreakdownTitle => _isHi ? 'à¤µà¤¿à¤·à¤¯à¤µà¤¾à¤° à¤ªà¥à¤°à¤¦à¤°à¥à¤¶à¤¨' : 'Section-wise Performance Breakdown';
  static String get topicAnalysisTitle => _isHi ? 'à¤Ÿà¥‰à¤ªà¤¿à¤•-à¤µà¤¾à¤° à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£' : 'Topic-wise Analysis';
  static String get viewSolutionsBtn => _isHi ? 'ðŸ“– à¤µà¤¿à¤¸à¥à¤¤à¥ƒà¤¤ à¤‰à¤¤à¥à¤¤à¤° à¤•à¥à¤‚à¤œà¥€ à¤à¤µà¤‚ à¤¹à¤²' : 'ðŸ“– Detailed Answer Key & Solutions';
  static String get backHomeBtn => _isHi ? 'à¤®à¥à¤–à¥à¤¯ à¤ªà¥ƒà¤·à¥à¤  à¤ªà¤° à¤µà¤¾à¤ªà¤¸ à¤œà¤¾à¤à¤‚' : 'Return to Home Screen';

  // Solution Screen
  static String get solutionsTitle => screenTitle(
      'à¤µà¤¿à¤¸à¥à¤¤à¥ƒà¤¤ à¤‰à¤¤à¥à¤¤à¤° à¤•à¥à¤‚à¤œà¥€ à¤à¤µà¤‚ à¤¹à¤²',
      'Answer Key & Detailed Solutions');
  static String get solFilterAll => _isHi ? 'à¤¸à¤­à¥€' : 'All';
  static String get solFilterIncorrect => _isHi ? 'à¤—à¤²à¤¤' : 'Incorrect';
  static String get solFilterUnattempted => _isHi ? 'à¤›à¥‹à¤¡à¤¼à¥‡ à¤—à¤' : 'Unattempted';
  static String get solFilterCorrect => _isHi ? 'à¤¸à¤¹à¥€' : 'Correct';
  static String get solNoQuestionsInCategory => _isHi ? 'à¤‡à¤¸ à¤¶à¥à¤°à¥‡à¤£à¥€ à¤®à¥‡à¤‚ à¤•à¥‹à¤ˆ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¨à¤¹à¥€à¤‚ à¤¹à¥ˆ' : 'No questions in this category';
  static String solQuestionNum(int num) => _isHi ? 'à¤ªà¥à¤°à¤¶à¥à¤¨ $num' : 'Question $num';
  static String get solBadgeUnattempted => _isHi ? 'à¤›à¥‹à¤¡à¤¼à¤¾ à¤—à¤¯à¤¾' : 'Unattempted';
  static String get solBadgeCorrect => _isHi ? 'âœ… à¤¸à¤¹à¥€ (+1)' : 'âœ… Correct (+1)';
  static String get solBadgeIncorrect => _isHi ? 'âŒ à¤—à¤²à¤¤ (0)' : 'âŒ Incorrect (0)';
  static String solProbScore(double score) => _isHi
      ? 'à¤¸à¤‚à¤­à¤¾à¤µà¤¨à¤¾ à¤…à¤‚à¤•: ${(score * 100).toStringAsFixed(0)}%'
      : 'Probability: ${(score * 100).toStringAsFixed(0)}%';

  // Result Extra Tokens
  static String resultMarksPct(double pct) => _isHi ? '${pct.toStringAsFixed(1)}% à¤…à¤‚à¤•' : '${pct.toStringAsFixed(1)}% Marks';
  static String resultAccuracy(double acc) => _isHi ? 'à¤¸à¤Ÿà¥€à¤•à¤¤à¤¾: ${acc.toStringAsFixed(0)}%' : 'Accuracy: ${acc.toStringAsFixed(0)}%';
  static String resultTime(int mins) => _isHi ? '$mins à¤®à¤¿à¤¨à¤Ÿ à¤¸à¤®à¤¯' : '$mins Mins Time';
  static String get correctShort => _isHi ? 'à¤¸à¤¹à¥€' : 'Correct';
  static String get wrongShort => _isHi ? 'à¤—à¤²à¤¤' : 'Wrong';
  static String get unattemptedShort => _isHi ? 'à¤¶à¥‡à¤·' : 'Skipped';
  static String get accuracyShort => _isHi ? 'à¤¸à¤Ÿà¥€à¤•à¤¤à¤¾' : 'Accuracy';
  static String get topWeakTopicsWarning => _isHi ? 'âš ï¸ à¤‡à¤¨ à¤®à¥à¤–à¥à¤¯ à¤Ÿà¥‰à¤ªà¤¿à¤•à¥à¤¸ à¤ªà¤° à¤¤à¥à¤°à¤‚à¤¤ à¤§à¥à¤¯à¤¾à¤¨ à¤¦à¥‡à¤‚:' : 'âš ï¸ Focus on these key weak topics:';
  static String get generalQuestionFallback => _isHi ? 'à¤¸à¤¾à¤®à¤¾à¤¨à¥à¤¯ à¤ªà¥à¤°à¤¶à¥à¤¨' : 'General Question';

  static bool get isPaper2 => ExamService.instance.isPaper2;
  static String get paperBadge => ExamService.instance.paperBadge;

  // Section Names (Pure Hindi vs Pure English)
  static String sectionName(String sec) =>
      SectionCatalog.name(sec, hindi: _isHi);

  // Paper Selector Strings
  /// The paper switcher always says the same thing, in every screen.
  static String get paper1Label =>
      _isHi ? '${paperName(1)} (à¤•à¤•à¥à¤·à¤¾ 1â€“5)' : '${paperName(1)} (Classes 1â€“5)';
  static String get paper2Label =>
      _isHi ? '${paperName(2)} (à¤•à¤•à¥à¤·à¤¾ 6â€“8)' : '${paperName(2)} (Classes 6â€“8)';
  static String get paper1Tab => 'ðŸ“˜ $paper1Label';
  static String get paper2Tab => 'ðŸ“™ $paper2Label';
  static String get paperSelectorHeader => _isHi ? 'à¤ªà¥‡à¤ªà¤° à¤šà¤¯à¤¨' : 'Select Paper';
  static String get paperSelectorDesc => _isHi
      ? '${paperName(1)} (à¤•à¤•à¥à¤·à¤¾ 1â€“5) à¤¯à¤¾ ${paperName(2)} (à¤•à¤•à¥à¤·à¤¾ 6â€“8) à¤šà¥à¤¨à¥‡à¤‚'
      : 'Choose ${paperName(1)} (Classes 1â€“5) or ${paperName(2)} (Classes 6â€“8)';

  // Gateway Cards on Home Booklets
  static String get gatewayPyqTitle => _isHi
      ? '$examPaperStreamLabel Â· à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤¸à¤‚à¤—à¥à¤°à¤¹'
      : '$examPaperStreamLabel Â· Previous Year Solved Papers';
  static String get gatewayPyqSub => _isHi
      ? 'à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤·à¥‹à¤‚ à¤•à¥‡ à¤¸à¤­à¥€ à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : 'All previous year board papers';
  static String get gatewayMocksTitle => _isHi
      ? '$examPaperStreamLabel Â· $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : '$examPaperStreamLabel Â· $currentExamYear Model Test Papers';
  static String get gatewayMocksSub => _isHi
      ? '${BankFacts.paperCount} à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : '${BankFacts.paperCount} complete authentic model test papers';

  // PYQ Section
  static String get pyqVaultTitle =>
      screenTitle('à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°', 'Previous Year Solved Papers');
  static String get pyqVaultSubtitle => _isCtet
      ? (_isHi
          ? 'à¤•à¥‡à¤¨à¥à¤¦à¥à¤°à¥€à¤¯ à¤¶à¤¿à¤•à¥à¤·à¤• à¤ªà¤¾à¤¤à¥à¤°à¤¤à¤¾ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ ($examName) à¤•à¥‡ à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
          : 'Previous year question papers of $examName')
      : (_isHi
          ? 'à¤‰à¤¤à¥à¤¤à¤°à¤¾à¤–à¤£à¥à¤¡ à¤¶à¤¿à¤•à¥à¤·à¤• à¤ªà¤¾à¤¤à¥à¤°à¤¤à¤¾ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ ($examName) à¤•à¥‡ à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
          : 'Previous year question papers of $examName');
  static String get pyqVaultBadge =>
      _isHi ? 'à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°' : 'Previous Year Solved Paper';
  static String pyqVaultCardTitle(String year) => _isHi
      ? '$examPaperStreamLabel Â· $year à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : '$examPaperStreamLabel Â· $year Previous Year Solved Paper';
  static String pyqVaultCardDesc(int count) => _isHi
      ? '$count à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤ªà¥‚à¤°à¥à¤µ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨ Â· ${BankFacts.subjectCount} à¤µà¤¿à¤·à¤¯'
      : '$count Authentic Questions Â· ${BankFacts.subjectCount} Subjects';
  static String get startPyqExamBtn => _isHi ? 'ðŸ“– à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤¹à¤² à¤•à¤°à¥‡à¤‚' : 'ðŸ“– Solve Paper';

  // Mock Series Screen
  static String get mockSeriesTitle => _isHi
      ? '$examPaperStreamLabel Â· $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : '$examPaperStreamLabel Â· $currentExamYear Model Test Papers';
  static String get mockSeriesSubtitle {
    final total = BankFacts.format(
      BankFacts.paperCount * BankFacts.questionsPerPaper,
    );
    return _isHi
        ? 'à¤®à¤¾à¤¨à¤• à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¥ˆà¤Ÿà¤°à¥à¤¨ à¤ªà¤° à¤†à¤§à¤¾à¤°à¤¿à¤¤ $total à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¥€ ${BankFacts.paperCount} à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤¶à¥ƒà¤‚à¤–à¤²à¤¾'
        : '$total-question series of ${BankFacts.paperCount} authentic model test papers curated on the standard exam pattern';
  }
  static String mockSeriesCardTitle(int num) => _isHi
      ? 'à¤¸à¥‡à¤Ÿ-${num.toString().padLeft(2, '0')} Â· $examPaperStreamLabel Â· $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : 'SET-${num.toString().padLeft(2, '0')} Â· $examPaperStreamLabel Â· $currentExamYear Model Test Paper';
  static String get mockSeriesCardDesc => _isHi
      ? '${BankFacts.questionsPerPaper} à¤¬à¤¹à¥à¤µà¤¿à¤•à¤²à¥à¤ªà¥€à¤¯ à¤ªà¥à¤°à¤¶à¥à¤¨ Â· ${BankFacts.questionsPerPaper} à¤®à¤¿à¤¨à¤Ÿ Â· à¤ªà¥‚à¤°à¥à¤£à¤¾à¤‚à¤• ${BankFacts.questionsPerPaper}'
      : '${BankFacts.questionsPerPaper} MCQs Â· ${BankFacts.questionsPerPaper} Minutes Â· ${BankFacts.questionsPerPaper} Marks';
  static String get freshMockGenerateBtn => _isHi
      ? 'âš¡ à¤¨à¤¯à¤¾ à¤…à¤¸à¥€à¤®à¤¿à¤¤ à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤¤à¥ˆà¤¯à¤¾à¤° à¤•à¤°à¥‡à¤‚'
      : 'âš¡ Generate Fresh Practice Mock';

  /// Formats paper titles with 100% pure language separation
  static String formatPaperTitle(Map<String, dynamic> form, {bool? isHindi}) {
    final isHi = isHindi ?? _isHi;
    final fid = (form['id'] as String? ?? '').toLowerCase();
    final exam = (form['exam'] as String? ?? (fid.contains('ctet') ? 'ctet' : 'utet')).toUpperCase();
    final paper = form['paper'] is int ? form['paper'] as int : (fid.contains('p2') ? 2 : 1);
    final setCode = (form['set_code']?.toString() ?? '').toUpperCase();
    final rawTitle = form['title']?.toString() ?? '';

    final paperStr = isHi ? 'à¤ªà¥‡à¤ªà¤°-$paper' : 'Paper-$paper';
    // The paper-2 stream belongs to the paper name, so a stream paper is
    // never mistaken for the other one.
    final streamTag = isHi
        ? (fid.contains('sst-mock')
            ? '(à¤¸à¤¾à¤®à¤¾à¤œà¤¿à¤• à¤…à¤§à¥à¤¯à¤¯à¤¨)'
            : '(à¤—à¤£à¤¿à¤¤ à¤à¤µà¤‚ à¤µà¤¿à¤œà¥à¤žà¤¾à¤¨)')
        : (fid.contains('sst-mock')
            ? '(Social Studies)'
            : '(Mathematics & Science)');

    // 1. UTET Paper 1 Fullmock Board Paper
    if (fid == 'utet-p1-fullmock') {
      return isHi
          ? '$exam $paperStr Â· 2023 à¤†à¤§à¤¿à¤•à¤¾à¤°à¤¿à¤• à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
          : '$exam $paperStr Â· 2023 Official Board Solved Paper';
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
          ? '$exam $paperStr Â· $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° $num'
          : '$exam $paperStr Â· $currentExamYear Model Test Paper $num';
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
          ? '$exam $paperStr Â· $year (à¤¸à¥‡à¤Ÿ-$setLetter) à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
          : '$exam $paperStr Â· $year (Set-$setLetter) Board Solved Paper';
    }

    // 4. CTET Paper 1 PYQs
    if (fid.startsWith('ctet-p1-') && fid.endsWith('-pyq')) {
      final yearM = RegExp(r'20\d\d').firstMatch(fid);
      final year = yearM?.group(0) ?? '$currentExamYear';
      return isHi
          ? '$exam $paperStr Â· $year à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
          : '$exam $paperStr Â· $year Previous Year Solved Paper';
    }

    // 5. CTET Paper 1 Mocks
    if (fid.startsWith('ctet-p1-mock-')) {
      final numM = RegExp(r'mock-(\d+)').firstMatch(fid) ?? RegExp(r'(\d+)').firstMatch(setCode);
      final num = numM != null ? numM.group(1)!.padLeft(2, '0') : '01';
      return isHi
          ? '$exam $paperStr Â· $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° $num'
          : '$exam $paperStr Â· $currentExamYear Model Test Paper $num';
    }

    // 6. CTET Paper 2 Math & Science Mocks
    if (fid.contains('ms-mock')) {
      final numM = RegExp(r'mock-(\d+)').firstMatch(fid) ?? RegExp(r'(\d+)').firstMatch(setCode);
      final num = numM != null ? numM.group(1)!.padLeft(2, '0') : '01';
      return isHi
          ? '$exam $paperStr Â· $streamTag Â· $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° $num'
          : '$exam $paperStr Â· $streamTag Â· $currentExamYear Model Test Paper $num';
    }

    // 7. CTET Paper 2 Social Studies Mocks
    if (fid.contains('sst-mock')) {
      final numM = RegExp(r'mock-(\d+)').firstMatch(fid) ?? RegExp(r'(\d+)').firstMatch(setCode);
      final num = numM != null ? numM.group(1)!.padLeft(2, '0') : '01';
      return isHi
          ? '$exam $paperStr Â· $streamTag Â· $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° $num'
          : '$exam $paperStr Â· $streamTag Â· $currentExamYear Model Test Paper $num';
    }

    // Fallback Translation for any custom or dynamic forms
    if (rawTitle.isEmpty) {
      return isHi
          ? '$exam $paperStr Â· à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
          : '$exam $paperStr Â· Practice Paper';
    }

    if (isHi) {
      return rawTitle
          .replaceAll(RegExp(r'Paper[- ]*I\b', caseSensitive: false), 'à¤ªà¥‡à¤ªà¤°-1')
          .replaceAll(RegExp(r'Paper[- ]*II\b', caseSensitive: false), 'à¤ªà¥‡à¤ªà¤°-2')
          .replaceAll(RegExp(r'Paper[- ]*1\b', caseSensitive: false), 'à¤ªà¥‡à¤ªà¤°-1')
          .replaceAll(RegExp(r'Paper[- ]*2\b', caseSensitive: false), 'à¤ªà¥‡à¤ªà¤°-2')
          .replaceAll(RegExp(r'Model Paper\b', caseSensitive: false), 'à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°')
          .replaceAll(RegExp(r'Model Booklet\b', caseSensitive: false), 'à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°')
          .replaceAll('à¤®à¥‰à¤¡à¤² à¤ªà¥‡à¤ªà¤°', 'à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°')
          .replaceAll('à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾', 'à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°')
          .replaceAll('à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥‡à¤ªà¤°', 'à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°')
          .replaceAll('à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥‡à¤ªà¤°', 'à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°')
          .replaceAll('Set-', 'à¤¸à¥‡à¤Ÿ-')
          .replaceAll('Set ', 'à¤¸à¥‡à¤Ÿ ');
    } else {
      return rawTitle
          .replaceAll('à¤†à¤§à¤¿à¤•à¤¾à¤°à¤¿à¤• à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°', 'Official Board Solved Paper')
          .replaceAll('à¤†à¤§à¤¿à¤•à¤¾à¤°à¤¿à¤• à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥‡à¤ªà¤°', 'Official Board Solved Paper')
          .replaceAll('à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°', 'Board Solved Paper')
          .replaceAll('à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥‡à¤ªà¤°', 'Board Solved Paper')
          .replaceAll('à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°', 'Previous Year Solved Paper')
          .replaceAll('à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥‡à¤ªà¤°', 'Previous Year Solved Paper')
          .replaceAll('à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°', 'Model Test Paper')
          .replaceAll('à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾', 'Model Test Paper')
          .replaceAll('à¤®à¥‰à¤¡à¤² à¤ªà¥‡à¤ªà¤°', 'Model Test Paper')
          .replaceAll('à¤®à¥‰à¤¡à¤² à¤ªà¥‡à¤ªà¤°', 'Model Test Paper')
          .replaceAll('à¤—à¤£à¤¿à¤¤ à¤à¤µà¤‚ à¤µà¤¿à¤œà¥à¤žà¤¾à¤¨', 'Mathematics & Science')
          .replaceAll('à¤¸à¤¾à¤®à¤¾à¤œà¤¿à¤• à¤…à¤§à¥à¤¯à¤¯à¤¨', 'Social Studies')
          .replaceAll('à¤ªà¥‡à¤ªà¤°-1', 'Paper-1')
          .replaceAll('à¤ªà¥‡à¤ªà¤°-2', 'Paper-2')
          .replaceAll('à¤¸à¥‡à¤Ÿ-', 'Set-')
          .replaceAll('à¤¸à¥‡à¤Ÿ ', 'Set ');
    }
  }

  /// Clean two-line stamp breakdown: top label and bottom number/letter
  static ({String top, String bottom}) getStampParts(String rawSet, {bool? isHindi}) {
    final isHi = isHindi ?? _isHi;
    final s = rawSet.trim().toUpperCase();

    // Year PYQ (e.g. '2023', '2021-C')
    if (RegExp(r'20\d\d').hasMatch(s)) {
      return (top: isHi ? 'à¤µà¤°à¥à¤·' : 'YEAR', bottom: s);
    }

    // Mock Test (e.g. 'MOCK 01', 'M-01')
    if (s.startsWith('MOCK') || s.startsWith('M-')) {
      final num = s.replaceAll(RegExp(r'[^0-9]'), '');
      return (top: isHi ? 'à¤®à¥‰à¤¡à¤²' : 'MOCK', bottom: num.isNotEmpty ? num : '01');
    }

    // Math & Science Stream (e.g. 'MS-01')
    if (s.startsWith('MS-') || s.startsWith('MS ')) {
      final num = s.replaceAll(RegExp(r'[^0-9]'), '');
      return (top: isHi ? 'à¤—à¤£à¤¿à¤¤-à¤µà¤¿.' : 'M&S', bottom: num.isNotEmpty ? num : '01');
    }

    // Social Studies Stream (e.g. 'SST-01')
    if (s.startsWith('SST-') || s.startsWith('SST ')) {
      final num = s.replaceAll(RegExp(r'[^0-9]'), '');
      return (top: isHi ? 'à¤¸à¤¾à¤®à¤¾à¤œà¤¿à¤•' : 'SST', bottom: num.isNotEmpty ? num : '01');
    }

    // Set A, B, C...
    if (s.startsWith('SET-') || s.startsWith('SET ')) {
      final rest = s.replaceAll(RegExp(r'^SET[- ]*'), '');
      return (top: isHi ? 'à¤¸à¥‡à¤Ÿ' : 'SET', bottom: rest);
    }

    // Generic
    return (top: isHi ? 'à¤ªà¥‡à¤ªà¤°' : 'PAPER', bottom: s);
  }

  /// Formats stamp badge text into single line (e.g. 'MOCK 01' -> 'à¤®à¥‰à¤¡à¤² 01')
  static String formatSetBadge(String rawSet, {bool? isHindi}) {
    final parts = getStampParts(rawSet, isHindi: isHindi);
    return '${parts.top} ${parts.bottom}';
  }

  // Paper-2 streams (Mathematics & Science / Social Studies)
  static String get streamSwitcherLabel =>
      _isHi ? 'à¤µà¤¿à¤·à¤¯ à¤µà¤°à¥à¤— (à¤–à¤‚à¤¡ IV)' : 'Subject Stream (Section IV)';
  static String get streamMathScience =>
      _isHi ? 'à¤—à¤£à¤¿à¤¤ à¤à¤µà¤‚ à¤µà¤¿à¤œà¥à¤žà¤¾à¤¨' : 'Mathematics & Science';
  static String get streamSocialStudies =>
      _isHi ? 'à¤¸à¤¾à¤®à¤¾à¤œà¤¿à¤• à¤…à¤§à¥à¤¯à¤¯à¤¨' : 'Social Studies';
  static String get streamBoth =>
      _isHi ? 'à¤¦à¥‹à¤¨à¥‹à¤‚ à¤µà¤¿à¤·à¤¯ à¤µà¤°à¥à¤—' : 'Both Streams';
  static String streamQuestions(int count) =>
      _isHi ? '$count à¤ªà¥à¤°à¤¶à¥à¤¨' : '$count Qs';
  static String get streamChanged =>
      _isHi ? 'à¤µà¤¿à¤·à¤¯ à¤µà¤°à¥à¤— à¤¬à¤¦à¤² à¤¦à¤¿à¤¯à¤¾ à¤—à¤¯à¤¾' : 'Subject stream changed';

  // â”€â”€ Screen titles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Every one of them names the exam, the paper and - for paper 2 - the
  // subject stream, so a candidate always knows what they are solving.

  /// Home Â· Booklets tab.
  static String get homeBookletsTitle =>
      screenTitle('à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾à¤à¤‚', 'Booklets');

  /// Home Â· Subjects tab.
  static String get homeSubjectsTitle =>
      screenTitle('à¤µà¤¿à¤·à¤¯ à¤…à¤­à¥à¤¯à¤¾à¤¸', 'Subject Practice');

  /// Home Â· History tab.
  static String get homeHistoryTitle => historyTitle;

  /// Home Â· Settings tab.
  static String get homeSettingsTitle => settingsTitle;

  /// The heading above the paper list on the home screen.
  static String paperListHeading(int count) => _isHi
      ? '$examPaperStreamLabel Â· $currentExamYear à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° ($count à¤¸à¥‡à¤Ÿ)'
      : '$examPaperStreamLabel Â· $currentExamYear Model Test Papers ($count Sets)';

  /// The CBT exam screen.
  static String get cbtExamTitle => screenTitle('CBT à¤ªà¤°à¥€à¤•à¥à¤·à¤¾', 'CBT Exam');

  /// The CBT exam screen, empty paper state.
  static String get examEmptyStateTitle => screenTitle('à¤ªà¤°à¥€à¤•à¥à¤·à¤¾', 'Exam');

  /// The reported questions screen.
  static String get reportedQuestionsTitle =>
      screenTitle('à¤°à¤¿à¤ªà¥‹à¤°à¥à¤Ÿ à¤•à¥€ à¤—à¤ˆ à¤ªà¥à¤°à¤¶à¥à¤¨', 'Reported Questions');

  static String get streamShortMathScience => _isHi ? 'à¤—à¤£à¤¿à¤¤-à¤µà¤¿à¤œà¥à¤žà¤¾à¤¨' : 'M&S';
  static String get streamShortSocialStudies => _isHi ? 'à¤¸à¤¾à¤®à¤¾à¤œà¤¿à¤•' : 'SST';

  static String papersCountDesc(int count, int size) => _isHi
      ? '$count à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° Â· à¤¹à¤° à¤à¤• à¤®à¥‡à¤‚ $size à¤ªà¥à¤°à¤¶à¥à¤¨'
      : '$count papers Â· $size questions each';

  static String get allPapersHeading =>
      _isHi ? '?? ???? ?? ??? ??????-????' : 'All Papers Of This Level';

  static String get examPaperLabel {
    final exam = _isCtet ? 'CTET' : 'UTET';
    return '$exam ${paperName(currentPaperNumber)}';
  }

  static String boardPaperSubtitle(int size) => _isHi
      ? '$size à¤ªà¥à¤°à¤¶à¥à¤¨ Â· $size à¤®à¤¿à¤¨à¤Ÿ Â· à¤¸à¤¤à¥à¤¯à¤¾à¤ªà¤¿à¤¤ à¤‰à¤¤à¥à¤¤à¤° à¤¸à¤¹à¤¿à¤¤ à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥‡à¤ªà¤°'
      : '$size questions Â· $size minutes Â· board paper with verified answers';

  static String resultTargetedHeadline(int needed) => _isHi
      ? 'à¤—à¤¹à¤¨ à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤•à¥€ à¤†à¤µà¤¶à¥à¤¯à¤•à¤¤à¤¾'
      : 'Targeted Revision Needed';
  static String resultTargetedAdvice(int needed) => _isHi
      ? 'à¤†à¤°à¤•à¥à¤·à¤¿à¤¤ à¤µà¤°à¥à¤— à¤•à¤Ÿ-à¤‘à¤« 55% à¤•à¥‡ à¤²à¤¿à¤ $needed à¤”à¤° à¤…à¤‚à¤• à¤†à¤µà¤¶à¥à¤¯à¤• à¤¹à¥ˆà¤‚à¥¤ à¤˜à¤¬à¤°à¤¾à¤à¤‚ à¤¨à¤¹à¥€à¤‚, à¤ªà¥‚à¤°à¥à¤µ à¤µà¤°à¥à¤· à¤•à¥‡ à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ (SET-R) à¤”à¤° à¤—à¤²à¤¤ à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¥‡ à¤ªà¥à¤¨à¤ƒ à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤¸à¥‡ à¤¸à¥à¤•à¥‹à¤° à¤¤à¥à¤°à¤‚à¤¤ à¤¬à¤¢à¤¼à¥‡à¤—à¤¾à¥¤'
      : 'You need $needed more marks for the reserved seat 55%. Do not worry - practising the previous year papers (SET-R) and the questions you got wrong will lift the score right away.';

  // ---- bilingual labels for the exam and the result screens --------------
  static String get reportLabel => _isHi ? 'à¤°à¤¿à¤ªà¥‹à¤°à¥à¤Ÿ' : 'Report';
  static String get answeredCountLabel => _isHi ? 'à¤¹à¤²: ' : 'Answered: ';
  static String get reviewCountLabel => _isHi ? 'à¤¸à¤®à¥€à¤•à¥à¤·à¤¾: ' : 'Review: ';
  static String get sectionLabel => _isHi ? 'à¤¸à¥‡à¤•à¥à¤¶à¤¨: ' : 'Section: ';
  static String get emptyPaperTitle => _isHi
      ? 'à¤‡à¤¸ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤®à¥‡à¤‚ à¤•à¥‹à¤ˆ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¨à¤¹à¥€à¤‚ à¤®à¤¿à¤²à¤¾à¥¤ à¤•à¥ƒà¤ªà¤¯à¤¾ à¤¦à¥‚à¤¸à¤°à¤¾ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤šà¥à¤¨à¥‡à¤‚à¥¤'
      : 'No questions were found in this paper. Please choose another paper.';
  static String get wrongTimesLabel => _isHi ? 'à¤¬à¤¾à¤° à¤—à¤²à¤¤' : 'wrong times';
  static String get directionLabel => _isHi ? 'à¤¨à¤¿à¤°à¥à¤¦à¥‡à¤¶ : ' : 'Direction: ';
  static String practiceSetsHeading(int count) => _isHi
      ? 'à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤¸à¥‡à¤Ÿà¥à¤¸ ($count à¤ªà¥à¤°à¤¶à¥à¤¨ Â· $count à¤®à¤¿à¤¨à¤Ÿ)'
      : 'Practice Sets ($count questions Â· $count minutes)';
  static String get rightDirectionAdvice => _isHi
      ? 'à¤¸à¤¹à¥€ à¤¦à¤¿à¤¶à¤¾ à¤®à¥‡à¤‚ à¤¸à¥à¤§à¤¾à¤°: à¤‡à¤¨ à¤Ÿà¥‰à¤ªà¤¿à¤•à¥à¤¸ à¤•à¥‡ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤°à¤Ÿà¤¨à¥‡ à¤•à¥‡ à¤¬à¤œà¤¾à¤¯ à¤ªà¤¹à¤²à¥‡ à¤‡à¤¨à¤•à¥‡ à¤¨à¤¿à¤¯à¤® à¤”à¤° à¤¬à¥à¤¨à¤¿à¤¯à¤¾à¤¦à¥€ à¤¸à¤¿à¤¦à¥à¤§à¤¾à¤‚à¤¤ à¤¸à¤®à¤à¥‡à¤‚à¥¤ à¤«à¤¿à¤° à¤¨à¥€à¤šà¥‡ à¤¦à¤¿à¤ à¤¬à¤Ÿà¤¨ à¤¸à¥‡ à¤¸à¤¿à¤°à¥à¤«à¤¼ à¤‡à¤¨à¥à¤¹à¥€à¤‚ à¤—à¤²à¤¤ à¤¹à¥à¤ à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¤¾ à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤•à¤°à¥‡à¤‚à¥¤'
      : 'The right way to improve: understand the rules and the basics of these topics instead of memorising them. Then use the button below to practise only the questions you got wrong.';
  static String retestWrongQuestions(int count) => _isHi
      ? 'ðŸŽ¯ à¤¬à¤¾à¤°-à¤¬à¤¾à¤° à¤—à¤²à¤¤ à¤¹à¥à¤ ($count) à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¤¾ à¤°à¥€-à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤¹à¤² à¤•à¤°à¥‡à¤‚'
      : 'ðŸŽ¯ Re-test the $count questions you keep getting wrong';

  static String exitExamMessage(int total, int answered) => _isHi
      ? 'à¤†à¤ªà¤¨à¥‡ $total à¤®à¥‡à¤‚ à¤¸à¥‡ $answered à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¹à¤² à¤•à¤¿à¤ à¤¹à¥ˆà¤‚à¥¤ à¤¯à¤¦à¤¿ à¤†à¤ª à¤…à¤­à¥€ à¤¬à¤¾à¤¹à¤° à¤œà¤¾à¤¤à¥‡ à¤¹à¥ˆà¤‚, à¤¤à¥‹ à¤†à¤ªà¤•à¤¾ à¤®à¥Œà¤œà¥‚à¤¦à¤¾ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤¸à¤¤à¥à¤° à¤¸à¤®à¤¾à¤ªà¥à¤¤ à¤¹à¥‹ à¤œà¤¾à¤à¤—à¤¾à¥¤'
      : 'You have answered $answered of $total questions. If you leave now, this test session will end.';
  static String get zoomLabel => _isHi ? 'à¤œà¤¼à¥‚à¤® à¤•à¤°à¥‡à¤‚' : 'Zoom';
  static String get pinchToZoomHint => _isHi
      ? 'à¤ªà¤¿à¤‚à¤š à¤•à¤°à¤•à¥‡ à¤¬à¤¡à¤¼à¤¾/à¤›à¥‹à¤Ÿà¤¾ à¤•à¤°à¥‡à¤‚ (Pinch to Zoom & Pan)'
      : 'Pinch to zoom and pan';
  static String questionNumberLabel(int number) =>
      _isHi ? 'à¤ªà¥à¤°à¤¶à¥à¤¨ $number' : 'Question $number';

  // ---- the pass plan (prices come from the store, these are the fallback)
  static String get proPackMostPopular => _isHi ? 'à¤¸à¤¬à¤¸à¥‡ à¤²à¥‹à¤•à¤ªà¥à¤°à¤¿à¤¯' : 'Most Popular';
  static String get proPackPerMonth => _isHi ? 'à¤¸à¤¿à¤°à¥à¤« â‚¹208 à¤ªà¥à¤°à¤¤à¤¿ à¤®à¤¾à¤¹' : 'Just â‚¹208 a month';
  static String get proPackValidYear => _isHi ? '365 à¤¦à¤¿à¤¨' : '365 days';
  static String get proPackValidDays => _isHi ? '60 à¤¦à¤¿à¤¨' : '60 days';
  static String get proPackAnchorValue => _isHi ? 'â‚¹4,999 à¤•à¥€ à¤•à¥€à¤®à¤¤' : 'Worth â‚¹4,999';
  static String get proPackGuarantee => _isHi
      ? '7 à¤¦à¤¿à¤¨ à¤®à¥‡à¤‚ à¤¬à¤¿à¤¨à¤¾ à¤¸à¤µà¤¾à¤² à¤•à¥à¤› à¤­à¥€ à¤¨à¤¹à¥€à¤‚ à¤ªà¤¸à¤‚à¤¦ à¤†à¤¯à¤¾ à¤¤à¥‹ à¤ªà¥‚à¤°à¤¾ à¤ªà¥ˆà¤¸à¤¾ à¤µà¤¾à¤ªà¤¸'
      : 'Full refund within 7 days, no questions asked';
  static String get proPackWhichExam => _isHi ? 'à¤†à¤ª à¤•à¥Œà¤¨-à¤¸à¤¾ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤¦à¥‡ à¤°à¤¹à¥‡ à¤¹à¥ˆà¤‚?' : 'Which exam are you preparing for?';
  static String get proPackBothExams => _isHi ? 'UTET + CTET (à¤¦à¥‹à¤¨à¥‹à¤‚)' : 'UTET + CTET (both)';
  static String get proPackOnlyUtet => _isHi ? 'à¤¸à¤¿à¤°à¥à¤« UTET' : 'UTET only';
  static String get proPackOnlyCtet => _isHi ? 'à¤¸à¤¿à¤°à¥à¤« CTET' : 'CTET only';
  static String get proPackFullTitle => _isHi
      ? 'à¤«à¥à¤² à¤à¤•à¥à¤¸à¥‡à¤¸ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸'
      : 'Full Access Pro Pass';
  static String get proPackFullSub => _isHi
      ? 'UTET + CTET, à¤ªà¥‡à¤ªà¤°-1 à¤”à¤° à¤ªà¥‡à¤ªà¤°-2, à¤¸à¤­à¥€ à¤®à¥‰à¤¡à¤² à¤à¤µà¤‚ à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥‡à¤ªà¤°, à¤²à¤¾à¤‡à¤µ à¤¬à¥ˆà¤‚à¤• à¤…à¤ªà¤¡à¥‡à¤Ÿ, 12 à¤®à¤¹à¥€à¤¨à¥‡'
      : 'UTET + CTET, Paper-1 and Paper-2, every mock and board paper, live bank updates, 12 months';
  static String get proPackExamTitle => _isHi
      ? 'à¤à¤• à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸'
      : 'One Exam Pro Pass';
  static String get proPackExamSub => _isHi
      ? 'à¤šà¥à¤¨à¥‡ à¤¹à¥à¤ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤•à¥‡ à¤¸à¤­à¥€ à¤®à¥‰à¤¡à¤² à¤à¤µà¤‚ à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥‡à¤ªà¤°, à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ à¤¹à¤² à¤à¤µà¤‚ à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£, 12 à¤®à¤¹à¥€à¤¨à¥‡'
      : 'Every mock and board paper of the chosen exam, full solutions and analysis, 12 months';
  static String get proPackSingleTitleNew => _isHi
      ? 'à¤¸à¤¿à¤‚à¤—à¤² à¤ªà¥‡à¤ªà¤° à¤ªà¥à¤°à¥‹ à¤ªà¥ˆà¤¸'
      : 'Single Paper Pro Pass';
  static String get proPackSingleSubNew => _isHi
      ? 'à¤šà¤¯à¤¨à¤¿à¤¤ à¤ªà¥‡à¤ªà¤° à¤•à¥‡ à¤¸à¤­à¥€ à¤ªà¥à¤°à¤¶à¥à¤¨, à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ à¤¹à¤² à¤à¤µà¤‚ à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£, 60 à¤¦à¤¿à¤¨'
      : 'All the questions of the chosen paper, full solutions and analysis, 60 days';
  static String get proPackFallbackNote => _isHi
      ? 'à¤¦à¥à¤•à¤¾à¤¨ à¤¸à¥‡ à¤œà¥à¤¡à¤¼ à¤¨à¤¹à¥€à¤‚ à¤ªà¤¾à¤, à¤¦à¤¿à¤–à¤¾à¤¯à¤¾ à¤—à¤¯à¤¾ à¤¸à¤¾à¤®à¤¾à¤¨à¥à¤¯ à¤®à¥‚à¤²à¥à¤¯ à¤¹à¥ˆ'
      : 'The store could not be reached, the usual price is shown';
  static String proPackExpirySoon(int days) => _isHi
      ? 'à¤†à¤ªà¤•à¤¾ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸ $days à¤¦à¤¿à¤¨ à¤®à¥‡à¤‚ à¤¸à¤®à¤¾à¤ªà¥à¤¤ à¤¹à¥‹ à¤°à¤¹à¤¾ à¤¹à¥ˆ - à¤…à¤­à¥€ à¤¨à¤µà¥€à¤¨à¥€à¤•à¤°à¤£ à¤•à¤°à¥‡à¤‚'
      : 'Your Pro Pass ends in $days days - renew now';
  static String proPackRenewsAt(String price) => _isHi
      ? 'à¤¨à¤µà¥€à¤¨à¥€à¤•à¤°à¤£ â‚¹$price à¤ªà¤°'
      : 'Renews at â‚¹$price';
  static String get proPackUnlockedBadge => _isHi ? 'à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸ à¤¸à¤•à¥à¤°à¤¿à¤¯' : 'Pro Pass Active';

  // ---- bilingual wording for the buttons and cards ------------------------
  static String get verifiedTestPapersHeading =>
      _isHi ? 'à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤¬à¤¨à¥‡-à¤¬à¤¨à¤¾à¤ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤ªà¥‡à¤ªà¤°à¥à¤¸' : 'Verified Ready-Made Test Papers';
  static String verifiedTestPapersDesc(int count, int size) => _isHi
      ? '$count à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ $size-à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤µà¤¾à¤²à¥‡ à¤®à¥‰à¤¡à¤² à¤ªà¥‡à¤ªà¤°à¥à¤¸ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¹à¥ˆà¤‚à¥¤'
      : '$count complete mock papers with $size questions each.';
  static String get freshSetButton => _isHi
      ? 'âš¡ à¤«à¥à¤°à¥‡à¤¶ 30-à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¸à¥‡à¤Ÿ à¤œà¤¨à¤°à¥‡à¤Ÿ à¤•à¤°à¥‡à¤‚'
      : 'âš¡ Generate a fresh 30-question set';
  static String get freshSetLocked => _isHi
      ? 'ðŸ”’ à¤«à¥à¤°à¥‡à¤¶ 30-à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¸à¥‡à¤Ÿ (à¤ªà¤¾à¤¸ à¤¸à¥‡ à¤…à¤¨à¤²à¥‰à¤• à¤•à¤°à¥‡à¤‚)'
      : 'ðŸ”’ Fresh 30-question set (unlock with the pass)';
  static String get buildingSet => _isHi ? 'à¤¸à¥‡à¤Ÿ à¤¬à¤¨ à¤°à¤¹à¤¾ à¤¹à¥ˆ...' : 'Building the set...';
  static String get unlockLabel => _isHi ? 'à¤…à¤¨à¤²à¥‰à¤•' : 'Unlock';
  static String get solveLabel => _isHi ? 'à¤¹à¤² à¤•à¤°à¥‡à¤‚' : 'Solve';
  static String get drillLabel => _isHi ? 'à¤¡à¥à¤°à¤¿à¤²' : 'Drill';
  static String get changeStreamLabel =>
      _isHi ? 'à¤¸à¥à¤Ÿà¥à¤°à¥€à¤® à¤¬à¤¦à¤²à¥‡à¤‚ â‡„' : 'Change stream â‡„';
  static String topicsCount(int count) =>
      _isHi ? '$count à¤µà¤¿à¤·à¤¯' : '$count topics';
  static String get resultPassedHeadline =>
      _isHi ? 'à¤¬à¤¹à¥à¤¤ à¤¬à¤¢à¤¼à¤¿à¤¯à¤¾! à¤†à¤ªà¤¨à¥‡ à¤ªà¤¾à¤¸ à¤•à¤° à¤²à¤¿à¤¯à¤¾' : 'Well done, you passed!';
  static String get resultPassedAdvice => _isHi
      ? 'à¤…à¤ªà¤¨à¥€ à¤—à¤¤à¤¿ à¤¬à¤¨à¤¾à¤ à¤°à¤–à¥‡à¤‚à¥¤ à¤•à¤®à¤œà¥‹à¤° à¤µà¤¿à¤·à¤¯à¥‹à¤‚ à¤•à¥‹ à¤¦à¥‹à¤¬à¤¾à¤°à¤¾ à¤ªà¤¢à¤¼à¥‡à¤‚ à¤¤à¤¾à¤•à¤¿ à¤¸à¥à¤•à¥‹à¤° à¤”à¤° à¤®à¤œà¤¬à¥‚à¤¤ à¤¹à¥‹à¥¤'
      : 'Keep the pace. Revise the weak sections once more to make the score even stronger.';
  static String get resultReservedHeadline => _isHi
      ? 'à¤†à¤ª à¤°à¤¿à¤œà¤¼à¤°à¥à¤µ à¤¸à¥€à¤Ÿ à¤•à¥‡ à¤¸à¤¾à¤¥ à¤ªà¤¾à¤¸ à¤¹à¥ˆà¤‚'
      : 'You passed on the reserved seat';
  static String resultReservedAdvice(int needed) => _isHi
      ? 'à¤¸à¤¾à¤®à¤¾à¤¨à¥à¤¯ à¤µà¤°à¥à¤— à¤ªà¤¾à¤° à¤•à¤°à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤•à¥‡à¤µà¤² $needed à¤”à¤° à¤…à¤‚à¤• à¤šà¤¾à¤¹à¤¿à¤à¥¤ à¤¨à¥€à¤šà¥‡ à¤¦à¤¿à¤ à¤•à¤®à¤œà¥‹à¤° à¤Ÿà¥‰à¤ªà¤¿à¤•à¥à¤¸ à¤•à¤¾ à¤ªà¥à¤¨à¤ƒ à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤•à¤°à¥‡à¤‚à¥¤'
      : 'You need only $needed more marks for the general seat. Revise the weak topics below.';
  static String mockPaperSubtitle(int size) => _isHi
      ? '$size à¤ªà¥à¤°à¤¶à¥à¤¨ Â· $size à¤®à¤¿à¤¨à¤Ÿ Â· à¤ªà¥‚à¤°à¥à¤£ à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤®à¥‰à¤•'
      : '$size questions Â· $size minutes Â· fully verified mock';

  // Subject Practice Hub
  static String subjectPracticeHubTitle(String sec) =>
      screenTitle('$sec à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤¹à¤¬', '$sec Practice Hub');
  static String subjectPracticeHubDesc(int total) => _isHi
      ? 'à¤¬à¥ˆà¤‚à¤• à¤®à¥‡à¤‚ à¤•à¥à¤² $total à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤ªà¥à¤°à¤¶à¥à¤¨ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¹à¥ˆà¤‚'
      : 'Total $total authentic questions available in bank';
  static String subjectSetTitle(int num) => _isHi
      ? 'à¤¸à¥‡à¤Ÿ-$num : ${BankFacts.subjectSetQuestions} à¤ªà¥à¤°à¤¶à¥à¤¨ à¤…à¤­à¥à¤¯à¤¾à¤¸'
      : 'Set-$num : ${BankFacts.subjectSetQuestions} Questions Practice';
  static String get topicsDrillHeading => _isHi ? 'à¤Ÿà¥‰à¤ªà¤¿à¤•-à¤µà¤¾à¤° à¤—à¤¹à¤¨ à¤…à¤­à¥à¤¯à¤¾à¤¸' : 'Topic-wise Focused Drills';
  static String get startPracticeBtn => _isHi ? 'à¤¹à¤² à¤¶à¥à¤°à¥‚ à¤•à¤°à¥‡à¤‚ â–¾' : 'Start Practice â–¾';
  static String topicDrillTitle(String topic) => _isHi ? '$topic à¤¡à¥à¤°à¤¿à¤²' : '$topic Drill';
  static String topicDrillSub(int count) => _isHi ? '$count à¤ªà¥à¤°à¤¶à¥à¤¨' : '$count Questions';
  static String get subjectCardSetsInfo =>
      _isHi ? 'à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤¸à¥‡à¤Ÿà¥à¤¸ Â· à¤Ÿà¥‰à¤ªà¤¿à¤• à¤¡à¥à¤°à¤¿à¤²' : 'Practice Sets Â· Topic Drills';

  /// The same line with the real number of sets the bank can offer.
  static String subjectCardSetsInfoFor(int sets) => _isHi
      ? '$sets à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤¸à¥‡à¤Ÿà¥à¤¸ Â· à¤Ÿà¥‰à¤ªà¤¿à¤• à¤¡à¥à¤°à¤¿à¤²'
      : '$sets Practice Sets Â· Topic Drills';

  // Premium & In-App Purchase Gate (IAP)
  static String get premiumPassTitle =>
      _isHi ? 'UTET à¤à¤µà¤‚ CTET $currentExamYear à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸' : 'UTET & CTET $currentExamYear Pro Pass';
  static String get premiumPassSubtitle => _isHi
      ? 'à¤à¤• à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤ªà¥‚à¤°à¥à¤£à¤¤à¤ƒ à¤¨à¤¿à¤ƒà¤¶à¥à¤²à¥à¤• à¤¹à¥ˆà¥¤ à¤¬à¤¾à¤•à¥€ à¤¸à¤­à¥€ ${BankFacts.paperCount}+ à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°, à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤”à¤° ${BankFacts.format(BankFacts.questionCount)}+ à¤ªà¥à¤°à¤¶à¥à¤¨ 12 à¤®à¤¹à¥€à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤…à¤¨à¤²à¥‰à¤• à¤•à¤°à¥‡à¤‚à¥¤'
      : 'One model test paper is completely free. Unlock all ${BankFacts.paperCount}+ model test papers, previous year solved papers, and ${BankFacts.format(BankFacts.questionCount)}+ questions for a full year.';

  static String get proPackMasterTitle => _isHi ? 'à¤®à¤¾à¤¸à¥à¤Ÿà¤° à¤‘à¤²-à¤à¤•à¥à¤¸à¥‡à¤¸ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸' : 'Master All-Access Pro Pass';
  static String get proPackMasterSub => _isHi
      ? 'à¤¦à¥‹à¤¨à¥‹à¤‚ à¤ªà¥‡à¤ªà¤° (à¤ªà¥‡à¤ªà¤°-1 + à¤ªà¥‡à¤ªà¤°-2), UTET à¤”à¤° CTET, à¤¸à¤­à¥€ ${BankFacts.paperCount}+ à¤Ÿà¥‡à¤¸à¥à¤Ÿ, ${BankFacts.format(BankFacts.questionCount)}+ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤µ 12 à¤®à¤¹à¥€à¤¨à¥‡ à¤•à¥‡ à¤…à¤ªà¤¡à¥‡à¤Ÿ'
      : 'Both papers (Paper-1 + Paper-2), UTET & CTET, all ${BankFacts.paperCount}+ full tests, ${BankFacts.format(BankFacts.questionCount)}+ questions & 12 months of updates';
  static String get proPackMasterPrice =>
      _isHi ? 'â‚¹599 (80% à¤¤à¤• à¤›à¥‚à¤Ÿ)' : 'â‚¹599 (Up to 80% Off)';
  static String get proPackMasterTag => _isHi ? 'â­ à¤¸à¤°à¥à¤µà¥‹à¤¤à¥à¤¤à¤® à¤®à¥‚à¤²à¥à¤¯ Â· à¤¶à¤¿à¤•à¥à¤·à¤•à¥‹à¤‚ à¤•à¥€ à¤ªà¤¸à¤‚à¤¦' : 'â­ Best Value Â· Most Popular';

  static String get proPackSingleTitle => _isHi ? 'à¤à¤•à¤² à¤ªà¥‡à¤ªà¤° à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸' : 'Single Paper Pro Pass';
  static String get proPackSingleSub => _isHi
      ? 'à¤šà¤¯à¤¨à¤¿à¤¤ à¤ªà¥‡à¤ªà¤° à¤•à¥‡ à¤¸à¤­à¥€ ${BankFacts.paperCount}+ à¤Ÿà¥‡à¤¸à¥à¤Ÿ, à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ à¤¸à¤®à¤¾à¤§à¤¾à¤¨ à¤à¤µà¤‚ à¤µà¤¿à¤¸à¥à¤¤à¥ƒà¤¤ à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£'
      : 'All ${BankFacts.paperCount}+ full tests, complete solutions & analytics for selected paper';
  static String get proPackSinglePrice => _isHi ? 'â‚¹399' : 'â‚¹399';
  static String get proPackSingleTag => _isHi ? 'à¤›à¤¾à¤¤à¥à¤° à¤ªà¥ˆà¤•' : 'Student Pack';

  static String get premiumFeature1 => _isHi
      ? '${BankFacts.paperCount}+ à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ ${BankFacts.questionsPerPaper}-à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¥‡ à¤®à¥‰à¤¡à¤² à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : '${BankFacts.paperCount}+ full ${BankFacts.questionsPerPaper}-question model test papers';
  static String get premiumFeature2 => _isHi
      ? 'à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤·à¥‹à¤‚ à¤•à¥‡ ${BankFacts.pyqCount}+ à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤¬à¥‹à¤°à¥à¤¡ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤°'
      : '${BankFacts.pyqCount}+ authentic previous year board papers';
  static String get premiumFeature3 => _isHi ? 'à¤µà¤¿à¤¸à¥à¤¤à¥ƒà¤¤ à¤µà¥à¤¯à¤¾à¤–à¥à¤¯à¤¾ à¤¸à¤¹à¤¿à¤¤ à¤¸à¤®à¥à¤ªà¥‚à¤°à¥à¤£ à¤¹à¤² à¤µ à¤¸à¤Ÿà¥€à¤• à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£' : 'Detailed Explanations & Performance Analytics';
  static String get premiumFeature4 => _isHi ? '100% à¤µà¤¿à¤œà¥à¤žà¤¾à¤ªà¤¨-à¤®à¥à¤•à¥à¤¤ Â· à¤¬à¤¿à¤¨à¤¾ à¤‡à¤‚à¤Ÿà¤°à¤¨à¥‡à¤Ÿ à¤ªà¥‚à¤°à¥à¤£ à¤à¤•à¥à¤¸à¥‡à¤¸' : '100% Ad-Free Â· Complete Offline Access';

  static String get premiumUnlockBtn => _isHi ? 'ðŸ‘‘ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸ à¤…à¤¨à¤²à¥‰à¤• à¤•à¤°à¥‡à¤‚' : 'ðŸ‘‘ Unlock Pro Pass';
  static String get premiumRestoreBtn => _isHi ? 'à¤–à¤°à¥€à¤¦ à¤ªà¥à¤¨à¤°à¥à¤¸à¥à¤¥à¤¾à¤ªà¤¿à¤¤ à¤•à¤°à¥‡à¤‚' : 'Restore Purchases';
  static String get premiumCloseBtn => _isHi ? 'à¤¬à¤‚à¤¦ à¤•à¤°à¥‡à¤‚' : 'Close';
  static String get premiumFreeBadge => _isHi ? 'à¤¨à¤¿à¤ƒà¤¶à¥à¤²à¥à¤•' : 'FREE';
  static String get premiumLockedBadge => _isHi ? 'ðŸ”’ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸' : 'ðŸ”’ Pro Pass';
  static String get premiumSuccessToast => _isHi
      ? 'ðŸŽ‰ à¤¬à¤§à¤¾à¤ˆ! à¤‘à¤²-à¤à¤•à¥à¤¸à¥‡à¤¸ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸ à¤¸à¤«à¤²à¤¤à¤¾à¤ªà¥‚à¤°à¥à¤µà¤• à¤…à¤¨à¤²à¥‰à¤• à¤¹à¥‹ à¤—à¤¯à¤¾à¥¤'
      : 'ðŸŽ‰ Congratulations! All-Access Pro Pass unlocked successfully.';
  static String get premiumActiveStatus => _isHi ? 'ðŸ‘‘ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸ à¤¸à¤•à¥à¤°à¤¿à¤¯' : 'ðŸ‘‘ Pro Pass Active';
  static String get premiumPriceBadge => _isHi ? 'ðŸ‘‘ à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸ à¤‰à¤ªà¤²à¤¬à¥à¤§ Â· â‚¹399 à¤¸à¥‡ à¤¶à¥à¤°à¥‚' : 'ðŸ‘‘ Pro Pass Available Â· From â‚¹399';
  static String get premiumCancelledToast => _isHi ? 'à¤­à¥à¤—à¤¤à¤¾à¤¨ à¤°à¤¦à¥à¤¦ à¤•à¤° à¤¦à¤¿à¤¯à¤¾ à¤—à¤¯à¤¾à¥¤' : 'Payment was cancelled.';
  static String get premiumErrorToast => _isHi ? 'à¤­à¥à¤—à¤¤à¤¾à¤¨ à¤ªà¥‚à¤°à¤¾ à¤¨à¤¹à¥€à¤‚ à¤¹à¥‹ à¤¸à¤•à¤¾à¥¤ à¤•à¥ƒà¤ªà¤¯à¤¾ à¤ªà¥à¤¨à¤ƒ à¤ªà¥à¤°à¤¯à¤¾à¤¸ à¤•à¤°à¥‡à¤‚à¥¤' : 'Payment could not be completed. Please try again.';
  static String get premiumPendingToast => _isHi ? 'à¤­à¥à¤—à¤¤à¤¾à¤¨ à¤ªà¥à¤°à¤•à¥à¤°à¤¿à¤¯à¤¾ à¤®à¥‡à¤‚ à¤¹à¥ˆà¥¤ à¤ªà¥à¤·à¥à¤Ÿà¤¿ à¤¹à¥‹à¤¤à¥‡ à¤¹à¥€ à¤ªà¤¾à¤¸ à¤¸à¤•à¥à¤°à¤¿à¤¯ à¤¹à¥‹ à¤œà¤¾à¤à¤—à¤¾à¥¤' : 'Payment is pending. Your pass will be activated upon confirmation.';
  static String get premiumNoPurchasesFound => _isHi ? 'à¤•à¥‹à¤ˆ à¤ªà¥‚à¤°à¥à¤µ à¤–à¤°à¥€à¤¦ à¤¨à¤¹à¥€à¤‚ à¤®à¤¿à¤²à¥€à¥¤' : 'No previous purchases found.';

  // Congratulations Dialog
  static String get congratulationsTitle => _isHi ? 'à¤¬à¤§à¤¾à¤ˆ à¤¹à¥‹! à¤ªà¥à¤°à¥‹ à¤ªà¤¾à¤¸ à¤¸à¤•à¥à¤°à¤¿à¤¯ à¤¹à¥‹ à¤—à¤¯à¤¾' : 'Congratulations! Pro Pass Activated';
  static String get congratulationsSub => _isHi
      ? 'à¤†à¤ªà¤•à¥€ à¤ªà¥à¤°à¥‹ à¤¸à¤¦à¤¸à¥à¤¯à¤¤à¤¾ à¤¸à¤«à¤²à¤¤à¤¾à¤ªà¥‚à¤°à¥à¤µà¤• à¤¸à¤•à¥à¤°à¤¿à¤¯ à¤•à¤° à¤¦à¥€ à¤—à¤ˆ à¤¹à¥ˆà¥¤ à¤…à¤¬ à¤†à¤ª à¤¸à¤­à¥€ ${BankFacts.paperCount}+ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾à¤“à¤‚ à¤”à¤° à¤µà¤¿à¤—à¤¤ à¤µà¤°à¥à¤· à¤ªà¥‡à¤ªà¤°à¥à¤¸ à¤•à¥‹ à¤¬à¤¿à¤¨à¤¾ à¤•à¤¿à¤¸à¥€ à¤°à¥‹à¤•-à¤Ÿà¥‹à¤• à¤•à¥‡ à¤¹à¤² à¤•à¤° à¤¸à¤•à¤¤à¥‡ à¤¹à¥ˆà¤‚à¥¤'
      : 'Your Pro membership is now active. You have full unlimited access to all ${BankFacts.paperCount}+ exam booklets and previous year papers.';
  static String get startPreparingBtn => _isHi ? 'à¤¤à¥ˆà¤¯à¤¾à¤°à¥€ à¤¶à¥à¤°à¥‚ à¤•à¤°à¥‡à¤‚' : 'Start Preparing';

  // Sanskrit Upcoming Notice
  static String get sanskritUpcomingTitle => _isHi ? 'à¤¸à¤‚à¤¸à¥à¤•à¥ƒà¤¤ à¤­à¤¾à¤·à¤¾ à¤œà¤²à¥à¤¦ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¹à¥‹à¤—à¥€' : 'Sanskrit Language Coming Soon';
  static String get sanskritUpcomingDesc => _isHi
      ? 'à¤¹à¤®à¤¾à¤°à¥€ à¤µà¤¿à¤·à¤¯ à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž à¤Ÿà¥€à¤® à¤†à¤—à¤¾à¤®à¥€ à¤…à¤ªà¤¡à¥‡à¤Ÿ à¤®à¥‡à¤‚ à¤¸à¤‚à¤¸à¥à¤•à¥ƒà¤¤ à¤­à¤¾à¤·à¤¾ à¤¦à¥à¤µà¤¿à¤¤à¥€à¤¯ à¤•à¥‡ à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¤¤à¥à¤° à¤œà¥‹à¤¡à¤¼ à¤°à¤¹à¥€ à¤¹à¥ˆà¥¤ à¤•à¥ƒà¤ªà¤¯à¤¾ à¤†à¤—à¤¾à¤®à¥€ à¤à¤ª à¤…à¤ªà¤¡à¥‡à¤Ÿ à¤•à¥€ à¤ªà¥à¤°à¤¤à¥€à¤•à¥à¤·à¤¾ à¤•à¤°à¥‡à¤‚à¥¤'
      : 'Our subject experts are curating authentic Sanskrit Language II question sets for the upcoming update. Please look forward to the next app update.';
  static String get understoodBtn => _isHi ? 'à¤¸à¤®à¤ à¤—à¤¯à¤¾' : 'Understood';

  // In-App Update (IAU)
  static String get updateAvailableTitle => _isHi ? 'à¤¨à¤¯à¤¾ à¤à¤ª à¤…à¤ªà¤¡à¥‡à¤Ÿ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¹à¥ˆ!' : 'New App Update Available!';
  static String get updateAvailableDesc => _isHi
      ? 'à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤¤à¥ˆà¤¯à¤¾à¤°à¥€ à¤•à¥‡ à¤²à¤¿à¤ à¤¨à¤µà¥€à¤¨à¤¤à¤® à¤ªà¥à¤°à¤¶à¥à¤¨ à¤”à¤° à¤¸à¥à¤§à¤¾à¤° à¤œà¥‹à¤¡à¤¼à¥‡ à¤—à¤ à¤¹à¥ˆà¤‚à¥¤'
      : 'Latest exam questions and enhancements have been added.';
  static String get updateNowBtn => _isHi ? 'à¤…à¤­à¥€ à¤…à¤ªà¤¡à¥‡à¤Ÿ à¤•à¤°à¥‡à¤‚' : 'Update Now';
  static String get updateLaterBtn => _isHi ? 'à¤¬à¤¾à¤¦ à¤®à¥‡à¤‚' : 'Later';
  static String get checkUpdateBtn => _isHi ? 'à¤à¤ª à¤…à¤ªà¤¡à¥‡à¤Ÿ à¤•à¥€ à¤œà¤¾à¤à¤š à¤•à¤°à¥‡à¤‚' : 'Check for Updates';
  static String get checkingUpdate => _isHi ? 'à¤œà¤¾à¤à¤š à¤¹à¥‹ à¤°à¤¹à¥€ à¤¹à¥ˆ...' : 'Checking for updates...';
  static String get appUpToDate => _isHi ? 'à¤†à¤ªà¤•à¤¾ à¤à¤ª à¤¨à¤µà¥€à¤¨à¤¤à¤® à¤¸à¤‚à¤¸à¥à¤•à¤°à¤£ à¤ªà¤° à¤¹à¥ˆà¥¤' : 'Your app is up to date.';
  static String get updateFound => _isHi ? 'à¤¨à¤¯à¤¾ à¤¸à¤‚à¤¸à¥à¤•à¤°à¤£ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¹à¥ˆ!' : 'New update available!';

  // In-App Review (IAR)
  static String get reviewPromptTitle => _isHi ? 'à¤•à¥à¤¯à¤¾ à¤†à¤ªà¤•à¥‹ à¤¹à¤®à¤¾à¤°à¥€ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾à¤à¤‚ à¤ªà¤¸à¤‚à¤¦ à¤†à¤ˆà¤‚?' : 'Loving our Exam Booklets?';
  static String get reviewPromptDesc => _isHi
      ? 'à¤†à¤ªà¤•à¤¾ 5-à¤¸à¥à¤Ÿà¤¾à¤° à¤°à¤¿à¤µà¥à¤¯à¥‚ à¤¹à¤®à¥‡à¤‚ à¤”à¤° à¤¬à¥‡à¤¹à¤¤à¤° à¤ªà¥à¤°à¤¾à¤®à¤¾à¤£à¤¿à¤• à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¤à¥ˆà¤¯à¤¾à¤° à¤•à¤°à¤¨à¥‡ à¤®à¥‡à¤‚ à¤®à¤¦à¤¦ à¤•à¤°à¤¤à¤¾ à¤¹à¥ˆà¥¤'
      : 'Your 5-star review helps us curate even better authentic questions.';
  static String get rateOnPlayStoreBtn => _isHi ? 'â­ Play Store à¤ªà¤° à¤°à¥‡à¤Ÿ à¤•à¤°à¥‡à¤‚' : 'â­ Rate on Play Store';

  // Settings & Navigation Labels
  static String get targetExamHeading => _isHi ? 'à¤²à¤•à¥à¤·à¤¿à¤¤ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾' : 'Target Examination';
  static String get examLevelHeading => _isHi ? 'à¤ªà¥‡à¤ªà¤° à¤¸à¥à¤¤à¤°' : 'Paper Level';
  static String get streamHeading =>
      _isHi ? 'à¤µà¤¿à¤·à¤¯ à¤µà¤°à¥à¤— (à¤–à¤‚à¤¡ IV)' : 'Subject Stream (Section IV)';
  static String get myReportsTooltip =>
      _isHi ? 'à¤°à¤¿à¤ªà¥‹à¤°à¥à¤Ÿ à¤•à¥€ à¤—à¤ˆ à¤ªà¥à¤°à¤¶à¥à¤¨' : 'Reported Questions';
  static String get langCardTitle => _isHi ? 'à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤­à¤¾à¤·à¤¾ à¤šà¤¯à¤¨' : 'Exam Language Selection';
  static String get langCardSubtitle => _isHi ? 'à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤¨à¤¿à¤¯à¤®à¤¾à¤¨à¥à¤¸à¤¾à¤° à¤…à¤ªà¤¨à¥€ à¤­à¤¾à¤·à¤¾ I à¤”à¤° à¤­à¤¾à¤·à¤¾ II à¤šà¥à¤¨à¥‡à¤‚' : 'Select your Language I & Language II per exam pattern';
  static String get lang1Heading => _isHi
      ? 'à¤­à¤¾à¤·à¤¾ à¤ªà¥à¤°à¤¥à¤® â€” $languageSectionQuestions à¤ªà¥à¤°à¤¶à¥à¤¨'
      : 'Language I â€” $languageSectionQuestions Questions';
  static String get lang2Heading => _isHi
      ? 'à¤­à¤¾à¤·à¤¾ à¤¦à¥à¤µà¤¿à¤¤à¥€à¤¯ â€” $languageSectionQuestions à¤ªà¥à¤°à¤¶à¥à¤¨'
      : 'Language II â€” $languageSectionQuestions Questions';
  static String get langHindiLabel => _isHi ? 'à¤¹à¤¿à¤¨à¥à¤¦à¥€' : 'Hindi';
  static String get langEnglishLabel => _isHi ? 'à¤…à¤‚à¤—à¥à¤°à¥‡à¤œà¥€' : 'English';
  static String get langSanskritLabel => _isHi ? 'à¤¸à¤‚à¤¸à¥à¤•à¥ƒà¤¤' : 'Sanskrit';
  static String get langNotice => _isHi ? 'à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤¨à¤¿à¤¯à¤®à¤¾à¤¨à¥à¤¸à¤¾à¤° à¤­à¤¾à¤·à¤¾ I à¤”à¤° à¤­à¤¾à¤·à¤¾ II à¤…à¤²à¤—-à¤…à¤²à¤— à¤¹à¥‹à¤¨à¥€ à¤…à¤¨à¤¿à¤µà¤¾à¤°à¥à¤¯ à¤¹à¥ˆà¤‚à¥¤' : 'Per exam guidelines, Language I and Language II must be different.';

  // Question Report Sheet
  static String get reportSheetTitle =>
      _isHi ? 'à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¤° à¤†à¤ªà¤¤à¥à¤¤à¤¿ / à¤¸à¥à¤§à¤¾à¤° à¤•à¥€ à¤°à¤¿à¤ªà¥‹à¤°à¥à¤Ÿ' : 'Report an Issue or Correction';
  static String get reportWrongAnswer => _isHi ? 'à¤‰à¤¤à¥à¤¤à¤° à¤—à¤²à¤¤ à¤¹à¥ˆ' : 'Wrong Answer Key';
  static String get reportIncompleteQuestion => _isHi ? 'à¤…à¤§à¥‚à¤°à¤¾ à¤¯à¤¾ à¤…à¤¸à¥à¤ªà¤·à¥à¤Ÿ à¤ªà¥à¤°à¤¶à¥à¤¨' : 'Incomplete or Unclear Question';
  static String get reportTypo => _isHi ? 'à¤Ÿà¤¾à¤‡à¤ªà¤¿à¤‚à¤— à¤¯à¤¾ à¤µà¤°à¥à¤¤à¤¨à¥€ à¤•à¥€ à¤…à¤¶à¥à¤¦à¥à¤§à¤¿' : 'Typo or Spelling Mistake';
  static String get reportOther => _isHi ? 'à¤…à¤¨à¥à¤¯ à¤¸à¤®à¤¸à¥à¤¯à¤¾' : 'Other Issue';
  static String get reportSolved => _isHi ? 'à¤¹à¤² à¤¹à¥‹ à¤—à¤¯à¤¾' : 'Solved';
  static String get reportPending => _isHi ? 'à¤¸à¤®à¥€à¤•à¥à¤·à¤¾ à¤œà¤¾à¤°à¥€ à¤¹à¥ˆ' : 'Under Review';
  static String get reportSubmitBtn => _isHi ? 'à¤°à¤¿à¤ªà¥‹à¤°à¥à¤Ÿ à¤¦à¤°à¥à¤œ à¤•à¤°à¥‡à¤‚' : 'Submit Report';
  static String get reportSubmittedSuccess => _isHi ? 'à¤†à¤ªà¤•à¥€ à¤°à¤¿à¤ªà¥‹à¤°à¥à¤Ÿ à¤¦à¤°à¥à¤œ à¤•à¤° à¤²à¥€ à¤—à¤ˆ à¤¹à¥ˆà¥¤ à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦!' : 'Your report has been submitted. Thank you!';

  // CBT & Solution Extra Tokens
  static String get questionPaletteTitle => _isHi ? 'à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¥ˆà¤²à¥‡à¤Ÿ' : 'Question Palette';
  static String get selectLangTitle => _isHi ? 'à¤­à¤¾à¤·à¤¾ à¤šà¥à¤¨à¥‡à¤‚' : 'Select Language';
  static String get recurringWeaknesses => _isHi ? 'à¤¬à¤¾à¤°-à¤¬à¤¾à¤° à¤¹à¥‹à¤¨à¥‡ à¤µà¤¾à¤²à¥€ à¤—à¤²à¤¤à¤¿à¤¯à¤¾à¤' : 'Recurring Weaknesses';
  static String get targetedRevisionNeed => _isHi ? 'à¤—à¤¹à¤¨ à¤…à¤­à¥à¤¯à¤¾à¤¸ à¤•à¥€ à¤†à¤µà¤¶à¥à¤¯à¤•à¤¤à¤¾' : 'Targeted Revision Needed';

  // Math & Diagrams
  static String get tapToZoom => _isHi ? 'à¤¬à¤¡à¤¼à¤¾ à¤¦à¥‡à¤–à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤Ÿà¥ˆà¤ª à¤•à¤°à¥‡à¤‚' : 'Tap to Zoom';
  static String get diagramLabel => _isHi ? 'à¤šà¤¿à¤¤à¥à¤°' : 'Diagram';
  static String get numberLineLabel => _isHi ? 'à¤¸à¤‚à¤–à¥à¤¯à¤¾ à¤°à¥‡à¤–à¤¾' : 'Number Line';
  static String get prismLabel => _isHi ? 'à¤¤à¥à¤°à¤¿à¤­à¥à¤œà¤¾à¤•à¤¾à¤° à¤ªà¥à¤°à¤¿à¤œà¥à¤®' : 'Triangular Prism';
  static String get shadedRegionLabel => _isHi ? 'à¤›à¤¾à¤¯à¤¾à¤‚à¤•à¤¿à¤¤ à¤­à¤¾à¤—' : 'Shaded Region';

  // Test Mode Settings
  static String get testModeHeader => _isHi ? 'à¤¡à¤¿à¤«à¤¼à¥‰à¤²à¥à¤Ÿ à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤®à¥‹à¤¡' : 'Default Test Mode';
  static String get testModeDesc => _isHi
      ? 'à¤Ÿà¥‡à¤¸à¥à¤Ÿ à¤¹à¤² à¤•à¤°à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤…à¤ªà¤¨à¤¾ à¤ªà¤¸à¤‚à¤¦à¥€à¤¦à¤¾ à¤®à¥‹à¤¡ à¤šà¥à¤¨à¥‡à¤‚'
      : 'Choose your preferred interface for solving tests';
  static String get cbtModeTitle => _isHi ? 'ðŸ“± CBT à¤®à¥‹à¤¡ (1 à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¥à¤°à¤¤à¤¿ à¤¸à¥à¤•à¥à¤°à¥€à¤¨)' : 'ðŸ“± CBT Mode (1 Question per Screen)';
  static String get cbtModeSub => _isHi
      ? 'à¤•à¤®à¥à¤ªà¥à¤¯à¥‚à¤Ÿà¤° à¤Ÿà¥‡à¤¸à¥à¤Ÿ Â· à¤¬à¤¡à¤¼à¤¾ à¤¸à¤¾à¤«à¤¼ à¤«à¥‰à¤¨à¥à¤Ÿ Â· à¤ªà¥‚à¤°à¥à¤£ à¤¸à¥à¤•à¥à¤°à¥€à¤¨ Â· à¤†à¤à¤–à¥‹à¤‚ à¤•à¥‡ à¤²à¤¿à¤ à¤¸à¥à¤—à¤®'
      : 'Computer test Â· Large clear font Â· Full screen Â· Easy on the eyes';
  static String get bookletModeTitle => _isHi ? 'ðŸ“„ à¤ªà¥à¤°à¤¶à¥à¤¨-à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤®à¥‹à¤¡' : 'ðŸ“„ Question Booklet';
  static String get bookletModeSub => _isHi
      ? 'à¤®à¤¾à¤¨à¤• à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤ªà¥‡à¤ªà¤° Â· ${BankFacts.questionsPerPaper} à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¸à¥‚à¤šà¥€ Â· OMR à¤¶à¥€à¤Ÿ à¤¶à¥ˆà¤²à¥€'
      : 'Standard exam paper Â· ${BankFacts.questionsPerPaper} questions list Â· OMR sheet style';
}


