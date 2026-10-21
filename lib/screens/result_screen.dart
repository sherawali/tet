import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_strings.dart';
import '../models/test_session.dart';
import '../models/question.dart';
import '../models/mock_config.dart';
import '../widgets/app_card.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_button.dart';
import 'solution_screen.dart';
import 'home_screen.dart';
import '../database/db_helper.dart';
import '../services/in_app_review_service.dart';
import '../services/exam_service.dart';
import '../services/exam_rules.dart';

class ResultScreen extends StatefulWidget {
  final TestSession session;
  final bool fromHistory;

  const ResultScreen({
    super.key,
    required this.session,
    this.fromHistory = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<Map<String, dynamic>> _recurringWeakTopics = [];
  List<Question> _recurringWrongQuestions = [];

  TestSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    _loadMistakeAnalysis();
  }

  Future<void> _loadMistakeAnalysis() async {
    final topics = await DbHelper.instance.getRecurringMistakeTopics(limit: 5);
    final questions = await DbHelper.instance.getRecurringMistakeQuestions(limit: 30);
    if (!mounted) return;
    setState(() {
      _recurringWeakTopics = topics;
      _recurringWrongQuestions = questions;
    });

    // Review prompts belong to a freshly completed test, not to reopening an
    // old result from History.
    if (!widget.fromHistory) {
      InAppReviewService.instance.checkAndPromptReview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = session.calculateScore();
    final total = session.questions.length;
    final pct = ExamRules.percentage(score, total);
    final isPassGeneral = ExamRules.isGeneralPass(score, total);
    final isPassReserved = ExamRules.isReservedPass(score, total);

    final answeredCount = session.answeredCount;
    final accuracy = answeredCount > 0 ? (score / answeredCount) * 100 : 0.0;
    final timeMinutes = (session.elapsedSeconds / 60).round();

    // 1. Identify Wrong and Unattempted Questions
    final wrongQuestions = <Question>[];
    final unattemptedQuestions = <Question>[];

    for (int i = 0; i < session.questions.length; i++) {
      final q = session.questions[i];
      final ans = session.selectedAnswers[i];
      if (ans != null) {
        if (ans != q.answer) {
          wrongQuestions.add(q);
        }
      } else {
        unattemptedQuestions.add(q);
      }
    }

    // 2. Calculate Section-wise Breakdown
    final Map<String, ({int total, int correct, int wrong, int unattempted})> secStats = {};
    for (int i = 0; i < session.questions.length; i++) {
      final q = session.questions[i];
      final sec = q.section;
      final selected = session.selectedAnswers[i];
      final isCorrect = selected == q.answer;
      final isWrong = selected != null && !isCorrect;
      final isUnattempted = selected == null;

      final current = secStats[sec] ?? (total: 0, correct: 0, wrong: 0, unattempted: 0);
      secStats[sec] = (
        total: current.total + 1,
        correct: current.correct + (isCorrect ? 1 : 0),
        wrong: current.wrong + (isWrong ? 1 : 0),
        unattempted: current.unattempted + (isUnattempted ? 1 : 0),
      );
    }

    // 3. Calculate Topic-wise Breakdown
    final Map<String, ({int total, int correct, int wrong, int unattempted, String section})> topicStats = {};
    for (int i = 0; i < session.questions.length; i++) {
      final q = session.questions[i];
      final topic = (q.topicName != null && q.topicName!.trim().isNotEmpty)
          ? q.topicName!.trim()
          : AppStrings.generalQuestionFallback;
      final selected = session.selectedAnswers[i];
      final isCorrect = selected == q.answer;
      final isWrong = selected != null && !isCorrect;
      final isUnattempted = selected == null;

      final current = topicStats[topic] ?? (total: 0, correct: 0, wrong: 0, unattempted: 0, section: q.section);
      topicStats[topic] = (
        total: current.total + 1,
        correct: current.correct + (isCorrect ? 1 : 0),
        wrong: current.wrong + (isWrong ? 1 : 0),
        unattempted: current.unattempted + (isUnattempted ? 1 : 0),
        section: q.section,
      );
    }

    // Sort topics: highest wrong first
    final sortedTopics = topicStats.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.wrong.compareTo(a.value.wrong);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });

    final weakTopics = sortedTopics.where((e) => e.value.wrong > 0).take(3).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(AppStrings.resultsTitle),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          children: [
            // 1. Score Hero Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPassGeneral
                      ? [const Color(0xFF064E3B), AppColors.primary]
                      : (isPassReserved
                          ? [AppColors.warningDark, AppColors.primary]
                          : [const Color(0xFF450A0A), AppColors.primary]),
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: AppRadius.roundedLg,
                border: Border.all(
                  color: (isPassGeneral
                          ? AppColors.success
                          : (isPassReserved ? AppColors.sealGold : AppColors.danger))
                      .withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    isPassGeneral
                        ? AppStrings.passGeneral
                        : (isPassReserved
                            ? AppStrings.passReserved
                            : AppStrings.needMorePractice),
                    style: AppTypography.titleLarge(color: Colors.white).copyWith(fontSize: 17),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$score',
                        style: AppTypography.displayLarge(color: Colors.white).copyWith(fontSize: 52),
                      ),
                      Text(
                        ' / $total',
                        style: AppTypography.titleLarge(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      AppBadge(
                        label: AppStrings.resultMarksPct(pct),
                        color: isPassGeneral ? AppColors.success : (isPassReserved ? AppColors.sealGold : AppColors.danger),
                        isSolid: true,
                      ),
                      AppBadge(
                        label: AppStrings.resultAccuracy(accuracy),
                        color: AppColors.primary,
                        isSolid: true,
                      ),
                      AppBadge(
                        label: AppStrings.resultTime(timeMinutes),
                        color: AppColors.violet,
                        isSolid: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Wrong Questions Practice Card (Re-practice Mistakes)
            if (wrongQuestions.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryLight : const Color(0xFFFFFBEB),
                  borderRadius: AppRadius.roundedBase,
                  border: Border.all(
                    color: isDark ? AppColors.sealGold : AppColors.goldBright,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.sealGold.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.replay_rounded, color: AppColors.sealGold, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.rePracticeTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.goldText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppStrings.rePracticeSub(wrongQuestions.length),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.sealGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sealGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        final practiceConfig = MockConfig(
                          mode: MockMode.pyq,
                          seed: DateTime.now().millisecondsSinceEpoch,
                          totalQuestions: wrongQuestions.length,
                          timeLimitMinutes: (wrongQuestions.length * 1.5).ceil().clamp(5, 150),
                        );
                        final practiceSession = TestSession(
                          id: 'practice_${DateTime.now().millisecondsSinceEpoch}',
                          config: practiceConfig,
                          questions: wrongQuestions,
                          passages: session.passages,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ExamService.instance.buildExamScreen(session: practiceSession),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppStrings.rePracticeBtn(wrongQuestions.length),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 2.5 Recurring Weaknesses Card (🎯 बार-बार होने वाली कमजोरियाँ)
            if (_recurringWeakTopics.isNotEmpty || _recurringWrongQuestions.isNotEmpty) ...[
              _buildRecurringMistakesCard(isDark),
              const SizedBox(height: 18),
            ],

            // 3. Smart Guidance & Advice (💡 विशेषज्ञ मार्गदर्शन एवं सही सलाह)
            _buildGuidanceCard(
              isDark: isDark,
              score: score,
              total: total,
              pct: pct,
              accuracy: accuracy,
              wrongCount: wrongQuestions.length,
              weakTopics: weakTopics,
            ),
            const SizedBox(height: 20),

            // 4. Section Breakdown (विषयवार प्रदर्शन)
            Text(
              AppStrings.sectionBreakdownTitle,
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ).copyWith(fontSize: 15),
            ),
            const SizedBox(height: 10),

            ...secStats.entries.map((e) {
              final secName = AppStrings.sectionName(e.key);
              final secColor = _getSectionColor(e.key);
              final correct = e.value.correct;
              final wrong = e.value.wrong;
              final secTotal = e.value.total;
              final secPct = secTotal > 0 ? (correct / secTotal) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: secColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    secName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '✓ $correct ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.success,
                                ),
                              ),
                              Text(
                                '✗ $wrong ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: wrong > 0 ? AppColors.danger : Colors.grey,
                                ),
                              ),
                              Text(
                                '/ $secTotal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: AppRadius.roundedFull,
                        child: LinearProgressIndicator(
                          value: secPct,
                          minHeight: 6,
                          backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(secColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),

            // 5. Detailed Topic Breakdown (सभी टॉपिक्स का विस्तृत विश्लेषण)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.topicAnalysisTitle,
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ).copyWith(fontSize: 15),
                ),
                Text(
                  '${sortedTopics.length} Topics',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...sortedTopics.map((e) {
              final topic = e.key;
              final stats = e.value;
              final secColor = _getSectionColor(stats.section);
              final accuracy = stats.total > 0 ? ((stats.correct / stats.total) * 100).round() : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            topic,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: secColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stats.section.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: secColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildStatChip(
                              icon: Icons.check_circle_outline_rounded,
                              label: '${stats.correct} ${AppStrings.correctShort}',
                              color: AppColors.success,
                              isDark: isDark,
                            ),
                            _buildStatChip(
                              icon: Icons.highlight_off_rounded,
                              label: '${stats.wrong} ${AppStrings.wrongShort}',
                              color: stats.wrong > 0 ? AppColors.danger : Colors.grey,
                              isDark: isDark,
                            ),
                            if (stats.unattempted > 0)
                              _buildStatChip(
                                icon: Icons.radio_button_unchecked_rounded,
                                label: '${stats.unattempted} ${AppStrings.unattemptedShort}',
                                color: Colors.blueGrey,
                                isDark: isDark,
                              ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (accuracy >= 60
                                    ? AppColors.success
                                    : (accuracy >= 40 ? AppColors.sealGold : AppColors.danger))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$accuracy% ${AppStrings.accuracyShort}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: accuracy >= 60
                                  ? AppColors.success
                                  : (accuracy >= 40 ? AppColors.sealGold : AppColors.danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // 6. Action Buttons
            AppButton(
              label: AppStrings.viewSolutionsBtn,
              variant: AppButtonVariant.primary,
              height: 48,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SolutionScreen(session: session),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              label: AppStrings.backHomeBtn,
              variant: AppButtonVariant.outline,
              height: 48,
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceCard({
    required bool isDark,
    required int score,
    required int total,
    required double pct,
    required double accuracy,
    required int wrongCount,
    required List<MapEntry<String, ({int correct, String section, int total, int unattempted, int wrong})>> weakTopics,
  }) {
    String headline;
    String adviceText;
    Color badgeColor;

    if (ExamRules.isGeneralPass(score, total)) {
      headline = 'उत्कृष्ट तैयारी! आप 60% कट-ऑफ पार कर चुके हैं।';
      adviceText = 'आपकी मजबूत पकड़ बन चुकी है। अब शीर्ष मेरिट में स्थान बनाने के लिए उन 1-2 टॉपिक्स पर काम करें जिनमें गलतियाँ हुईं।';
      badgeColor = AppColors.success;
    } else if (ExamRules.isReservedPass(score, total)) {
      final needed = ExamRules.generalPassMark(total) - score;
      headline = 'सराहनीय! आप सामान्य कट-ऑफ के बहुत करीब हैं।';
      adviceText = 'आपको सामान्य वर्ग पार करने के लिए केवल $needed और अंक चाहिए। नीचे दिए कमजोर टॉपिक्स का पुनः अभ्यास करके आसानी से 100+ अंक ला सकते हैं।';
      badgeColor = AppColors.sealGold;
    } else {
      final needed = ExamRules.reservedPassMark(total) - score;
      headline = AppStrings.targetedRevisionNeed;
      adviceText = 'आरक्षित वर्ग कट-ऑफ (55%) के लिए $needed और अंक आवश्यक हैं। घबराएं नहीं, पूर्व वर्ष के प्रश्नों (SET-R) और गलत प्रश्नों के पुनः अभ्यास से स्कोर तुरंत बढ़ेगा।';
      badgeColor = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.successSubtle,
        borderRadius: AppRadius.roundedBase,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.successBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_rounded, color: badgeColor, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.guidanceTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.successText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            adviceText,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : AppColors.grayText,
            ),
          ),
          if (weakTopics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardElevated : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.grayBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.topWeakTopicsWarning,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.danger),
                  ),
                  const SizedBox(height: 6),
                  ...weakTopics.map((w) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_right_rounded, size: 24, color: AppColors.danger),
                          Expanded(
                            child: Text(
                              '${w.key} (${w.value.section.toUpperCase()})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '${w.value.wrong} ${AppStrings.wrongShort}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSectionColor(String sec) {
    switch (sec.toLowerCase()) {
      case 'cdp':
        return AppColors.cdp;
      case 'hindi':
        return AppColors.hindi;
      case 'english':
        return AppColors.english;
      case 'math':
        return AppColors.math;
      case 'evs':
        return AppColors.evs;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildRecurringMistakesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.indigoSurface : const Color(0xFFFEF2F2),
        borderRadius: AppRadius.roundedBase,
        border: Border.all(
          color: isDark ? AppColors.indigoText : AppColors.dangerBorder,
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.sealGold : AppColors.danger).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚨 ${AppStrings.recurringWeaknesses}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.isHindi
                          ? 'सिस्टम ने आपके पिछले टेस्टों में इन कमजोरियों को बार-बार पकड़ा है:'
                          : 'System has identified these recurring weaknesses from your tests:',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Topic Chips with repeat count
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recurringWeakTopics.map((t) {
              final topic = t['topic_name'] as String? ?? 'General';
              final wrongs = (t['total_wrongs'] as num?)?.toInt() ?? 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel_outlined, size: 14, color: AppColors.danger),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$wrongs बार गलत',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Actionable Guide Text
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.directions_rounded, size: 18, color: AppColors.sealGold),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'सही दिशा में सुधार: इन टॉपिक्स के प्रश्न रटने के बजाय पहले इनके नियम और बुनियादी सिद्धांत समझें। फिर नीचे दिए बटन से सिर्फ इन्हीं गलत हुए प्रश्नों का अभ्यास करें।',
                    style: TextStyle(fontSize: 11.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),

          // Re-Test Recurring Mistakes Button
          if (_recurringWrongQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  final repeatConfig = MockConfig(
                    mode: MockMode.pyq,
                    seed: DateTime.now().millisecondsSinceEpoch,
                    totalQuestions: _recurringWrongQuestions.length,
                    timeLimitMinutes: (_recurringWrongQuestions.length * 1.5).ceil().clamp(5, 150),
                  );
                  final repeatSession = TestSession(
                    id: 'repeat_mistakes_${DateTime.now().millisecondsSinceEpoch}',
                    config: repeatConfig,
                    questions: _recurringWrongQuestions,
                    passages: session.passages,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ExamService.instance.buildExamScreen(session: repeatSession),
                    ),
                  );
                },
                icon: const Icon(Icons.replay_circle_filled_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '🎯 बार-बार गलत हुए (${_recurringWrongQuestions.length}) प्रश्नों का री-टेस्ट हल करें',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
