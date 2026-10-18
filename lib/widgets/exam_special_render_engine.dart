import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
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
              fontSize: 17.5,
            ).copyWith(fontWeight: FontWeight.w600, height: 1.6),
          ),
          if (MathDiagramWidget.hasDiagram(question.id, engText)) ...[
            const SizedBox(height: 10),
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
              fontSize: 17.5,
            ).copyWith(fontWeight: FontWeight.w600, height: 1.6),
          ),
          if (MathDiagramWidget.hasDiagram(question.id, question.qHindi)) ...[
            const SizedBox(height: 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF38BDF8) : AppColors.primary).withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: AppRadius.roundedSm,
              ),
              child: Text(
                'हिन्दी (Hindi)',
                style: AppTypography.labelSmall(
                  color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                ).copyWith(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Hindi Stem
        FormattedQuestionStem(
          text: question.qHindi,
          isDark: isDark,
          style: AppTypography.questionText(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontSize: 17.5,
          ).copyWith(fontWeight: FontWeight.w600, height: 1.6),
        ),

        // Diagram (if present)
        if (MathDiagramWidget.hasDiagram(question.id, question.qHindi)) ...[
          const SizedBox(height: 10),
          MathDiagramWidget(
            questionId: question.id,
            rawText: question.qHindi,
            isDark: isDark,
          ),
        ],

        // English Translation Callout
        if (showEnglishBox) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2A) : const Color(0xFFF8FAFC),
              borderRadius: AppRadius.roundedBase,
              border: Border.all(
                color: isDark ? const Color(0xFF26334D) : const Color(0xFFCBD5E1),
                width: 1.0,
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
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'English Translation',
                      style: AppTypography.labelSmall(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FormattedQuestionStem(
                  text: question.qEnglish!,
                  isDark: isDark,
                  isTranslation: true,
                  style: AppTypography.bodyMedium(
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ).copyWith(fontSize: 15.0, height: 1.5, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
