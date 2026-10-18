import '../services/language_service.dart';
import '../services/exam_service.dart';

class AppStrings {
  static bool get _isHi => LanguageService.instance.isHindi;
  static bool get isHindi => _isHi;
  static bool get _isCtet => ExamService.instance.isCtet;
  static int get currentExamYear => DateTime.now().year;

  // App Header
  static String get appTitle => _isHi ? 'शिक्षक पात्रता परीक्षा' : 'Teacher Eligibility Test';
  static String get appSubtitle => _isCtet
      ? (_isHi ? 'CTET $currentExamYear डिजिटल प्रश्न-पुस्तिका' : 'CTET $currentExamYear Digital Booklet Portal')
      : (_isHi ? 'UTET $currentExamYear डिजिटल प्रश्न-पुस्तिका' : 'UTET $currentExamYear Digital Booklet Portal');
  static String get bankSyncTooltip => _isHi ? 'बैंक अपडेट करें' : 'Update Bank Online';
  static String get langToggleLabel => _isHi ? 'ENG' : 'हिन्दी';

  // Bank Strip
  static String get offlineBankTitle => _isHi ? 'ऑफलाइन बैंक' : 'Offline Bank';
  static String get offlineBadge => '100% Offline';
  static String bankInfo(int total, int pyq, int subjects) => _isHi
      ? '$total कुल प्रश्न · $pyq विगत वर्ष (PYQ) · $subjects विषय'
      : '$total Total Questions · $pyq Previous Papers · $subjects Subjects';

  // Splash Screen
  static String get splashTitle => _isHi ? 'शिक्षक पात्रता परीक्षा' : 'Teacher Eligibility Test';
  static String get splashSubtitle => _isHi
      ? 'UTET एवं CTET डिजिटल प्रश्न-पुस्तिका एवं परीक्षा विश्लेषण पोर्टल'
      : 'UTET & CTET Digital Question Booklet & Exam Analysis Portal';
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
  static String get heroTitle => _isCtet
      ? (_isHi ? 'CTET $currentExamYear मुख्य मॉडल प्रश्न-पुस्तिका' : 'CTET $currentExamYear Master Model Booklet')
      : (_isHi ? 'UTET $currentExamYear मुख्य मॉडल प्रश्न-पुस्तिका' : 'UTET $currentExamYear Master Model Booklet');
  static String get heroDesc => _isCtet
      ? (_isHi
          ? 'CBSE पाठ्यक्रम पर आधारित सम्पूर्ण 150 प्रश्नों का प्रामाणिक मॉडल पेपर।'
          : 'Complete 150-question mock paper based on CBSE pattern.')
      : (_isHi
          ? 'उत्तराखण्ड परीक्षा पैटर्न पर आधारित सम्पूर्ण 150 प्रश्नों का प्रामाणिक मॉडल पेपर।'
          : 'Complete 150-question authentic model paper based on Uttarakhand pattern.');
  static String get heroTotalQuestions => _isHi ? '150 बहुविकल्पीय प्रश्न' : '150 MCQs';
  static String get heroTime => _isHi ? 'समय : 2:30 घण्टे' : 'Time : 2:30 Hrs';
  static String get heroMarks => _isHi ? 'पूर्णांक : 150 अंक' : 'Marks : 150';
  static String get heroBtn => _isHi
      ? '📖 प्रश्न-पुस्तिका हल करें'
      : '📖 Open & Solve Booklet';

  // Booklet Sets
  static String get completeBookletsHeading => _isHi
      ? 'सम्पूर्ण प्रश्न-पुस्तिकाएं (150 प्रश्न · 150 मिनट)'
      : 'Complete Exam Booklets (150 Qs · 150 Mins)';

  static String get setQTitle => _isHi ? 'SET-Q : बार-बार आने वाले PYQ' : 'SET-Q : Frequently Repeated PYQs';
  static String get setQSub => _isHi ? '2+ वर्ष चक्रीय व सर्वाधिक पूछे गए प्रश्न (Hit Rate 98%)' : '2+ Years Recurring & High-Yield Questions (Hit Rate 98%)';
  static String get setQTag => _isHi ? '🔥 उच्च दोहराव' : '🔥 High Recurrence';

