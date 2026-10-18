import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_strings.dart';
import '../models/test_session.dart';
import '../models/test_language_mode.dart';
import '../models/question.dart';
import '../services/language_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_badge.dart';
import '../widgets/formatted_question_stem.dart';
import '../widgets/smart_math_text.dart';

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

  @override
  void initState() {
    super.initState();
    _languageMode = LanguageService.instance.isHindi
        ? TestLanguageMode.onlyHindi
        : TestLanguageMode.onlyEnglish;
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
                'भाषा चुनें (Select Language)',
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
        title: Text(AppStrings.solutionsTitle),
        actions: [
          InkWell(
            onTap: _showLanguageSelectorSheet,
            borderRadius: AppRadius.roundedSm,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated,
                borderRadius: AppRadius.roundedSm,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    _languageMode.badgeLabel,
                    style: AppTypography.labelSmall(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('${AppStrings.solFilterAll} (${allQuestions.length})', SolutionFilter.all, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(AppStrings.solFilterIncorrect, SolutionFilter.incorrect, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(AppStrings.solFilterUnattempted, SolutionFilter.unattempted, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(AppStrings.solFilterCorrect, SolutionFilter.correct, isDark),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: filteredIndices.isEmpty
            ? Center(
                child: Text(
                  AppStrings.solNoQuestionsInCategory,
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
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
                                const SizedBox(width: 8),
                                if (userAns == null)
                                  AppBadge(label: AppStrings.solBadgeUnattempted, color: AppColors.danger)
                                else if (isCorrect)
                                  AppBadge(label: AppStrings.solBadgeCorrect, color: AppColors.success)
                                else
                                  AppBadge(label: AppStrings.solBadgeIncorrect, color: AppColors.danger),
                              ],
                            ),
                            if (q.topicName != null)
                              AppBadge(label: q.topicName!, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // PYQ & Probability info
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
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
                        const SizedBox(height: 12),

                        // Passage (if any)
                        if (passage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF161E2E) : const Color(0xFFF1F5F9),
                              borderRadius: AppRadius.roundedSm,
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
                                    const SizedBox(width: 6),
                                    Text(
                                      passage.isPoem ? 'अपठित पद्यांश (काव्य)' : 'अपठित गद्यांश (Passage)',
                                      style: AppTypography.labelSmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                                    border: Border(
                                      left: BorderSide(
                                        color: isDark ? AppColors.primary : const Color(0xFFB45309),
                                        width: 2.5,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    'निर्देश : ${passage.displayDir}',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF78350F),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  passage.cleanBody,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.passageBody(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ).copyWith(fontSize: 13, height: passage.isPoem ? 1.5 : 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Question Stem
                        _buildSolQuestionStem(q, isDark),
                        const SizedBox(height: 14),

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

  Widget _buildSolQuestionStem(Question q, bool isDark) {
    final mode = _languageMode;

    if (mode == TestLanguageMode.onlyEnglish) {
      final engText = (q.hasEnglish && q.qEnglish != null && q.qEnglish!.trim().isNotEmpty)
          ? q.qEnglish!
          : q.qHindi;
      return FormattedQuestionStem(
        text: engText,
        style: AppTypography.questionText(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ).copyWith(fontSize: 15.5),
        isDark: isDark,
      );
    }

    if (mode == TestLanguageMode.onlyHindi) {
      return FormattedQuestionStem(
        text: q.qHindi,
        style: AppTypography.questionText(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ).copyWith(fontSize: 15.5),
        isDark: isDark,
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
          ).copyWith(fontSize: 15.5),
          isDark: isDark,
        ),
        if (showEnglish) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2A) : const Color(0xFFF1F5F9),
              borderRadius: AppRadius.roundedSm,
              border: Border.all(
                color: AppColors.violet.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: FormattedQuestionStem(
              text: q.qEnglish!,
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ).copyWith(fontSize: 13.5, fontStyle: FontStyle.italic),
              isDark: isDark,
              isTranslation: true,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildSolOptions(Question q, int? userAns, bool isCorrect, bool isDark) {
    final mode = _languageMode;
    final int count = q.optionsHindi.length;

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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ).copyWith(fontSize: 14),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartMathText(
                    primaryText,
                    style: AppTypography.optionText(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ).copyWith(fontSize: 14),
                  ),
                  if (secondaryText != null) ...[
                    const SizedBox(height: 3),
                    SmartMathText(
                      secondaryText,
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ).copyWith(fontStyle: FontStyle.italic, fontSize: 12),
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
            ? (isDark ? AppColors.darkBg : Colors.white)
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
