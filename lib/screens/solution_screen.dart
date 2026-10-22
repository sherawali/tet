import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_strings.dart';
import '../models/test_session.dart';
import '../models/test_language_mode.dart';
import '../models/question.dart';
import '../widgets/app_card.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_state_views.dart';
import '../widgets/formatted_question_stem.dart';
import '../widgets/smart_math_text.dart';
import '../widgets/question_report_sheet.dart';
import '../widgets/question_figure_catalog.dart';
import '../services/language_service.dart';
import '../design_system/app_sheet.dart';

enum SolutionFilter { all, incorrect, unattempted, correct }

class SolutionScreen extends StatefulWidget {
  final TestSession session;

  const SolutionScreen({super.key, required this.session});

  @override
  State<SolutionScreen> createState() => _SolutionScreenState();
}

class _SolutionScreenState extends State<SolutionScreen> {
  SolutionFilter _filter = SolutionFilter.all;
  late TestLanguageMode _languageMode;

  /// Questions whose passage is shown in full instead of the short preview.
  final Set<int> _expandedPassages = {};

  @override
  void initState() {
    super.initState();
    _languageMode = TestLanguageMode.onlyHindi;
  }

  /// The one border of this file.
  Border _cardBorder(bool isDark, {Color? color, double width = 1.2}) =>
      Border.all(
        color: color ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        width: width,
      );

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allQuestions = widget.session.questions;
    final userAnswers = widget.session.selectedAnswers;

