import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_shadows.dart';
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

  /// The one border of this file: every card, sheet and chip uses it.
  Border _cardBorder(bool isDark, {Color? color, double width = 1.2}) =>
      Border.all(
        color: color ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        width: width,
      );

  /// The one shadow of this file.
  List<BoxShadow> _cardShadow(bool isDark) =>
      isDark ? AppShadows.darkCard : AppShadows.card;

  /// The one card padding of this file.  The hero card is the only surface
  /// that is allowed to breathe more, because it carries the score.
  static const EdgeInsets _cardPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.base,
    vertical: AppSpacing.md,
  );

  /// The one heading rhythm of this file.
  Widget _sectionHeading(
    bool isDark, {
    required String title,
    String? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleMedium(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            trailing,
            style: AppTypography.labelSmall(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
            ),
          ),
        ],
      ],
    );
  }

  /// The one filled-button style of this file.
  ButtonStyle _filledButtonStyle({
    required Color bg,
    required Color fg,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.base,
      ),
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedBase),
      textStyle: AppTypography.titleSmall(color: fg),
    );
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
        title: Text(
          AppStrings.examPaperLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: AppColors.darkTextPrimary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.base,
          ),
          children: [
            // 1. Score Hero Card
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xl,
                horizontal: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPassGeneral
                      ? [AppColors.successDeep, AppColors.primary]
                      : (isPassReserved
                          ? [AppColors.warningDark, AppColors.primary]
                          : [AppColors.dangerDeep, AppColors.primary]),
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
                boxShadow: _cardShadow(isDark),
              ),
              child: Column(
                children: [
                  Text(
                    isPassGeneral
                        ? AppStrings.passGeneral
                        : (isPassReserved
                            ? AppStrings.passReserved
                            : AppStrings.needMorePractice),
                    style: AppTypography.titleLarge(color: AppColors.darkTextPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$score',
                        style: AppTypography.displayMedium(color: AppColors.darkTextPrimary),
                      ),
                      Text(
                        ' / $total',
                        style: AppTypography.titleLarge(
                          color: AppColors.darkTextPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
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
            const SizedBox(height: AppSpacing.base),

            // 2. Wrong Questions Practice Card (Re-practice Mistakes)
            if (wrongQuestions.isNotEmpty) ...[
              Container(
                padding: _cardPadding,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryLight : AppColors.warningSubtle,
                  borderRadius: AppRadius.roundedBase,
                  border: _cardBorder(
                    isDark,
                    color: isDark ? AppColors.sealGold : AppColors.goldBright,
                  ),
                  boxShadow: _cardShadow(isDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.sealGold.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.replay_rounded, color: AppColors.sealGold, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.rePracticeTitle,
                                style: AppTypography.titleSmall(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.goldText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                AppStrings.rePracticeSub(wrongQuestions.length),
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.sealGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      style: _filledButtonStyle(
                        bg: AppColors.sealGold,
                        fg: AppColors.primaryDark,
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
                      label: Text(
                        AppStrings.rePracticeBtn(wrongQuestions.length),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 2.5 Recurring Weaknesses Card
            if (_recurringWeakTopics.isNotEmpty || _recurringWrongQuestions.isNotEmpty) ...[
              _buildRecurringMistakesCard(isDark),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 3. Smart Guidance & Advice
            _buildGuidanceCard(
              isDark: isDark,
              score: score,
              total: total,
              pct: pct,
              accuracy: accuracy,
              wrongCount: wrongQuestions.length,
              weakTopics: weakTopics,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 4. Section Breakdown
            _sectionHeading(isDark, title: AppStrings.sectionBreakdownTitle),
            const SizedBox(height: AppSpacing.sm),

            ...secStats.entries.map((e) {
              final secName = AppStrings.sectionName(e.key);
              final secColor = _getSectionColor(e.key);
              final correct = e.value.correct;
              final wrong = e.value.wrong;
              final secTotal = e.value.total;
              final secPct = secTotal > 0 ? (correct / secTotal) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: _cardPadding,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                                  decoration: BoxDecoration(color: secColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    secName,
                                    style: AppTypography.titleSmall(
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '✓ $correct ',
                                style: AppTypography.labelMedium(
                                  color: AppColors.success,
                                ),
                              ),
                              Text(
                                '✗ $wrong ',
                                style: AppTypography.labelMedium(
                                  color: wrong > 0
                                      ? AppColors.danger
                                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                ),
                              ),
                              Text(
                                '/ $secTotal',
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.lg),

            // 5. Detailed Topic Breakdown
            _sectionHeading(
              isDark,
              title: AppStrings.topicAnalysisTitle,
              trailing: AppStrings.topicsCount(sortedTopics.length),
            ),
            const SizedBox(height: AppSpacing.sm),

            ...sortedTopics.map((e) {
              final topic = e.key;
              final stats = e.value;
              final secColor = _getSectionColor(stats.section);
              final accuracy = stats.total > 0 ? ((stats.correct / stats.total) * 100).round() : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: _cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              topic,
                              style: AppTypography.titleSmall(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: secColor.withValues(alpha: 0.15),
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Text(
                              stats.section.toUpperCase(),
                              style: AppTypography.labelSmall(color: secColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
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
                                color: stats.wrong > 0
                                    ? AppColors.danger
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                isDark: isDark,
                              ),
                              if (stats.unattempted > 0)
                                _buildStatChip(
                                  icon: Icons.radio_button_unchecked_rounded,
                                  label: '${stats.unattempted} ${AppStrings.unattemptedShort}',
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  isDark: isDark,
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: (accuracy >= 60
                                      ? AppColors.success
                                      : (accuracy >= 40 ? AppColors.sealGold : AppColors.danger))
                                  .withValues(alpha: 0.12),
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Text(
                              '$accuracy% ${AppStrings.accuracyShort}',
                              style: AppTypography.labelSmall(
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
                ),
              );
            }),
            const SizedBox(height: AppSpacing.lg),

            // 6. Action Buttons
            AppButton(
              label: AppStrings.viewSolutionsBtn,
              variant: AppButtonVariant.primary,
              width: double.infinity,
              height: 48,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SolutionScreen(session: session),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: AppStrings.backHomeBtn,
              variant: AppButtonVariant.outline,
              width: double.infinity,
              height: 48,
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
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
      headline = AppStrings.resultPassedHeadline;
      adviceText = AppStrings.resultPassedAdvice;
      badgeColor = AppColors.success;
    } else if (ExamRules.isReservedPass(score, total)) {
      final needed = ExamRules.generalPassMark(total) - score;
      headline = AppStrings.resultReservedHeadline;
      adviceText = AppStrings.resultReservedAdvice(needed);
      badgeColor = AppColors.sealGold;
    } else {
      final needed = ExamRules.reservedPassMark(total) - score;
      headline = AppStrings.targetedRevisionNeed;
      adviceText = 'आरक्षित वर्ग कट-ऑफ (55%) के लिए $needed और अंक आवश्यक हैं। घबराएं नहीं, पूर्व वर्ष के प्रश्नों (SET-R) और गलत प्रश्नों के पुनः अभ्यास से स्कोर तुरंत बढ़ेगा।';
      badgeColor = AppColors.danger;
    }

    // The card surface follows the verdict, so the eye reads the result
    // before it reads a single word.
    final Color surface;
    final Color hairline;
    switch (badgeColor) {
      case AppColors.success:
        surface = AppColors.successSubtle;
        hairline = AppColors.successBorder;
        break;
      case AppColors.sealGold:
        surface = AppColors.sealGoldSubtle;
        hairline = AppColors.goldBright;
        break;
      default:
        surface = AppColors.dangerSubtle;
        hairline = AppColors.dangerBorder;
        break;
    }

    return Container(
      padding: _cardPadding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : surface,
        borderRadius: AppRadius.roundedBase,
        border: _cardBorder(
          isDark,
          color: isDark ? AppColors.darkBorder : hairline,
        ),
        boxShadow: _cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_rounded, color: badgeColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.guidanceTitle,
                  style: AppTypography.titleSmall(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            headline,
            style: AppTypography.labelMedium(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            adviceText,
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          if (weakTopics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardElevated : AppColors.lightCard,
                borderRadius: AppRadius.roundedBase,
                border: _cardBorder(isDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.topWeakTopicsWarning,
                    style: AppTypography.labelSmall(color: AppColors.danger),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...weakTopics.map((w) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.arrow_right_rounded, size: 20, color: AppColors.danger),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              '${w.key} (${w.value.section.toUpperCase()})',
                              style: AppTypography.labelMedium(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${w.value.wrong} ${AppStrings.wrongShort}',
                            style: AppTypography.labelSmall(color: AppColors.danger),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.roundedSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.labelSmall(color: color),
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
      padding: _cardPadding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.indigoSurface : AppColors.dangerSubtle,
        borderRadius: AppRadius.roundedBase,
        border: _cardBorder(
          isDark,
          color: isDark ? AppColors.indigoText : AppColors.dangerBorder,
        ),
        boxShadow: _cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.sealGold : AppColors.danger).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚨 ${AppStrings.recurringWeaknesses}',
                      style: AppTypography.titleSmall(color: AppColors.danger),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.isHindi
                          ? 'सिस्टम ने आपके पिछले टेस्टों में इन कमजोरियों को बार-बार पकड़ा है:'
                          : 'System has identified these recurring weaknesses from your tests:',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Topic Chips with repeat count
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _recurringWeakTopics.map((t) {
              final topic = t['topic_name'] as String? ?? 'General';
              final wrongs = (t['total_wrongs'] as num?)?.toInt() ?? 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: AppRadius.roundedSm,
                  border: _cardBorder(
                    isDark,
                    color: AppColors.danger.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel_outlined, size: 14, color: AppColors.danger),
                    const SizedBox(width: AppSpacing.xs),
                    // The topic name is never cut: it wraps inside the chip.
                    Flexible(
                      child: Text(
                        topic,
                        style: AppTypography.labelSmall(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: AppRadius.roundedFull,
                      ),
                      child: Text(
                        '$wrongs बार गलत',
                        style: AppTypography.labelSmall(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Actionable Guide Text
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary : AppColors.lightCard,
              borderRadius: AppRadius.roundedBase,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.directions_rounded, size: 18, color: AppColors.sealGold),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'सही दिशा में सुधार: इन टॉपिक्स के प्रश्न रटने के बजाय पहले इनके नियम और बुनियादी सिद्धांत समझें। फिर नीचे दिए बटन से सिर्फ इन्हीं गलत हुए प्रश्नों का अभ्यास करें।',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Re-Test Recurring Mistakes Button
          if (_recurringWrongQuestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: _filledButtonStyle(
                  bg: AppColors.danger,
                  fg: AppColors.darkTextPrimary,
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
                label: Text(
                  '🎯 बार-बार गलत हुए (${_recurringWrongQuestions.length}) प्रश्नों का री-टेस्ट हल करें',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
