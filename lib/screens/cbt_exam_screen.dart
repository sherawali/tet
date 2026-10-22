import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_shadows.dart';
import '../models/test_session.dart';
import '../services/section_catalog.dart';
import '../models/question.dart';
import '../models/passage.dart';
import '../models/mock_config.dart';
import '../models/test_language_mode.dart';
import '../widgets/app_card.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_button.dart';
import '../widgets/smart_math_text.dart';
import '../widgets/exam_special_render_engine.dart';
import '../widgets/passage_display_card.dart';
import '../widgets/question_report_sheet.dart';
import '../widgets/question_figure_catalog.dart';
import '../database/db_helper.dart';
import '../design_system/app_strings.dart';
import 'result_screen.dart';
import '../design_system/app_motion.dart';
import '../design_system/app_sheet.dart';

class CbtExamScreen extends StatefulWidget {
  final TestSession session;
  final int initialQuestionIndex;

  const CbtExamScreen({
    super.key,
    required this.session,
    this.initialQuestionIndex = 0,
  });

  @override
  State<CbtExamScreen> createState() => _CbtExamScreenState();
}

class _CbtExamScreenState extends State<CbtExamScreen>
    with WidgetsBindingObserver {
  late int _currentIndex;
  late final ValueNotifier<int> _remainingSecondsNotifier;
  Timer? _timer;
  late DateTime _deadline;
  late TestLanguageMode _languageMode;
  bool _submitting = false;
  bool _paperIsEmpty = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _languageMode = TestLanguageMode.onlyHindi;
    if (widget.session.questions.isEmpty) {
      // A paper without questions would crash the index maths below.
      _paperIsEmpty = true;
      _currentIndex = 0;
      _remainingSecondsNotifier = ValueNotifier<int>(0);
      return;
    }
    _currentIndex = widget.initialQuestionIndex.clamp(0, widget.session.questions.length - 1);
    final totalSecs = widget.session.config.timeLimitMinutes * 60;
    final initialRemaining = (totalSecs - widget.session.elapsedSeconds).clamp(0, totalSecs);
    _remainingSecondsNotifier = ValueNotifier<int>(initialRemaining);
    _deadline = DateTime.now().add(Duration(seconds: initialRemaining));
    widget.session.visitedIndices.add(_currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startTimer();
  }

  int get _secondsLeft {
    final remaining = _deadline.difference(DateTime.now()).inSeconds;
    final limit = widget.session.config.timeLimitMinutes * 60;
    return remaining.clamp(0, limit);
  }

  void _syncTimer({bool submitWhenExpired = true}) {
    if (_submitting) return;
    final remaining = _secondsLeft;
    _remainingSecondsNotifier.value = remaining;
    widget.session.elapsedSeconds =
        (widget.session.config.timeLimitMinutes * 60) - remaining;
    if (remaining <= 0 && submitWhenExpired) {
      _timer?.cancel();
      _submitTest(autoSubmit: true);
    }
  }

  void _startTimer() {
    _syncTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _syncTimer());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Recompute before the OS suspends the periodic timer so the elapsed
      // value reflects the real wall clock as closely as possible.
      _syncTimer(submitWhenExpired: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _remainingSecondsNotifier.dispose();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Question get _currentQ => widget.session.questions[_currentIndex];

  Passage? get _currentPassage {
    final pid = _currentQ.passageId;
    if (pid != null && pid.isNotEmpty) {
      final syncPassage = PassageResolver.getPassageSync(pid, sessionPassages: widget.session.passages);
      if (syncPassage != null) return syncPassage;
      // Asynchronously preload from SQLite if not yet cached
      PassageResolver.getPassageAsync(pid, sessionPassages: widget.session.passages).then((p) {
        if (mounted && p != null) {
          setState(() {});
        }
      });
    }
    return null;
  }

  /// The one border of this file.
  Border _cardBorder(bool isDark, {Color? color, double width = 1.2}) =>
      Border.all(
        color: color ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        width: width,
      );

  /// The same border as a single side, for the sheets and bars that need one.
  BorderSide _cardBorderSide(bool isDark, {Color? color, double width = 1.2}) =>
      BorderSide(
        color: color ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        width: width,
      );

  /// The one filled button style of this file.
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

  void _goToQuestion(int idx) {
    if (idx < 0 || idx >= widget.session.questions.length) return;
    setState(() {
      _currentIndex = idx;
      widget.session.visitedIndices.add(idx);
    });
    _scrollController.animateTo(
      0,
      duration: AppMotion.base,
      curve: AppMotion.emphasized,
    );
  }

  void _selectOption(int optionIndex) {
    setState(() {
      widget.session.selectedAnswers[_currentIndex] = optionIndex;
    });
  }

  void _clearResponse() {
    setState(() {
      widget.session.selectedAnswers.remove(_currentIndex);
    });
  }

  void _toggleMarkForReview() {
    setState(() {
      if (widget.session.markedForReview.contains(_currentIndex)) {
        widget.session.markedForReview.remove(_currentIndex);
      } else {
        widget.session.markedForReview.add(_currentIndex);
      }
    });
  }

  void _saveAndNext() {
    if (_currentIndex < widget.session.questions.length - 1) {
      _goToQuestion(_currentIndex + 1);
    } else {
      _showSubmitConfirmation();
    }
  }

  Future<void> _submitTest({bool autoSubmit = false}) async {
    if (_submitting) return;
    _timer?.cancel();
    _syncTimer(submitWhenExpired: false);
    _submitting = true;
    widget.session.isCompleted = true;
    widget.session.endTime = DateTime.now();

    final score = widget.session.calculateScore();
    final total = widget.session.questions.length;

    // Save the full session snapshot so the completed test can be reopened
    // from History and reviewed question by question.
    try {
      await DbHelper.instance.saveTestHistory(
        id: widget.session.id,
        mode: widget.session.config.mode.shortTitle,
        sectionFilter: widget.session.config.sectionFilter,
        score: score,
        total: total,
        timeSpentSeconds: widget.session.elapsedSeconds,
        sessionJson: widget.session.encode(),
      );

      // Track user mistakes and weaknesses across tests
      await DbHelper.instance.recordSessionMistakes(widget.session);
    } catch (error) {
      debugPrint('Unable to save CBT test result: $error');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultScreen(session: widget.session),
      ),
    );
  }

  void _showSubmitConfirmation() {
    final answered = widget.session.answeredCount;
    final marked = widget.session.markedCount;
    final total = widget.session.questions.length;
    final notAnswered = total - answered;

    AppSheet.show(
      context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.base,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border(
              top: _cardBorderSide(isDark),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: AppSpacing.xxl,
                    height: AppSpacing.xs,
                    margin: const EdgeInsets.only(bottom: AppSpacing.base),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      borderRadius: AppRadius.roundedFull,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.sealGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pause_circle_rounded, color: AppColors.sealGold, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.exitExamTitle,
                            style: AppTypography.titleLarge(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppStrings.exitExamRemaining(total, answered, notAnswered),
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),

                // Metrics summary
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.base,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : AppColors.primarySubtle,
                    borderRadius: AppRadius.roundedBase,
                    border: _cardBorder(isDark),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('हल किए गए', '$answered', AppColors.success),
                      _buildSummaryItem('समीक्षा हेतु', '$marked', AppColors.warning),
                      _buildSummaryItem('शेष (अनुत्तरित)', '$notAnswered', AppColors.danger),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Option 1: Continue Test (Primary Green)
                ElevatedButton.icon(
                  style: _filledButtonStyle(
                    bg: AppColors.success,
                    fg: AppColors.darkTextPrimary,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(
                    AppStrings.continueTestBtn,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Option 2: Submit and View Result
                ElevatedButton.icon(
                  style: _filledButtonStyle(
                    bg: isDark ? AppColors.sealGold : AppColors.primary,
                    fg: isDark ? AppColors.darkBg : AppColors.darkTextPrimary,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _submitTest();
                  },
                  icon: const Icon(Icons.fact_check_rounded, size: 24),
                  label: Text(
                    AppStrings.submitViewResultBtn,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Option 3: Discard and Exit directly to Home (No forced submit!)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedBase),
                    textStyle: AppTypography.titleSmall(color: AppColors.danger),
                  ),
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(ctx); // Close sheet
                    Navigator.pop(context); // Close exam, return directly to Home
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 22),
                  label: Text(
                    AppStrings.discardDirectExitBtn,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleLarge(color: color),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall(color: color),
        ),
      ],
    );
  }

  void _showPalette() {
    AppSheet.show(
      context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.base,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      width: AppSpacing.xxl,
                      height: AppSpacing.xs,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: AppRadius.roundedFull,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.questionPaletteTitle,
                            style: AppTypography.titleLarge(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Palette Legend
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _buildLegendBadge('हल किया', AppColors.success),
                        _buildLegendBadge('समीक्षा', AppColors.warning),
                        _buildLegendBadge('छोड़ा गया', AppColors.danger),
                        _buildLegendBadge('नहीं देखा', isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Grid of Questions
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: widget.session.questions.length,
                        itemBuilder: (context, i) {
                          final status = widget.session.getQuestionStatus(i);
                          final isCurrent = i == _currentIndex;

                          Color btnBg;
                          Color textFg = AppColors.darkTextPrimary;

                          switch (status) {
                            case QuestionStatus.answered:
                              btnBg = AppColors.success;
                              break;
                            case QuestionStatus.markedForReview:
                            case QuestionStatus.answeredAndMarked:
                              btnBg = AppColors.warning;
                              break;
                            case QuestionStatus.notAnswered:
                              btnBg = AppColors.danger;
                              break;
                            case QuestionStatus.notVisited:
                              btnBg = isDark ? AppColors.primaryLight : AppColors.borderStrong;
                              textFg = isDark ? AppColors.lightBorder : AppColors.deskGray;
                              break;
                          }

                          return InkWell(
                            borderRadius: AppRadius.roundedSm,
                            onTap: () {
                              Navigator.pop(ctx);
                              _goToQuestion(i);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: btnBg,
                                borderRadius: AppRadius.roundedSm,
                                border: isCurrent
                                    ? Border.all(color: isDark ? AppColors.accentBright : AppColors.primary, width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: AppTypography.titleSmall(color: textFg),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'परीक्षा सबमिट करें',
                      variant: AppButtonVariant.primary,
                      width: double.infinity,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSubmitConfirmation();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendBadge(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.labelSmall(color: color),
        ),
      ],
    );
  }

  void _showLanguageSelectorSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    AppSheet.show(
      context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.base,
            AppSpacing.lg,
            AppSpacing.base,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: AppSpacing.xxl,
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: AppRadius.roundedFull,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                AppStrings.selectLangTitle,
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...TestLanguageMode.values.map((mode) {
                final isSelected = _languageMode == mode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: InkWell(
                    borderRadius: AppRadius.roundedSm,
                    onTap: () {
                      setState(() => _languageMode = mode);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : (isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated),
                        borderRadius: AppRadius.roundedSm,
                        border: _cardBorder(
                          isDark,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mode.title,
                                  style: AppTypography.titleSmall(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  mode.description,
                                  style: AppTypography.labelSmall(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Text(
                              mode.badgeLabel,
                              style: AppTypography.labelSmall(
                                color: isSelected ? AppColors.darkTextPrimary : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        );
      },
    );
  }

  void _showReportQuestionDialog(Question q, int qNum) {
    QuestionReportSheet.show(
      context,
      question: q,
      questionNumber: qNum,
      paperTitle: widget.session.paperTitle ?? widget.session.setCode,
      userAnswer: widget.session.selectedAnswers[_currentIndex],
    );
  }

  String _formatTimer(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_paperIsEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(title: Text(AppStrings.examEmptyStateTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 32,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    'इस प्रश्न-पत्र में कोई प्रश्न नहीं मिला।\nकृपया दूसरा प्रश्न-पत्र चुनें।',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'वापस जाएँ',
                    variant: AppButtonVariant.primary,
                    width: double.infinity,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final q = _currentQ;
    final selectedOpt = widget.session.selectedAnswers[_currentIndex];
    final isMarked = widget.session.markedForReview.contains(_currentIndex);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showSubmitConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: AppStrings.exitExamTitle,
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: _showSubmitConfirmation,
          ),
          leadingWidth: 44,
          title: Row(
            children: [
              // 1. Timer with ValueListenableBuilder (Zero Jerk, Isolated Rebuild)
              ValueListenableBuilder<int>(
                valueListenable: _remainingSecondsNotifier,
                builder: (context, seconds, _) {
                  final isLow = seconds < 600;
                  final timerColor = isLow
                      ? AppColors.danger
                      : (isDark ? AppColors.accentBright : AppColors.primary);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: AppRadius.roundedSm,
                      border: Border.all(
                        color: timerColor.withValues(alpha: isDark ? 0.6 : 1.0),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          size: 16,
                          color: timerColor,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _formatTimer(seconds),
                          style: AppTypography.numericTimer(
                            color: timerColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),

              // 2. Language Mode Selector Pill
              Flexible(
                child: InkWell(
                  onTap: _showLanguageSelectorSheet,
                  borderRadius: AppRadius.roundedSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated,
                      borderRadius: AppRadius.roundedSm,
                      border: _cardBorder(
                        isDark,
                        color: isDark ? AppColors.darkBorder : AppColors.primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language_rounded, size: 15, color: isDark ? AppColors.accentBright : AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            _languageMode.badgeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // 3. Question Palette Button
              IconButton(
                tooltip: 'प्रश्न पैलेट',
                icon: const Icon(Icons.grid_view_rounded, size: 22),
                onPressed: _showPalette,
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressStrip(isDark),
                _buildSectionTabBar(isDark),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                children: [
                  // The paper the candidate is solving.  The same wording as
                  // on every other screen of the app.
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          AppStrings.examPaperStreamLabel,
                          maxLines: 2,
                          style: AppTypography.labelSmall(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Question Header & Badges (Responsive Wrap for Compact Devices like S23)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text(
                        _languageMode == TestLanguageMode.onlyEnglish
                            ? 'Question ${_currentIndex + 1} of ${widget.session.questions.length}'
                            : 'प्रश्न ${_currentIndex + 1} / ${widget.session.questions.length}',
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (q.displayTag != null || q.isPyq)
                            AppBadge(
                              label: q.displayTag ?? 'PYQ ${q.years ?? ''}',
                              color: isDark ? AppColors.violetLight : AppColors.violet,
                              icon: Icons.history_edu_rounded,
                            ),
                          if (q.topicName != null)
                            AppBadge(
                              label: q.topicName!,
                              color: isDark ? AppColors.accentBright : AppColors.primary,
                              wrap: true,
                            ),
                          InkWell(
                            onTap: () => _showReportQuestionDialog(q, _currentIndex + 1),
                            borderRadius: AppRadius.roundedSm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.sealGoldLight.withValues(alpha: isDark ? 0.22 : 0.12),
                                borderRadius: AppRadius.roundedSm,
                                border: _cardBorder(
                                  isDark,
                                  color: AppColors.sealGoldLight.withValues(alpha: 0.45),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flag_rounded, size: 13, color: AppColors.goldBright),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'रिपोर्ट',
                                    style: AppTypography.labelSmall(
                                      color: isDark ? AppColors.goldBright : AppColors.sealGold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Reading Comprehension Passage (if applicable)
                  if (_currentPassage != null) ...[
                    Builder(builder: (ctx) {
                      final related = [
                        for (int i = 0; i < widget.session.questions.length; i++)
                          if (widget.session.questions[i].passageId == _currentPassage!.id) i + 1
                      ];
                      return PassageDisplayCard(
                        passage: _currentPassage!,
                        seqInPassage: q.seqInPassage,
                        startQNum: related.isNotEmpty ? related.first : null,
                        endQNum: related.isNotEmpty ? related.last : null,
                        isDark: isDark,
                        initiallyExpanded: true,
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Question Stem Card (Generous, eye-friendly typography)
                  _buildCbtQuestionCard(q, isDark),
                  const SizedBox(height: AppSpacing.base),

                  // 4 Options (Generous touch targets & crisp font)
                  ..._buildCbtOptions(q, selectedOpt, isDark),
                ],
              ),
            ),

            // Bottom Exam Actions
            _buildBottomActionBar(isDark, isMarked),
          ],
        ),
      ),
    );
  }

  Widget _buildCbtQuestionCard(Question q, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.base,
      ),
      child: ExamSpecialRenderEngine(
        question: q,
        languageMode: _languageMode,
        isDark: isDark,
      ),
    );
  }

  List<Widget> _buildCbtOptions(Question q, int? selectedOpt, bool isDark) {
    final mode = _languageMode;
    final int optCount = q.optionsHindi.length;

    return List.generate(optCount, (optIdx) {
      final isSelected = selectedOpt == optIdx;
      final optLabel = String.fromCharCode(65 + optIdx); // A, B, C, D

      String primaryText = '';
      String? secondaryText;

      if (mode == TestLanguageMode.onlyEnglish) {
        if (q.optionsEnglish != null &&
            optIdx < q.optionsEnglish!.length &&
            q.optionsEnglish![optIdx].trim().isNotEmpty) {
          primaryText = q.optionsEnglish![optIdx];
        } else {
          primaryText = q.optionsHindi[optIdx];
        }
      } else if (mode == TestLanguageMode.onlyHindi) {
        primaryText = q.optionsHindi[optIdx];
      } else {
        // Bilingual
        primaryText = q.optionsHindi[optIdx];
        if (q.optionsEnglish != null && optIdx < q.optionsEnglish!.length) {
          final en = q.optionsEnglish![optIdx].trim();
          if (en.isNotEmpty && en.toLowerCase() != primaryText.trim().toLowerCase()) {
            secondaryText = en;
          }
        }
      }

      final hasOptionFigure = QuestionFigureCatalog.hasOptionFigures(q.id);

      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          color: isSelected
              ? (isDark ? AppColors.indigoSurface : AppColors.infoSurface)
              : null,
          border: isSelected
              ? BorderSide(color: isDark ? AppColors.violet : AppColors.primary, width: 2.0)
              : BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.2,
                ),
          onTap: () => _selectOption(optIdx),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.violet : AppColors.primary)
                      : (isDark ? AppColors.darkCardElevated : AppColors.lightBorder),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    optLabel,
                    style: AppTypography.titleSmall(
                      color: isSelected
                          ? AppColors.darkTextPrimary
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasOptionFigure)
                      QuestionFigureCatalog.buildOption(
                        questionId: q.id,
                        optionIndex: optIdx,
                        isDark: isDark,
                      )
                    else
                      SmartMathText(
                        primaryText,
                        style: AppTypography.questionText(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ).copyWith(
                          height: 1.55,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    if (!hasOptionFigure && secondaryText != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      SmartMathText(
                        secondaryText,
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.deskGray,
                        ).copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildProgressStrip(bool isDark) {
    final total = widget.session.questions.length;
    final answered = widget.session.selectedAnswers.length;
    final review = widget.session.markedForReview.length;
    final ratio = total == 0 ? 0.0 : answered / total;
    final track = isDark ? AppColors.primaryLight : AppColors.borderStrong;
    final fill = isDark ? AppColors.accentBright : AppColors.primary;
    final labelColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.roundedFull,
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation<Color>(fill),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'हल: $answered/$total',
            style: AppTypography.labelSmall(color: labelColor),
          ),
          if (review > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              'समीक्षा: $review',
              style: AppTypography.labelSmall(color: labelColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTabBar(bool isDark) {
    final questions = widget.session.questions;
    final isSingleSection = widget.session.config.sectionFilter != null;

    if (isSingleSection) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        alignment: Alignment.centerLeft,
        child: Text(
          'सेक्शन: ${widget.session.config.sectionFilter!.toUpperCase()}',
          style: AppTypography.labelSmall(color: isDark ? AppColors.accentBright : AppColors.primary),
        ),
      );
    }

    // Dynamic section boundaries detected from actual questions in the session
    // Section labels come from the shared catalogue so that every vault
    // code (lang1_hindi, math_science, ...) gets a readable name.
    final sectionNames = <String, String>{
      for (final code in SectionCatalog.order) code: SectionCatalog.short(code),
    };

    final discoveredSections = <Map<String, dynamic>>[];
    for (int i = 0; i < questions.length; i++) {
      final sec = questions[i].section.toLowerCase();
      final existing = discoveredSections.indexWhere((e) => e['id'] == sec);
      if (existing == -1) {
        discoveredSections.add({
          'id': sec,
          'name': sectionNames[sec] ?? sec.toUpperCase(),
          'start': i,
          'count': 1,
        });
      } else {
        discoveredSections[existing]['count'] = (discoveredSections[existing]['count'] as int) + 1;
      }
    }

    // Fallback if section info not tagged
    if (discoveredSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: discoveredSections.length,
        itemBuilder: (context, i) {
          final s = discoveredSections[i];
          final startIdx = s['start'] as int;
          final count = s['count'] as int;
          final isCurrentSec = _currentIndex >= startIdx && _currentIndex < (startIdx + count);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: ChoiceChip(
              label: Text('${s['name']} ($count)'),
              selected: isCurrentSec,
              selectedColor: isDark ? AppColors.optionSelectedBorder : AppColors.primary,
              labelStyle: AppTypography.labelSmall(
                color: isCurrentSec ? AppColors.darkTextPrimary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              onSelected: (_) {
                if (startIdx < widget.session.questions.length) {
                  _goToQuestion(startIdx);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomActionBar(bool isDark, bool isMarked) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(
          top: _cardBorderSide(isDark, width: 1.0),
        ),
        boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Previous
            IconButton(
              tooltip: _languageMode == TestLanguageMode.onlyEnglish ? 'Previous' : 'पिछला प्रश्न',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _currentIndex > 0 ? () => _goToQuestion(_currentIndex - 1) : null,
            ),
            const SizedBox(width: AppSpacing.xs),

            // Clear
            IconButton(
              tooltip: _languageMode == TestLanguageMode.onlyEnglish ? 'Clear Response' : 'उत्तर साफ़ करें',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clearResponse,
            ),
            const SizedBox(width: AppSpacing.xs),

            // Mark for review
            IconButton(
              tooltip: isMarked
                  ? (_languageMode == TestLanguageMode.onlyEnglish ? 'Remove Mark' : 'समीक्षा मार्क हटाएं')
                  : (_languageMode == TestLanguageMode.onlyEnglish ? 'Mark for Review' : 'समीक्षा के लिए मार्क करें'),
              icon: Icon(
                isMarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
                color: isMarked ? AppColors.warning : null,
              ),
              onPressed: _toggleMarkForReview,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Save & Next
            Expanded(
              child: AppButton(
                label: _currentIndex == widget.session.questions.length - 1
                    ? (_languageMode == TestLanguageMode.onlyEnglish ? 'Submit' : 'सबमिट करें')
                    : (_languageMode == TestLanguageMode.onlyEnglish ? 'Save & Next' : 'सेव एवं आगे'),
                variant: AppButtonVariant.primary,
                width: double.infinity,
                height: 44,
                onPressed: _saveAndNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