    final filteredIndices = <int>[];
    for (int i = 0; i < allQuestions.length; i++) {
      final q = allQuestions[i];
      final userAns = userAnswers[i];
      final isAnswered = userAns != null;
      final isCorrect = isAnswered && userAns == q.answer;

      if (_filter == SolutionFilter.all) {
        filteredIndices.add(i);
      } else if (_filter == SolutionFilter.correct && isCorrect) {
        filteredIndices.add(i);
      } else if (_filter == SolutionFilter.incorrect && isAnswered && !isCorrect) {
        filteredIndices.add(i);
      } else if (_filter == SolutionFilter.unattempted && !isAnswered) {
        filteredIndices.add(i);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.examPaperLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          InkWell(
            onTap: _showLanguageSelectorSheet,
            borderRadius: AppRadius.roundedSm,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated,
                borderRadius: AppRadius.roundedSm,
                border: _cardBorder(
                  isDark,
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _languageMode.badgeLabel,
                    style: AppTypography.labelSmall(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.xs,
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('${AppStrings.solFilterAll} (${allQuestions.length})', SolutionFilter.all, isDark),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(AppStrings.solFilterIncorrect, SolutionFilter.incorrect, isDark),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(AppStrings.solFilterUnattempted, SolutionFilter.unattempted, isDark),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(AppStrings.solFilterCorrect, SolutionFilter.correct, isDark),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: filteredIndices.isEmpty
            ? _buildEmptyState(isDark)
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.base),
                itemCount: filteredIndices.length,
                itemBuilder: (context, idx) {
                final qIdx = filteredIndices[idx];
                final q = allQuestions[qIdx];
                final userAns = userAnswers[qIdx];
                final isCorrect = userAns != null && userAns == q.answer;
                final pid = q.passageId;
                final passage = (pid != null && widget.session.passages.containsKey(pid))
                    ? widget.session.passages[pid]
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.base),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppStrings.solQuestionNum(qIdx + 1),
                                  style: AppTypography.titleMedium(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                if (userAns == null)
                                  AppBadge(label: AppStrings.solBadgeUnattempted, color: AppColors.danger)
                                else if (isCorrect)
                                  AppBadge(label: AppStrings.solBadgeCorrect, color: AppColors.success)
                                else
                                  AppBadge(label: AppStrings.solBadgeIncorrect, color: AppColors.danger),
                              ],
                            ),
                            if (q.topicName != null)
                              AppBadge(label: q.topicName!, color: AppColors.primary, wrap: true),
                            InkWell(
                              onTap: () => QuestionReportSheet.show(
                                context,
                                question: q,
                                questionNumber: qIdx + 1,
                                paperTitle: widget.session.paperTitle ?? widget.session.setCode,
                                userAnswer: userAns,
                              ),
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
                        const SizedBox(height: AppSpacing.sm),

                        // PYQ & Probability info
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            if (q.displayTag != null || q.isPyq)
                              AppBadge(
                                label: q.displayTag ?? 'PYQ: ${q.years}',
                                color: AppColors.violet,
                                icon: Icons.history_edu_rounded,
                              ),
                            AppBadge(
                              label: AppStrings.solProbScore(q.pScore),
                              color: AppColors.cdp,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Passage (if any)
                        if (passage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.primarySubtle,
                              borderRadius: AppRadius.roundedMd,
                              border: _cardBorder(isDark),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      passage.isPoem ? Icons.auto_stories_rounded : Icons.article_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        passage.isPoem
                                            ? (LanguageService.instance.isHindi ? 'अपठित पद्यांश' : 'Poem')
                                            : (LanguageService.instance.isHindi ? 'अपठित गद्यांश' : 'Comprehension Passage'),
                                        style: AppTypography.labelSmall(color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.primaryLight : AppColors.sealGoldSubtle,
                                    border: Border(
                                      left: BorderSide(
                                        color: isDark ? AppColors.primary : AppColors.sealGold,
                                        width: 2.5,
                                      ),
                                    ),
                                    borderRadius: AppRadius.roundedSm,
                                  ),
                                  child: Text(
                                    'निर्देश : ${passage.displayDir}',
                                    style: AppTypography.labelSmall(
                                      color: isDark ? AppColors.borderStrong : AppColors.warningDark,
                                    ).copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (!_expandedPassages.add(qIdx)) {
                                        _expandedPassages.remove(qIdx);
                                      }
                                    });
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        passage.cleanBody,
                                        maxLines: _expandedPassages.contains(qIdx) ? null : 5,
                                        overflow: _expandedPassages.contains(qIdx)
                                            ? null
                                            : TextOverflow.ellipsis,
                                        style: AppTypography.passageBody(
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ).copyWith(
                                          height: passage.isPoem ? 1.7 : 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        _expandedPassages.contains(qIdx)
                                            ? 'संपूर्ण गद्यांश छिपाएँ ▲'
                                            : 'पूरा गद्यांश पढ़ें ▼',
                                        style: AppTypography.labelSmall(
                                          color: isDark
                                              ? AppColors.accentBright
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Question Stem
                        _buildSolQuestionStem(q, isDark),
                        const SizedBox(height: AppSpacing.md),

                        // 4 Options with answer highlights
                        ..._buildSolOptions(q, userAns, isCorrect, isDark),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  /// The empty state of this screen: an icon, the message and a quiet card
  /// around it, so a filtered-out list never looks broken.
  Widget _buildEmptyState(bool isDark) {
    return AppEmptyState(
      icon: Icons.filter_alt_off_rounded,
      accent: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      title: AppStrings.solNoQuestionsInCategory,
    );
  }

  Widget _buildSolQuestionStem(Question q, bool isDark) {
    final mode = _languageMode;

    if (mode == TestLanguageMode.onlyEnglish) {
      final engText = (q.hasEnglish && q.qEnglish != null && q.qEnglish!.trim().isNotEmpty)
          ? q.qEnglish!
          : q.qHindi;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormattedQuestionStem(
            text: engText,
            style: AppTypography.questionText(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            isDark: isDark,
          ),
          if (QuestionFigureCatalog.hasQuestionFigure(q.id))
            QuestionFigureCatalog.buildQuestion(
              questionId: q.id,
              isDark: isDark,
              height: 170,
            ),
        ],
      );
    }

    if (mode == TestLanguageMode.onlyHindi) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormattedQuestionStem(
            text: q.qHindi,
            style: AppTypography.questionText(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            isDark: isDark,
          ),
          if (QuestionFigureCatalog.hasQuestionFigure(q.id))
            QuestionFigureCatalog.buildQuestion(
              questionId: q.id,
              isDark: isDark,
              height: 170,
            ),
        ],
      );
    }

    // Bilingual: Clean Hindi with separate English Translation callout
    final showEnglish = q.hasEnglish &&
        q.qEnglish != null &&
        q.qEnglish!.trim().isNotEmpty &&
        q.qEnglish!.trim().toLowerCase() != q.qHindi.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormattedQuestionStem(
          text: q.qHindi,
          style: AppTypography.questionText(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          isDark: isDark,
        ),
        if (showEnglish) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.primarySubtle,
              borderRadius: AppRadius.roundedMd,
              border: _cardBorder(
                isDark,
                color: AppColors.violet.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: FormattedQuestionStem(
              text: q.qEnglish!,
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ).copyWith(fontStyle: FontStyle.italic),
              isDark: isDark,
              isTranslation: true,
            ),
          ),
        ],
        if (QuestionFigureCatalog.hasQuestionFigure(q.id))
          QuestionFigureCatalog.buildQuestion(
            questionId: q.id,
            isDark: isDark,
            height: 170,
          ),
      ],
    );
  }

  List<Widget> _buildSolOptions(Question q, int? userAns, bool isCorrect, bool isDark) {
    final mode = _languageMode;
    final int count = q.optionsHindi.length;

    final hasOptionFigure = QuestionFigureCatalog.hasOptionFigures(q.id);

    return List.generate(count, (optIdx) {
      final isThisCorrectAnswer = optIdx == q.answer;
      final isThisUserChoice = optIdx == userAns;

      Color optBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
      Color optBg = Colors.transparent;
      IconData? trailingIcon;
      Color iconColor = Colors.transparent;

      if (isThisCorrectAnswer) {
        optBorder = AppColors.success;
        optBg = AppColors.success.withValues(alpha: 0.12);
        trailingIcon = Icons.check_circle_rounded;
        iconColor = AppColors.success;
      } else if (isThisUserChoice && !isCorrect) {
        optBorder = AppColors.danger;
        optBg = AppColors.danger.withValues(alpha: 0.12);
        trailingIcon = Icons.cancel_rounded;
        iconColor = AppColors.danger;
      }

      final label = String.fromCharCode(65 + optIdx);

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

      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: optBg,
          borderRadius: AppRadius.roundedSm,
          border: Border.all(color: optBorder, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label. ',
              style: AppTypography.titleSmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
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
                      ),
                    ),
                  if (!hasOptionFigure && secondaryText != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    SmartMathText(
                      secondaryText,
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: iconColor, size: 20),
          ],
        ),
      );
    });
  }

  Widget _buildFilterChip(String label, SolutionFilter filter, bool isDark) {
    final isSelected = _filter == filter;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: isDark ? AppColors.sealGold : AppColors.primary,
      labelStyle: AppTypography.labelSmall(
        color: isSelected
            ? (isDark ? AppColors.darkBg : AppColors.darkTextPrimary)
            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      ),
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      side: BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}