  static String get setRTitle => _isHi ? 'SET-R : केवल पूर्व वर्ष प्रश्न (PYQ)' : 'SET-R : Past Year Questions (PYQs)';
  static String setRSub(int pyqCount, String years) => _isHi
      ? '$pyqCount प्रामाणिक ${_isCtet ? "CTET" : "UTET"} प्रश्न बैंक ($years)'
      : '$pyqCount Authentic ${_isCtet ? "CTET" : "UTET"} Questions ($years)';
  static String get setRTag => _isHi ? '📜 100% PYQ' : '📜 100% PYQ';

  static String get setSTitle => _isHi ? 'SET-S : नवीन संभावित प्रश्न' : 'SET-S : Fresh Potential Questions';
  static String get setSSub => _isHi ? 'नए शिक्षणशास्त्र व सैद्धांतिक केस प्रश्न' : 'New pedagogy & conceptual case questions';
  static String get setSTag => _isHi ? '✨ फ्रेश अभ्यास' : '✨ Fresh Practice';

  static String get setTTitle => _isHi ? 'SET-T : सम्पूर्ण मिश्रित परीक्षा' : 'SET-T : Complete Balanced Mock Test';
  static String get setTSub => _isHi ? 'मानक परीक्षा पैटर्न अनुरूप संतुलित ब्लूप्रिंट' : 'Standard exam pattern balanced blueprint';
  static String get setTTag => _isHi ? '⚖️ संतुलित' : '⚖️ Balanced';

  // Subject Booklets
  static String get subjectBookletsHeading => _isHi
      ? 'खण्ड-वार अभ्यास पुस्तिकाएं (30 प्रश्न · 30 मिनट)'
      : 'Subject-wise Mini Booklets (30 Qs · 30 Mins)';

  static String get pastHistoryHeading => _isHi ? 'पिछले टेस्ट परिणाम' : 'Past Test History';
  static String get doubleBackExit => _isHi ? 'ऐप बंद करने के लिए दोबारा बैक दबाएं' : 'Press back again to exit app';

  // Navigation Bar
  static String get navBooklets => _isHi ? 'प्रश्न-पुस्तिका' : 'Booklets';
  static String get navSubjects => _isHi ? 'विषय अभ्यास' : 'Subjects';
  static String get navHistory => _isHi ? 'इतिहास' : 'History';
  static String get navSettings => _isHi ? 'सेटिंग्स' : 'Settings';

  // Subject Practice Portal
  static String get subjectPracticeHeading => _isHi ? 'खण्ड-वार अभ्यास पुस्तिकाएं' : 'Subject-wise Practice Booklets';
  static String get subjectPracticeDesc => _isHi
      ? 'प्रत्येक विषय में 30 प्रामाणिक प्रश्न और 30 मिनट का समय'
      : '30 authentic questions & 30 minutes for each subject';
  static String get subjectCardTime => _isHi ? '30 प्रश्न · 30 मिनट' : '30 Qs · 30 Mins';
  static String get startSubjectTestBtn => _isHi ? 'हल शुरू करें ▾' : 'Start Practice ▾';

  // Test History
  static String get historyTitle => _isHi ? 'पिछले टेस्ट का रिकॉर्ड' : 'Past Test History';
  static String historySummary(int count, int pass) => _isHi
      ? 'कुल टेस्ट: $count · उत्तीर्ण: $pass'
      : 'Total Tests: $count · Qualified: $pass';
  static String get historyEmptyTitle => _isHi ? 'कोई पिछला टेस्ट रिकॉर्ड नहीं मिला' : 'No Test History Found';
  static String get historyEmptyDesc => _isHi
      ? 'आपने अभी तक कोई टेस्ट नहीं दिया है। मुख्य परीक्षा पत्र (SET-P) से अभ्यास की शुरुआत करें!'
      : 'You have not attempted any tests yet. Start your practice with the $currentExamYear Predicted Paper (SET-P)!';
  static String get historyStartCta => _isHi ? '📖 SET-P प्रश्न-पुस्तिका हल करें' : '📖 Solve SET-P Booklet';
  static String historyMockType(String mode) => _isHi ? 'मॉक टेस्ट ($mode)' : 'Mock Test ($mode)';
  static String get historyQualified => _isHi ? 'उत्तीर्ण' : 'Qualified';
  static String get historyPracticeNeeded => _isHi ? 'अभ्यास आवश्यक' : 'Needs Practice';

