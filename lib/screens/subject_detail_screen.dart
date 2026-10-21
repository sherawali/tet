import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_strings.dart';
import '../database/db_helper.dart';
import '../services/mock_engine.dart';
import '../models/test_session.dart';
import '../models/mock_config.dart';
import '../widgets/app_badge.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.loadError(e.toString()))),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('इस टॉपिक के प्रश्न उपलब्ध नहीं हैं')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.loadError(e.toString()))),
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
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isDark ? AppColors.darkCard : widget.sectionColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.sealGold))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // Hub Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.sectionColor.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: widget.sectionColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.school_rounded, color: widget.sectionColor, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.sectionName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppStrings.subjectPracticeHubDesc(_totalCount),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Fresh Practice Button
                        ValueListenableBuilder<bool>(
                          valueListenable: PremiumService.instance.isPremiumUnlocked,
                          builder: (context, isUnlocked, _) {
                            return ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isUnlocked ? widget.sectionColor : const Color(0xFF1E293B),
                                foregroundColor: isUnlocked ? Colors.white : AppColors.sealGold,
                                minimumSize: const Size(double.infinity, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(
                                    color: isUnlocked ? widget.sectionColor : AppColors.sealGold,
                                  ),
                                ),
                              ),
                              onPressed: _busyItem != null ? null : () => _startSubjectPractice(999, isFresh: true),
                              icon: _busyItem == 'set_999'
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(isUnlocked ? Icons.bolt_rounded : Icons.lock_rounded, size: 20),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _busyItem == 'set_999'
                                      ? 'सेट बन रहा है...'
                                      : (isUnlocked
                                          ? '⚡ फ्रेश 30-प्रश्न सेट जनरेट करें'
                                          : '🔒 फ्रेश 30-प्रश्न सेट (पास से अनलॉक करें)'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Practice Sets (SET-01 to SET-07)
                  Text(
                    'अभ्यास सेट्स (${BankFacts.subjectSetQuestions} प्रश्न · ${BankFacts.subjectSetQuestions} मिनट)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

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

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isLocked
                                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                    : widget.sectionColor.withValues(alpha: 0.5),
                                width: 1.0,
                              ),
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
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$setNum',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isFree ? AppColors.correctGreen : widget.sectionColor,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 6,
                                              runSpacing: 2,
                                              children: [
                                                Text(
                                                  AppStrings.subjectSetTitle(setNum),
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.bold,
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
                                            const SizedBox(height: 2),
                                            Text(
                                              AppStrings.subjectCardTime,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isLocked
                                        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                                        : widget.sectionColor,
                                    foregroundColor: isLocked ? AppColors.sealGold : Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    minimumSize: const Size(64, 34),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      side: BorderSide(
                                        color: isLocked ? AppColors.sealGold.withValues(alpha: 0.5) : widget.sectionColor,
                                      ),
                                    ),
                                  ),
                                  onPressed: isBusy ? null : () => _startSubjectPractice(setNum),
                                  child: isBusy
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : (isLocked
                                          ? const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.lock_rounded, size: 15, color: AppColors.sealGold),
                                                SizedBox(width: 4),
                                                Text(
                                                  'अनलॉक',
                                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.sealGold),
                                                ),
                                              ],
                                            )
                                          : const Text(
                                              'हल करें',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            )),
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Topic-wise Focused Drills
                  if (_topicCounts.isNotEmpty) ...[
                    Text(
                      AppStrings.topicsDrillHeading,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ValueListenableBuilder<bool>(
                      valueListenable: PremiumService.instance.isPremiumUnlocked,
                      builder: (context, isUnlocked, _) {
                        return Column(
                          children: _topicCounts.entries.map((e) {
                            final topic = e.key;
                            final count = e.value;
                            final isBusy = _busyItem == 'topic_$topic';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          topic,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppStrings.topicDrillSub(count),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isUnlocked ? widget.sectionColor : AppColors.sealGold,
                                      side: BorderSide(
                                        color: isUnlocked ? widget.sectionColor : AppColors.sealGold,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: const Size(64, 32),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    onPressed: isBusy ? null : () => _startTopicDrill(topic, count),
                                    icon: isBusy
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 1.8),
                                          )
                                        : Icon(
                                            isUnlocked ? Icons.play_arrow_rounded : Icons.lock_rounded,
                                            size: 16,
                                          ),
                                    label: Text(
                                      isBusy ? '...' : (isUnlocked ? 'ड्रिल' : 'अनलॉक'),
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}
