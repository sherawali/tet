import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_strings.dart';
import '../design_system/app_snack_bar.dart';
import '../database/db_helper.dart';
import '../services/mock_engine.dart';
import '../models/test_session.dart';
import '../models/mock_config.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_state_views.dart';
import '../services/premium_service.dart';
import '../services/exam_service.dart';
import '../services/language_service.dart';
import '../widgets/premium_paywall_modal.dart';

class PyqVaultScreen extends StatefulWidget {
  const PyqVaultScreen({super.key});

  @override
  State<PyqVaultScreen> createState() => _PyqVaultScreenState();
}

class _PyqVaultScreenState extends State<PyqVaultScreen> {
  final DbHelper _db = DbHelper.instance;
  final MockEngine _engine = MockEngine();
  List<Map<String, dynamic>> _forms = [];

  /// Number of questions in the loaded papers (from `paper_forms`).
  int get _paperSize {
    for (final form in _forms) {
      final total = form['total_questions'];
      if (total is int && total > 0) return total;
    }
    return 150;
  }
  bool _isLoading = true;
  String? _generatingFormId;

  @override
  void initState() {
    super.initState();
    _loadPyqForms();
  }

  Future<void> _loadPyqForms() async {
    setState(() => _isLoading = true);
    final paper = ExamService.instance.selectedPaper;
    // Only the past papers of the exam the candidate is preparing for, a
    // CTET push must never see the UTET board papers and the other way.
    final exam = ExamService.instance.isUtet ? 'utet' : 'ctet';
    final forms =
        await _db.getAvailablePaperForms(exam: exam, paper: paper, isPyqOnly: true);
    if (!mounted) return;
    setState(() {
      _forms = forms;
      _isLoading = false;
    });
  }