  // Settings Screen
  static String get settingsTitle => _isHi ? 'ऐप सेटिंग्स एवं भाषा' : 'App Settings & Language';
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
  static String get resultsTitle => _isHi ? 'परीक्षा परिणाम एवं विश्लेषण' : 'Exam Results & Analysis';
  static String get passGeneral => _isHi ? '🎉 बधाई! आप उत्तीर्ण हैं (60%+)' : '🎉 Congratulations! You Passed (60%+)';
  static String get passReserved => _isHi ? '⭐ आरक्षित वर्ग में उत्तीर्ण (55%+)' : '⭐ Qualified in Reserved Category (55%+)';
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
  static String get solutionsTitle => _isHi ? 'विस्तृत उत्तर कुंजी एवं हल' : 'Answer Key & Detailed Solutions';
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

  // Section Names
  static String sectionName(String sec) {
    switch (sec.toLowerCase()) {
      case 'cdp':
        return _isHi ? 'बाल विकास एवं शिक्षाशास्त्र (CDP)' : 'Child Development & Pedagogy (CDP)';
      case 'hindi':
        return _isHi ? 'हिन्दी भाषा प्रथम' : 'Hindi Language I';
      case 'english':
        return _isHi ? 'English Language II' : 'English Language II';
      case 'math':
        return _isHi ? 'गणित (Mathematics)' : 'Mathematics';
      case 'evs':
        return _isHi ? 'पर्यावरण अध्ययन (EVS)' : 'Environmental Studies (EVS)';
      case 'science':
        return _isHi ? 'सामान्य विज्ञान (Science)' : 'Science';
      case 'social':
      case 'sst':
        return _isHi ? 'सामाजिक अध्ययन / विज्ञान (SST)' : 'Social Science (SST)';
      case 'sanskrit':
        return _isHi ? 'संस्कृत भाषा द्वितीय' : 'Sanskrit Language II';
      default:
        return sec.toUpperCase();
    }
  }

  // Paper Selector Strings
  static String get paper1Tab => _isHi ? '📘 पेपर-I (1–5 प्राथमिक)' : '📘 Paper-I (1–5)';
  static String get paper2Tab => _isHi ? '📙 पेपर-II (6–8 जूनियर)' : '📙 Paper-II (6–8)';
  static String get paperSelectorHeader => _isHi ? 'परीक्षा स्तर चयन' : 'Select Exam Level';
  static String get paperSelectorDesc => _isHi
      ? 'प्राथमिक स्तर (कक्षा 1 से 5) या उच्च प्राथमिक स्तर (कक्षा 6 से 8) चुनें'
      : 'Choose between Primary Level (Class 1 to 5) or Upper Primary Level (Class 6 to 8)';

  // Gateway Cards on Home Booklets
  static String get gatewayPyqTitle => _isHi
      ? 'विगत वर्ष PYQ वॉल्ट'
      : 'Past PYQ Vault';
  static String get gatewayPyqSub => _isHi
      ? 'विगत वर्षों के सभी प्रश्न-पत्र'
      : 'All previous year papers';
  static String get gatewayMocksTitle => _isHi
      ? '2026 मॉडल टेस्ट'
      : '2026 Model Tests';
  static String get gatewayMocksSub => _isHi
      ? '20 सम्पूर्ण मॉडल सेट्स'
      : '20 complete mock sets';

