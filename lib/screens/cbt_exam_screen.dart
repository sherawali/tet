import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../models/test_session.dart';
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



  void _goToQuestion(int idx) {
    if (idx < 0 || idx >= widget.session.questions.length) return;
    setState(() {
      _currentIndex = idx;
      widget.session.visitedIndices.add(idx);
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.5,
              ),
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
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.sealGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pause_circle_rounded, color: AppColors.sealGold, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.exitExamTitle,
                            style: AppTypography.titleLarge(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ).copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.exitExamRemaining(total, answered, notAnswered),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Metrics summary
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9),
                    borderRadius: AppRadius.roundedBase,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
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
                const SizedBox(height: 20),

                // Option 1: Continue Test (Primary Green)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedBase),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(
                    AppStrings.continueTestBtn,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 10),

                // Option 2: Submit and View Result
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.sealGold : AppColors.primary,
                    foregroundColor: isDark ? AppColors.darkBg : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedBase),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _submitTest();
                  },
                  icon: const Icon(Icons.fact_check_rounded, size: 24),
                  label: Text(
                    AppStrings.submitViewResultBtn,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 10),

                // Option 3: Discard and Exit directly to Home (No forced submit!)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedBase),
                  ),
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(ctx); // Close sheet
                    Navigator.pop(context); // Close exam, return directly to Home
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 22),
                  label: Text(
                    AppStrings.discardDirectExitBtn,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
          style: AppTypography.numericTimer(color: color).copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall(color: color),
        ),
      ],
    );
  }

  void _showPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: AppRadius.roundedFull,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.questionPaletteTitle,
                          style: AppTypography.titleLarge(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Palette Legend
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildLegendBadge('हल किया', AppColors.success),
                        _buildLegendBadge('समीक्षा', AppColors.warning),
                        _buildLegendBadge('छोड़ा गया', AppColors.danger),
                        _buildLegendBadge('नहीं देखा', isDark ? const Color(0xFF94A3B8) : AppColors.lightTextMuted),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grid of Questions
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: widget.session.questions.length,
                        itemBuilder: (context, i) {
                          final status = widget.session.getQuestionStatus(i);
                          final isCurrent = i == _currentIndex;

                          Color btnBg;
                          Color textFg = Colors.white;

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
                              btnBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
                              textFg = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
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
                                    ? Border.all(color: isDark ? const Color(0xFF38BDF8) : AppColors.primary, width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: AppTypography.titleMedium(color: textFg).copyWith(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
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
        const SizedBox(width: 5),
        Text(label, style: AppTypography.labelSmall(color: color)),
      ],
    );
  }

  void _showLanguageSelectorSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: AppRadius.roundedFull,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.selectLangTitle,
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ...TestLanguageMode.values.map((mode) {
                final isSelected = _languageMode == mode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: AppRadius.roundedSm,
                    onTap: () {
                      setState(() => _languageMode = mode);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : (isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated),
                        borderRadius: AppRadius.roundedSm,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mode.title,
                                  style: AppTypography.titleMedium(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ).copyWith(fontSize: 14.5),
                                ),
                                const SizedBox(height: 2),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Text(
                              mode.badgeLabel,
                              style: AppTypography.labelSmall(
                                color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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
        appBar: AppBar(title: const Text('परीक्षा')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 46),
                const SizedBox(height: 12),
                Text(
                  'इस प्रश्न-पत्र में कोई प्रश्न नहीं मिला।\nकृपया दूसरा प्रश्न-पत्र चुनें।',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('वापस जाएँ'),
                ),
              ],
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
                      : (isDark ? const Color(0xFF38BDF8) : AppColors.primary);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        const SizedBox(width: 6),
                        Text(
                          _formatTimer(seconds),
                          style: AppTypography.numericTimer(
                            color: timerColor,
                          ).copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),

              // 2. Language Mode Selector Pill
              InkWell(
                onTap: _showLanguageSelectorSheet,
                borderRadius: AppRadius.roundedSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated,
                    borderRadius: AppRadius.roundedSm,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language_rounded, size: 15, color: isDark ? const Color(0xFF38BDF8) : AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        _languageMode.badgeLabel,
                        style: AppTypography.labelSmall(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  // Question Header & Badges (Responsive Wrap for Compact Devices like S23)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        _languageMode == TestLanguageMode.onlyEnglish
                            ? 'Question ${_currentIndex + 1} of ${widget.session.questions.length}'
                            : 'प्रश्न ${_currentIndex + 1} / ${widget.session.questions.length}',
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ).copyWith(fontSize: 16.5, fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (q.displayTag != null || q.isPyq)
                            AppBadge(
                              label: q.displayTag ?? 'PYQ ${q.years ?? ''}',
                              color: isDark ? const Color(0xFFA78BFA) : AppColors.violet,
                              icon: Icons.history_edu_rounded,
                            ),
                          if (q.topicName != null)
                            AppBadge(
                              label: q.topicName!,
                              color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                            ),
                          InkWell(
                            onTap: () => _showReportQuestionDialog(q, _currentIndex + 1),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.45),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flag_rounded, size: 13, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'रिपोर्ट',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
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
                  const SizedBox(height: 12),

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
                    const SizedBox(height: 14),
                  ],

                  // Question Stem Card (Generous, eye-friendly typography)
                  _buildCbtQuestionCard(q, isDark),
                  const SizedBox(height: 16),

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        padding: const EdgeInsets.only(bottom: 12.0),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: isSelected
              ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
              : null,
          border: isSelected
              ? BorderSide(color: isDark ? const Color(0xFF6366F1) : AppColors.primary, width: 2.0)
              : BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.0,
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
                      ? (isDark ? const Color(0xFF6366F1) : AppColors.primary)
                      : (isDark ? AppColors.darkCardElevated : AppColors.lightBorder),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    optLabel,
                    style: AppTypography.titleMedium(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ).copyWith(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                        style: AppTypography.optionText(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 16.5,
                        ).copyWith(
                          height: 1.55,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    if (!hasOptionFigure && secondaryText != null) ...[
                      const SizedBox(height: 6),
                      SmartMathText(
                        secondaryText,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          fontStyle: FontStyle.italic,
                          fontSize: 13.5,
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
    final track = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final fill = isDark ? const Color(0xFF38BDF8) : AppColors.primary;
    final labelColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation<Color>(fill),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'हल: $answered/$total',
            style: AppTypography.labelSmall(color: labelColor)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
          if (review > 0) ...[
            const SizedBox(width: 8),
            Text(
              'समीक्षा: $review',
              style: AppTypography.labelSmall(color: labelColor)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 11.5),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          'सेक्शन: ${widget.session.config.sectionFilter!.toUpperCase()}',
          style: AppTypography.labelSmall(color: isDark ? const Color(0xFF38BDF8) : AppColors.primary),
        ),
      );
    }

    // Dynamic section boundaries detected from actual questions in the session
    final sectionNames = {
      'cdp': 'CDP',
      'hindi': 'हिन्दी',
      'english': 'English',
      'math': 'गणित',
      'evs': 'EVS',
      'sans': 'संस्कृत',
      'science': 'विज्ञान',
      'social': 'सामाजिक अध्ययन',
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: discoveredSections.length,
        itemBuilder: (context, i) {
          final s = discoveredSections[i];
          final startIdx = s['start'] as int;
          final count = s['count'] as int;
          final isCurrentSec = _currentIndex >= startIdx && _currentIndex < (startIdx + count);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text('${s['name']} ($count)'),
              selected: isCurrentSec,
              selectedColor: isDark ? const Color(0xFF2563EB) : AppColors.primary,
              labelStyle: AppTypography.labelSmall(
                color: isCurrentSec ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
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
            const SizedBox(width: 4),

            // Clear
            IconButton(
              tooltip: _languageMode == TestLanguageMode.onlyEnglish ? 'Clear Response' : 'उत्तर साफ़ करें',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clearResponse,
            ),
            const SizedBox(width: 4),

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
            const Spacer(),

            // Save & Next
            AppButton(
              label: _currentIndex == widget.session.questions.length - 1
                  ? (_languageMode == TestLanguageMode.onlyEnglish ? 'Submit' : 'सबमिट करें')
                  : (_languageMode == TestLanguageMode.onlyEnglish ? 'Save & Next' : 'सेव एवं आगे'),
              variant: AppButtonVariant.primary,
              height: 42,
              onPressed: _saveAndNext,
            ),
          ],
        ),
      ),
    );
  }
}