  Future<void> _startPyqPaper(Map<String, dynamic> form, int index) async {
    // The gate follows the badge: the same `isPaperFree` check decides
    // whether the card shows FREE and whether the tap opens it.
    final String formId = form['id'] as String;
    final isFree = PremiumService.instance.isPaperFree(
      formId: formId,
      index: index,
    );
    final isPremium = PremiumService.instance.hasUnlockedAccess;
    if (!isPremium && !isFree) {
      PremiumPaywallModal.show(context);
      return;
    }

    setState(() => _generatingFormId = formId);
    try {
      final data = await _engine.loadPrebuiltPaper(paperFormId: formId);
      if (!mounted) return;
      setState(() => _generatingFormId = null);

      if (data.questions.isEmpty) {
        AppSnackBar.showError(
          context,
          title: AppStrings.isHindi
              ? 'इस वर्ष के प्रश्न उपलब्ध नहीं हैं'
              : 'No questions available for this year',
        );
        return;
      }

      final cleanId = formId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final config = MockConfig(
        mode: MockMode.pyq,
        seed: 2026100 + index * 999,
        totalQuestions: data.questions.length,
        timeLimitMinutes: _paperSize,
        exam: ExamService.instance.examCode,
      );

      final session = TestSession(
        id: 'pyq_${cleanId}_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        questions: data.questions,
        passages: data.passages,
        paperTitle: AppStrings.formatPaperTitle(form),
        setCode: _extractYearLabel(form),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExamService.instance.buildExamScreen(session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingFormId = null);
      AppSnackBar.showError(
        context,
        title: AppStrings.loadError(e.toString()),
      );
    }
  }

  String _extractYearLabel(Map<String, dynamic> form) {
    final setCode = form['set_code']?.toString();
    if (setCode != null && setCode.isNotEmpty) return setCode;
    final title = form['title']?.toString() ?? '';
    final examDate = form['exam_date']?.toString() ?? '';
    final m = RegExp(r'(20\d\d)').firstMatch('$title $examDate');
    if (m != null) return m.group(1)!;
    return AppStrings.isHindi ? 'विगत वर्ष' : 'PYQ';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPaper = ExamService.instance.selectedPaper;
    final isPaper2 = currentPaper == 2;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(AppStrings.examPaperLabel),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(isDark)
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.base,
                ),
                children: [
                  // Vault Hero Banner
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    border: BorderSide(color: AppColors.sealGold, width: 1.2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.sealGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_edu_rounded, color: AppColors.sealGold, size: 28),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    AppStrings.pyqVaultSubtitle,
                                    style: AppTypography.titleMedium(
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  AppBadge(
                                    label: AppStrings.isHindi ? 'विगत वर्ष प्रश्न-पत्र' : 'Past Year Papers',
                                    color: AppColors.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                AppStrings.isHindi
                                    ? '${_forms.length} विगत वर्षों के प्रश्न-पत्र सम्पूर्ण हल सहित उपलब्ध हैं।'
                                    : '${_forms.length} Previous year question papers available with solutions.',
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // If Paper 2, show active stream toggle
                  if (isPaper2) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: BorderSide(
                        color: AppColors.sealGold.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.tune_rounded, size: 20, color: AppColors.sealGold),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.streamSwitcherLabel,
                                  style: AppTypography.labelSmall(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                                Text(
                                  // The stream always carries the same
                                  // wording as the rest of the app.
                                  '${ExamService.instance.isMathScienceStream ? AppStrings.streamMathScience : AppStrings.streamSocialStudies} (${AppStrings.streamQuestions(60)})',
                                  style: AppTypography.titleSmall(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.sealGold,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                            ),
                            onPressed: () {
                              final newStream = ExamService.instance.isMathScienceStream
                                  ? AppStream.socialStudies
                                  : AppStream.mathScience;
                              ExamService.instance.setStream(newStream).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                            child: Text(
                              LanguageService.instance.isHindi ? 'विषय वर्ग बदलें ⇄' : 'Change Stream ⇄',
                              style: AppTypography.labelMedium(color: AppColors.sealGold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Official Real PYQ Cards
                  ValueListenableBuilder<bool>(
                    valueListenable: PremiumService.instance.isPremiumUnlocked,
                    builder: (context, isUnlocked, _) {
                      if (_forms.isEmpty) {
                        return _buildEmptyState(isDark, currentPaper);
                      }

                      return Column(
                        children: List.generate(_forms.length, (idx) {
                          final form = _forms[idx];
                          final formId = form['id'] as String;
                          final title = AppStrings.formatPaperTitle(form);
                          final yearBadge = _extractYearLabel(form);
                          final isBusy = _generatingFormId == formId;
                          final isFree = PremiumService.instance.isPaperFree(formId: formId, index: idx);
                          final isLocked = !isFree && !isUnlocked;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.base),
                              border: BorderSide(
                                color: isLocked
                                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                    : AppColors.sealGold.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.darkCardElevated : AppColors.lightBg,
                                          borderRadius: AppRadius.roundedSm,
                                          border: Border.all(
                                            color: isFree ? AppColors.correctGreen : AppColors.sealGold,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            final stampParts = AppStrings.getStampParts(yearBadge);
                                            return Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  stampParts.top,
                                                  style: AppTypography.outfit(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w700,
                                                    color: isFree ? AppColors.correctGreen : AppColors.sealGold,
                                                  ),
                                                ),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    stampParts.bottom,
                                                    style: AppTypography.outfit(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w900,
                                                      color: isFree ? AppColors.correctGreen : AppColors.sealGold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: AppTypography.titleSmall(
                                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                                    ),
                                                  ),
                                                ),
                                                if (isFree)
                                                  AppBadge(
                                                    label: AppStrings.premiumFreeBadge,
                                                    color: AppColors.correctGreen,
                                                    isSolid: true,
                                                  )
                                                else if (isLocked)
                                                  AppBadge(
                                                    label: AppStrings.premiumLockedBadge,
                                                    color: AppColors.sealGold,
                                                    isSolid: true,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: AppSpacing.xs),
                                            Text(
                                              AppStrings.isHindi
                                                  ? '$_paperSize प्रश्न · $_paperSize मिनट · सम्पूर्ण हल सहित'
                                                  : '$_paperSize Questions · $_paperSize Mins · Complete Solutions',
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

                                  // Action Button
                                  AppButton(
                                    label: isBusy
                                        ? (AppStrings.isHindi ? 'पेपर खुल रहा है...' : 'Opening paper...')
                                        : (isLocked
                                            ? (AppStrings.isHindi ? '🔒 $title प्रो पास से अनलॉक करें' : '🔒 Unlock $title with Pro Pass')
                                            : (AppStrings.isHindi ? '📖 $title हल करें' : '📖 Solve $title')),
                                    variant: isLocked
                                        ? AppButtonVariant.outline
                                        : AppButtonVariant.primary,
                                    icon: isLocked ? Icons.lock_rounded : Icons.menu_book_rounded,
                                    isLoading: isBusy,
                                    width: double.infinity,
                                    height: 44,
                                    onPressed: isBusy ? null : () => _startPyqPaper(form, idx),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }

  /// The empty state of this screen.
  Widget _buildEmptyState(bool isDark, int currentPaper) {
    return AppEmptyState(
      icon: Icons.history_toggle_off_rounded,
      accent: AppColors.sealGold,
      title: AppStrings.isHindi
          ? 'पेपर $currentPaper के लिए कोई विगत वर्ष पेपर उपलब्ध नहीं है'
          : 'No previous papers available for Paper $currentPaper',
    );
  }

  /// The loading state of this screen.
  Widget _buildLoadingState(bool isDark) {
    return const AppLoadingState();
  }
}