  // PYQ Section
  static String get pyqVaultTitle => _isHi
      ? '${_isCtet ? "CTET" : "UTET"} विगत वर्ष प्रश्न-पत्र (PYQ)'
      : '${_isCtet ? "CTET" : "UTET"} Previous Year Papers (PYQ)';
  static String get pyqVaultSubtitle => _isCtet
      ? (_isHi
          ? 'केन्द्रीय शिक्षक पात्रता परीक्षा (CBSE) के विगत वर्ष प्रश्न-पत्र'
          : 'Previous year question papers of CTET')
      : (_isHi
          ? 'उत्तराखण्ड शिक्षक पात्रता परीक्षा (UBSE) के विगत वर्ष प्रश्न-पत्र'
          : 'Previous year question papers of UTET');
  static String get pyqVaultBadge => _isHi ? 'विगत वर्ष प्रश्न-पत्र' : 'Previous Year Paper';
  static String pyqVaultCardTitle(String year) => _isHi
      ? '${_isCtet ? "CTET" : "UTET"} $year विगत वर्ष प्रश्न-पत्र'
      : '${_isCtet ? "CTET" : "UTET"} $year Solved Paper';
  static String pyqVaultCardDesc(int count) => _isHi
      ? '$count प्रामाणिक पूर्व वर्ष प्रश्न · 5 विषय'
      : '$count Authentic PYQs · 5 Sections';
  static String get startPyqExamBtn => _isHi ? '📖 प्रश्न-पत्र हल करें' : '📖 Solve Paper';

  // Mock Series Screen
  static String get mockSeriesTitle => _isHi
      ? '10 ${_isCtet ? "CTET" : "UTET"} मॉडल प्रश्न-पुस्तिकाएं ($currentExamYear)'
      : '10 ${_isCtet ? "CTET" : "UTET"} Model Question Booklets ($currentExamYear)';
  static String get mockSeriesSubtitle => _isCtet
      ? (_isHi
          ? 'CBSE परीक्षा पैटर्न पर विश्लेषित 1,500 प्रश्नों की सम्पूर्ण CTET मॉडल टेस्ट शृंखला'
          : 'Complete 1,500-question CTET model test series curated on CBSE pattern')
      : (_isHi
          ? 'उत्तराखण्ड परीक्षा पैटर्न पर विश्लेषित 1,500 प्रश्नों की सम्पूर्ण UTET मॉडल टेस्ट शृंखला'
          : 'Complete 1,500-question UTET model test series curated by exam experts');
  static String mockSeriesCardTitle(int num) => _isHi
      ? 'SET-${num.toString().padLeft(2, '0')} : ${_isCtet ? "CTET" : "UTET"} $currentExamYear मॉडल प्रश्न-पुस्तिका'
      : 'SET-${num.toString().padLeft(2, '0')} : ${_isCtet ? "CTET" : "UTET"} $currentExamYear Model Booklet';
  static String get mockSeriesCardDesc => _isHi
      ? '150 बहुविकल्पीय प्रश्न · 150 मिनट · पूर्णांक 150'
      : '150 MCQs · 150 Minutes · 150 Marks';
  static String get freshMockGenerateBtn => _isHi
      ? '⚡ नया असीमित मॉडल पेपर तैयार करें'
      : '⚡ Generate Fresh Practice Mock';

  // Subject Practice Hub
  static String subjectPracticeHubTitle(String sec) => _isHi ? '$sec अभ्यास हब' : '$sec Practice Hub';
  static String subjectPracticeHubDesc(int total) => _isHi
      ? 'बैंक में कुल $total प्रामाणिक प्रश्न उपलब्ध हैं'
      : 'Total $total authentic questions available in bank';
  static String subjectSetTitle(int num) => _isHi ? 'सेट-$num : 30 प्रश्न अभ्यास' : 'Set-$num : 30 Questions Practice';
  static String get topicsDrillHeading => _isHi ? 'टॉपिक-वार गहन अभ्यास' : 'Topic-wise Focused Drills';
  static String get startPracticeBtn => _isHi ? 'हल शुरू करें ▾' : 'Start Practice ▾';
  static String topicDrillTitle(String topic) => _isHi ? '$topic ड्रिल' : '$topic Drill';
  static String topicDrillSub(int count) => _isHi ? '$count प्रश्न' : '$count Questions';
  static String get subjectCardSetsInfo => _isHi ? '7 अभ्यास सेट्स · टॉपिक ड्रिल' : '7 Practice Sets · Topic Drills';

