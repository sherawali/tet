import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_typography.dart';
import '../models/question.dart';
import '../models/test_language_mode.dart';
import 'formatted_question_stem.dart';
import 'math_diagram_widget.dart';

/// Master Special Render Engine for Board Exam Questions
/// Specialised rendering for:
/// - Paragraph & Comprehension
/// - Poetry & Verses
/// - Hindi & English Bilingual Modes
/// - Assertion & Reason / Kathan & Nishkarsh
/// - Match The Column (2-Column Pairs)
/// - Markdown Data Tables
/// - LaTeX Math Equations
/// - Geometry Figures & Math Diagrams
class ExamSpecialRenderEngine extends StatelessWidget {
  final Question question;
  final TestLanguageMode languageMode;
  final bool isDark;

  const ExamSpecialRenderEngine({
    super.key,
    required this.question,
    required this.languageMode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final mode = languageMode;

    if (mode == TestLanguageMode.onlyEnglish) {
      final engText = (question.hasEnglish && question.qEnglish != null && question.qEnglish!.trim().isNotEmpty)
          ? question.qEnglish!
          : question.qHindi;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormattedQuestionStem(
            text: engText,
            isDark: isDark,
            style: AppTypography.questionText(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ).copyWith(fontWeight: FontWeight.w600, height: 1.6),
          ),
          if (MathDiagramWidget.hasDiagram(question.id, engText)) ...[
            const SizedBox(height: AppSpacing.sm),
            MathDiagramWidget(
              questionId: question.id,
              rawText: engText,
              isDark: isDark,
            ),
          ],
        ],
      );
    }

    if (mode == TestLanguageMode.onlyHindi) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormattedQuestionStem(
            text: question.qHindi,
            isDark: isDark,
            style: AppTypography.questionText(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ).copyWith(fontWeight: FontWeight.w600, height: 1.6),
          ),
          if (MathDiagramWidget.hasDiagram(question.id, question.qHindi)) ...[
            const SizedBox(height: AppSpacing.sm),
            MathDiagramWidget(
              questionId: question.id,
              rawText: question.qHindi,
              isDark: isDark,
            ),
          ],
        ],
      );
    }

    // Bilingual Mode: Pure Hindi first, then dedicated elegant English translation callout
    final showEnglishBox = question.hasEnglish &&
        question.qEnglish != null &&
        question.qEnglish!.trim().isNotEmpty &&
        question.qEnglish!.trim().toLowerCase() != question.qHindi.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hindi Primary Header Badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.accentBright : AppColors.primary).withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: AppRadius.roundedSm,
              ),
              child: Text(
                'हिन्दी (Hindi)',
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.accentBright : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Hindi Stem
        FormattedQuestionStem(
          text: question.qHindi,
          isDark: isDark,
          style: AppTypography.questionText(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ).copyWith(fontWeight: FontWeight.w600, height: 1.6),
        ),

        // Diagram (if present)
        if (MathDiagramWidget.hasDiagram(question.id, question.qHindi)) ...[
          const SizedBox(height: AppSpacing.sm),
          MathDiagramWidget(
            questionId: question.id,
            rawText: question.qHindi,
            isDark: isDark,
          ),
        ],

        // English Translation Callout
        if (showEnglishBox) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.darkTextPrimary,
              borderRadius: AppRadius.roundedBase,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.translate_rounded,
                      size: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'English Translation',
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                FormattedQuestionStem(
                  text: question.qEnglish!,
                  isDark: isDark,
                  isTranslation: true,
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.lightBorder : AppColors.lightTextSecondary,
                  ).copyWith(fontStyle: FontStyle.italic, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
