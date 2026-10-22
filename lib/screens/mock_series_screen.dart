import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_strings.dart';
import '../design_system/app_snack_bar.dart';
import '../services/mock_engine.dart';
import '../models/test_session.dart';
import '../models/mock_config.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_state_views.dart';
import '../services/premium_service.dart';
import '../services/exam_service.dart';
import '../widgets/premium_paywall_modal.dart';

class MockSeriesScreen extends StatefulWidget {
  const MockSeriesScreen({super.key});

  @override
  State<MockSeriesScreen> createState() => _MockSeriesScreenState();
}

class _MockSeriesScreenState extends State<MockSeriesScreen> {
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
  /// true when the list holds the mock papers, false when it
  /// falls back to the board papers of the same level.
  bool _onlyMocks = true;
  String? _loadingFormId;

  @override
  void initState() {
    super.initState();
    _loadForms();
  }

  Future<void> _loadForms() async {
    setState(() => _isLoading = true);
    final paper = ExamService.instance.selectedPaper;
    // The list belongs to the exam that is selected, otherwise the UTET and
    // the CTET mocks would be mixed under one heading.
    final examName = ExamService.instance.isUtet ? 'utet' : 'ctet';
    var forms = await _engine.db.getAvailablePaperForms(
      exam: examName,
      paper: paper,
      isPyqOnly: false,
    );
    // UTET Paper-2 has no mock papers, only the board papers.  Rather than
    // showing an empty screen, every paper of the level is listed.
    var onlyMocks = true;
    if (forms.isEmpty) {
      onlyMocks = false;
      forms = await _engine.db.getAvailablePaperForms(
        exam: examName,
        paper: paper,
      );
    }
    if (!mounted) return;
    setState(() {
      _forms = forms;
      _onlyMocks = onlyMocks;
      _isLoading = false;
    });
  }

  Future<void> _startMockPaper(Map<String, dynamic> form, int index) async {
    // The gate follows the badge: the same `isPaperFree` check decides
    // whether the card shows FREE and whether the tap opens it.
    final String formId = form['id'] as String;
    final isFree = PremiumService.instance.isPaperFree(
      formId: formId,
      index: index,
    );
    final isPremium = PremiumService.instance.isPremiumUnlocked.value;
    if (!isPremium && !isFree) {
      PremiumPaywallModal.show(context);
      return;
    }

    setState(() => _loadingFormId = formId);

    try {
      final data = await _engine.loadPrebuiltPaper(paperFormId: formId);
      if (!mounted) return;
      setState(() => _loadingFormId = null);

      if (data.questions.isEmpty) {
        AppSnackBar.showError(
          context,
          title: 'इस पेपर के प्रश्न उपलब्ध नहीं हैं',
        );
        return;
      }

      final config = MockConfig(
        mode: MockMode.predicted,
        seed: 2026100 + index * 777,
        totalQuestions: data.questions.length,
        timeLimitMinutes: _paperSize,
        exam: ExamService.instance.examCode,
      );

      final session = TestSession(
        id: '${formId}_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        questions: data.questions,
        passages: data.passages,
        paperTitle: AppStrings.formatPaperTitle(form),
        setCode: _formatSetCode(form, index),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExamService.instance.buildExamScreen(session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFormId = null);
      AppSnackBar.showError(
        context,
        title: AppStrings.loadError(e.toString()),
      );
    }
  }

  String _formatSetCode(Map<String, dynamic> form, int index) {
    final rawSet = form['set_code']?.toString() ?? '';
    if (rawSet.isNotEmpty) {
      return AppStrings.formatSetBadge(rawSet);
    }
    return AppStrings.formatSetBadge('MOCK ${(index + 1).toString().padLeft(2, "0")}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  // Series Header Banner
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    border: BorderSide(color: AppColors.sealGold, width: 1.2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.sealGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars_rounded, color: AppColors.sealGold, size: 28),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _onlyMocks
                                    ? AppStrings.verifiedTestPapersHeading
                                    : AppStrings.allPapersHeading,
                                style: AppTypography.titleMedium(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                AppStrings.papersCountDesc(_forms.length, _paperSize),
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  AppBadge(label: 'Verified Board Key', color: AppColors.sealGold),
                                  AppBadge(
                                    label: AppStrings.isHindi
                                        ? '$_paperSize प्रश्न मानक'
                                        : '$_paperSize Qs Standard',
                                    color: AppColors.cdp,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Pre-built Mock Booklet Cards
                  ValueListenableBuilder<bool>(
                    valueListenable: PremiumService.instance.isPremiumUnlocked,
                    builder: (context, isUnlocked, _) {
                      if (_forms.isEmpty) {
                        return _buildEmptyState(isDark);
                      }

                      return Column(
                        children: List.generate(_forms.length, (idx) {
                          final form = _forms[idx];
                          final formId = form['id'] as String;
                          final title = AppStrings.formatPaperTitle(form);
                          final rawSet = form['set_code']?.toString() ?? 'MOCK ${(idx + 1).toString().padLeft(2, "0")}';
                          final stampParts = AppStrings.getStampParts(rawSet);
                          final isBusy = _loadingFormId == formId;
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
                                        child: Column(
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
                                              _onlyMocks
                                          ? AppStrings.mockPaperSubtitle(_paperSize)
                                          : AppStrings.boardPaperSubtitle(_paperSize),
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
                                    onPressed: isBusy ? null : () => _startMockPaper(form, idx),
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
  Widget _buildEmptyState(bool isDark) {
    return AppEmptyState(
      icon: Icons.inbox_rounded,
      accent: AppColors.sealGold,
      title: AppStrings.isHindi ? 'कोई मॉक पेपर उपलब्ध नहीं है' : 'No mock papers available',
    );
  }

  /// The loading state of this screen.
  Widget _buildLoadingState(bool isDark) {
    return const AppLoadingState();
  }
}