  // Premium & In-App Purchase Gate (IAP)
  static String get premiumPassTitle => _isHi ? 'TET $currentExamYear संपूर्ण परीक्षा पास' : 'TET $currentExamYear All-Access Pass';
  static String get premiumPassSubtitle => _isHi
      ? 'SET-P मुफ़्त है। बाकी सभी मुख्य पेपर्स, 20 मॉडल बुक्स, सम्पूर्ण विगत वर्ष PYQ और सभी अभ्यास सेट्स को आजीवन अनलॉक करें।'
      : 'SET-P is Free. Unlock all other core papers, 20 model books, complete past PYQs, and all practice sets forever.';
  static String get premiumUnlockBtn => _isHi ? '👑 सम्पूर्ण ऑल-एक्सेस पास अनलॉक करें' : '👑 Unlock All-Access Pass';
  static String get premiumRestoreBtn => _isHi ? 'खरीद पुनर्स्थापित करें' : 'Restore Purchases';
  static String get premiumPriceBadge => _isHi ? 'मात्र ₹99 (75% सीमित समय छूट)' : 'Only ₹99 (75% Limited Discount)';
  static String get premiumFreeBadge => _isHi ? 'मुफ़्त' : 'FREE';
  static String get premiumLockedBadge => _isHi ? '🔒 प्रीमियम पास' : '🔒 Premium Pass';
  static String get premiumSuccessToast => _isHi ? '🎉 बधाई! सम्पूर्ण परीक्षा पास सफलतापूर्वक अनलॉक हो गया।' : '🎉 Congratulations! All-Access Pass Unlocked Successfully.';
  static String get premiumActiveStatus => _isHi ? '👑 ऑल-एक्सेस पास सक्रिय' : '👑 All-Access Pass Active';

  // In-App Update (IAU)
  static String get updateAvailableTitle => _isHi ? 'नया ऐप अपडेट उपलब्ध है!' : 'New App Update Available!';
  static String get updateAvailableDesc => _isHi
      ? 'परीक्षा तैयारी के लिए नवीनतम प्रश्न और सुधार जोड़े गए हैं।'
      : 'Latest exam questions and enhancements have been added.';
  static String get updateNowBtn => _isHi ? 'अभी अपडेट करें' : 'Update Now';
  static String get updateLaterBtn => _isHi ? 'बाद में' : 'Later';

  // In-App Review (IAR)
  static String get reviewPromptTitle => _isHi ? 'क्या आपको हमारी परीक्षा प्रश्न-पुस्तिकाएं पसंद आईं?' : 'Loving our Exam Booklets?';
  static String get reviewPromptDesc => _isHi
      ? 'आपका 5-स्टार रिव्यू हमें और बेहतर प्रामाणिक प्रश्न तैयार करने में मदद करता है।'
      : 'Your 5-star review helps us curate even better authentic questions.';
  static String get rateOnPlayStoreBtn => _isHi ? '⭐ Play Store पर रेट करें' : '⭐ Rate on Play Store';

  // Test Mode Settings
  static String get testModeHeader => _isHi ? 'डिफ़ॉल्ट टेस्ट मोड' : 'Default Test Mode';
  static String get testModeDesc => _isHi
      ? 'टेस्ट हल करने के लिए अपना पसंदीदा मोड चुनें'
      : 'Choose your preferred interface for solving tests';
  static String get cbtModeTitle => _isHi ? '📱 CBT मोड (1 प्रश्न प्रति स्क्रीन · अनुशंसित)' : '📱 CBT Mode (1 Question per Screen · Recommended)';
  static String get cbtModeSub => _isHi
      ? 'कम्प्यूटर टेस्ट · बड़ा साफ़ फॉन्ट · पूर्ण स्क्रीन · आँखों के लिए सुगम'
      : 'Computer test · Large clear font · Full screen · Easy on the eyes';
  static String get bookletModeTitle => _isHi ? '📄 प्रश्न-पुस्तिका मोड (OMR शैली)' : '📄 Question Booklet (OMR)';
  static String get bookletModeSub => _isHi
      ? 'मानक परीक्षा पेपर · 150 प्रश्न सूची · OMR शीट शैली'
      : 'Standard exam paper · 150 questions list · OMR sheet style';
}

