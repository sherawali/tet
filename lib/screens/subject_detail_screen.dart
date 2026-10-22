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
import '../widgets/premium_paywall_modal.dart';
import '../services/bank_facts.dart';

class SubjectDetailScreen extends StatefulWidget {
  final String section;
  final String sectionName;
  final Color sectionColor;

  const SubjectDetailScreen({
    super.key,
    required this.section,
    required this.sectionName,
    required this.sectionColor,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final DbHelper _db = DbHelper.instance;
  final MockEngine _engine = MockEngine();
  int _totalCount = 0;
  Map<String, int> _topicCounts = {};
  bool _isLoading = true;
  String? _busyItem;

  /// The one card padding of this file.
  static const EdgeInsets _cardPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.base,
    vertical: AppSpacing.md,
  );

  @override
  void initState() {
    super.initState();
    _loadSectionData();
  }

  Future<void> _loadSectionData() async {
    setState(() => _isLoading = true);
    final secCounts = await _db.getSectionCounts(ExamService.instance.examCode);
    final topics = await _db.getTopicCountsForSection(widget.section, ExamService.instance.examCode);
    if (!mounted) return;
    setState(() {
      _totalCount = secCounts[widget.section] ?? 0;
      _topicCounts = topics;
      _isLoading = false;
    });
  }

  Future<void> _startSubjectPractice(int setNumber, {bool isFresh = false}) async {
    final isPremium = PremiumService.instance.isPremiumUnlocked.value;
    if (!isPremium && (setNumber > 1 || isFresh)) {
      PremiumPaywallModal.show(context);
      return;
    }

    final examCode = ExamService.instance.examCode;
    final busyKey = 'set_$setNumber';
    setState(() => _busyItem = busyKey);
    try {
      final data = isFresh
          ? await _engine.generateMock(
              MockConfig(
                mode: MockMode.mixed,
                sectionFilter: widget.section,
                seed: DateTime.now().millisecondsSinceEpoch,
                totalQuestions: 30,
                timeLimitMinutes: 30,
                exam: examCode,
              ),
            )
          : await _engine.generateSubjectSet(
              section: widget.section,
              setNumber: setNumber,
              exam: examCode,
            );

      if (!mounted) return;
      setState(() => _busyItem = null);

      final config = MockConfig(
        mode: MockMode.mixed,
        sectionFilter: widget.section,
        seed: isFresh ? DateTime.now().millisecondsSinceEpoch : (10000 + setNumber * 433),
        totalQuestions: data.questions.length,
        timeLimitMinutes: 30,
        exam: examCode,
      );

      final session = TestSession(
        id: '${widget.section}_set_${setNumber}_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        questions: data.questions,
        passages: data.passages,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExamService.instance.buildExamScreen(session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyItem = null);
      AppSnackBar.showError(
        context,
        title: AppStrings.loadError(e.toString()),
      );
    }
  }

  Future<void> _startTopicDrill(String topicName, int count) async {
    final isPremium = PremiumService.instance.isPremiumUnlocked.value;
    if (!isPremium) {
      PremiumPaywallModal.show(context);
      return;
    }

    final busyKey = 'topic_$topicName';
    setState(() => _busyItem = busyKey);
    try {
      final data = await _engine.generateTopicDrill(
        section: widget.section,
        topicName: topicName,
        exam: ExamService.instance.examCode,
      );

      if (!mounted) return;
      setState(() => _busyItem = null);

      if (data.questions.isEmpty) {
        AppSnackBar.showError(
          context,
          title: 'इस टॉपिक के प्रश्न उपलब्ध नहीं हैं',
        );
        return;
      }

      final config = MockConfig(
        mode: MockMode.mixed,
        sectionFilter: widget.section,
        seed: DateTime.now().millisecondsSinceEpoch,
        totalQuestions: data.questions.length,
        timeLimitMinutes: (data.questions.length * 1.5).ceil().clamp(10, 60),
        exam: ExamService.instance.examCode,
      );

      final session = TestSession(
        id: 'drill_${widget.section}_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        questions: data.questions,
        passages: data.passages,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExamService.instance.buildExamScreen(session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyItem = null);
      AppSnackBar.showError(
        context,
        title: AppStrings.loadError(e.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          AppStrings.subjectPracticeHubTitle(widget.sectionName),
        ),
        backgroundColor: isDark ? AppColors.darkCard : widget.sectionColor,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(isDark)
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.base,
                  AppSpacing.base,
                  AppSpacing.xxl,
                ),
                children: [
                  // Hub Banner
                  AppCard(
                    padding: _cardPadding,
                    border: BorderSide(
                      color: widget.sectionColor.withValues(alpha: 0.6),
                      width: 1.2,
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
                                color: widget.sectionColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.school_rounded, color: widget.sectionColor, size: 26),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.sectionName,
                                    style: AppTypography.titleMedium(
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    AppStrings.subjectPracticeHubDesc(_totalCount),
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

                        // Fresh Practice Button
                        ValueListenableBuilder<bool>(
                          valueListenable: PremiumService.instance.isPremiumUnlocked,
                          builder: (context, isUnlocked, _) {
                            return AppButton(
                              label: _busyItem == 'set_999'
                                  ? AppStrings.buildingSet
                                  : (isUnlocked
                                      ? AppStrings.freshSetLocked
                                      : '🔒 फ्रेश 30-प्रश्न सेट (पास से अनलॉक करें)'),
                              variant: isUnlocked
                                  ? AppButtonVariant.primary
                                  : AppButtonVariant.outline,
                              icon: isUnlocked ? Icons.bolt_rounded : Icons.lock_rounded,
                              isLoading: _busyItem == 'set_999',
                              width: double.infinity,
                              onPressed: _busyItem != null
                                  ? null
                                  : () => _startSubjectPractice(999, isFresh: true),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Section 1: Practice Sets (SET-01 to SET-07)
                  Text(
                    AppStrings.practiceSetsHeading(BankFacts.subjectSetQuestions),
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  ValueListenableBuilder<bool>(
                    valueListenable: PremiumService.instance.isPremiumUnlocked,
                    builder: (context, isUnlocked, _) {
                      // Dynamically calculate how many 30-question sets this section can provide (minimum 7, up to 20)
                      final availableSets = (_totalCount > 0 ? (_totalCount ~/ 30).clamp(7, 20) : 7);
                      return Column(
                        children: List.generate(availableSets, (idx) {
                          final setNum = idx + 1;
                          final isBusy = _busyItem == 'set_$setNum';
                          final isFree = PremiumService.instance.isPaperFree(index: idx);
                          final isLocked = !isFree && !isUnlocked;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: _cardPadding,
                              border: BorderSide(
                                color: isLocked
                                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                    : widget.sectionColor.withValues(alpha: 0.5),
                                width: 1.2,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: isFree
                                                ? AppColors.correctGreen.withValues(alpha: 0.15)
                                                : widget.sectionColor.withValues(alpha: 0.12),
                                            borderRadius: AppRadius.roundedSm,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$setNum',
                                              style: AppTypography.labelMedium(
                                                color: isFree ? AppColors.correctGreen : widget.sectionColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: AppSpacing.xs,
                                                runSpacing: AppSpacing.xs,
                                                children: [
                                                  Text(
                                                    AppStrings.subjectSetTitle(setNum),
                                                    style: AppTypography.titleSmall(
                                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                                                AppStrings.subjectCardTime,
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
                                  const SizedBox(width: AppSpacing.sm),
                                  AppButton(
                                    label: isLocked ? AppStrings.unlockLabel : AppStrings.solveLabel,
                                    variant: isLocked
                                        ? AppButtonVariant.outline
                                        : AppButtonVariant.primary,
                                    icon: isLocked ? Icons.lock_rounded : null,
                                    isLoading: isBusy,
                                    width: isLocked ? 120 : 96,
                                    height: 38,
                                    onPressed: isBusy ? null : () => _startSubjectPractice(setNum),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Section 2: Topic-wise Focused Drills
                  if (_topicCounts.isNotEmpty) ...[
                    Text(
                      AppStrings.topicsDrillHeading,
                      style: AppTypography.titleMedium(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    ValueListenableBuilder<bool>(
                      valueListenable: PremiumService.instance.isPremiumUnlocked,
                      builder: (context, isUnlocked, _) {
                        return Column(
                          children: _topicCounts.entries.map((e) {
                            final topic = e.key;
                            final count = e.value;
                            final isBusy = _busyItem == 'topic_$topic';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AppCard(
                                padding: _cardPadding,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            topic,
                                            style: AppTypography.titleSmall(
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            AppStrings.topicDrillSub(count),
                                            style: AppTypography.bodySmall(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    AppButton(
                                      label: isUnlocked ? AppStrings.drillLabel : AppStrings.unlockLabel,
                                      variant: isUnlocked
                                          ? AppButtonVariant.primary
                                          : AppButtonVariant.outline,
                                      icon: isUnlocked
                                          ? Icons.play_arrow_rounded
                                          : Icons.lock_rounded,
                                      isLoading: isBusy,
                                      width: 104,
                                      height: 38,
                                      onPressed: isBusy ? null : () => _startTopicDrill(topic, count),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
      ),
    );
  }

  /// The loading state of this screen.
  Widget _buildLoadingState(bool isDark) {
    return const AppLoadingState();
  }
}
