import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_strings.dart';
import '../services/mock_engine.dart';
import '../models/test_session.dart';
import '../models/mock_config.dart';
import '../widgets/app_badge.dart';
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
  bool _isLoading = true;
  String? _loadingFormId;

  @override
  void initState() {
    super.initState();
    _loadForms();
  }

  Future<void> _loadForms() async {
    setState(() => _isLoading = true);
    final paper = ExamService.instance.selectedPaper;
    final forms = await _engine.db.getAvailablePaperForms(paper: paper, isPyqOnly: false);
    if (!mounted) return;
    setState(() {
      _forms = forms;
      _isLoading = false;
    });
  }

  Future<void> _startMockPaper(Map<String, dynamic> form, int index) async {
    final isPremium = PremiumService.instance.isPremiumUnlocked.value;
    if (!isPremium && index > 0) {
      PremiumPaywallModal.show(context);
      return;
    }

    final formId = form['id'] as String;
    setState(() => _loadingFormId = formId);

    try {
      final data = await _engine.loadPrebuiltPaper(paperFormId: formId);
      if (!mounted) return;
      setState(() => _loadingFormId = null);

      if (data.questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('इस पेपर के प्रश्न उपलब्ध नहीं हैं')),
        );
        return;
      }

      final config = MockConfig(
        mode: MockMode.predicted,
        seed: 2026100 + index * 777,
        totalQuestions: data.questions.length,
        timeLimitMinutes: 150,
        exam: ExamService.instance.examCode,
      );

      final session = TestSession(
        id: '${formId}_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        questions: data.questions,
        passages: data.passages,
        paperTitle: form['title']?.toString(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.loadError(e.toString()))),
      );
    }
  }

  String _formatSetCode(Map<String, dynamic> form, int index) {
    final rawSet = form['set_code']?.toString().toUpperCase() ?? '';
    if (rawSet.isNotEmpty) {
      return rawSet;
    }
    return 'M-${(index + 1).toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPaper = ExamService.instance.selectedPaper;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text('${AppStrings.mockSeriesTitle} (Paper $currentPaper)'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Series Header Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.sealGold,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.sealGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars_rounded, color: AppColors.sealGold, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'प्रामाणिक बने-बनाए टेस्ट पेपर्स',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_forms.length} सम्पूर्ण 150-प्रश्नों वाले मॉक पेपर्स उपलब्ध हैं।',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: [
                                  AppBadge(label: 'Verified Board Key', color: AppColors.sealGold),
                                  const AppBadge(label: '150 Qs Standard', color: AppColors.cdp),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pre-built Mock Booklet Cards
                  ValueListenableBuilder<bool>(
                    valueListenable: PremiumService.instance.isPremiumUnlocked,
                    builder: (context, isUnlocked, _) {
                      if (_forms.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'कोई मॉक पेपर उपलब्ध नहीं है',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: List.generate(_forms.length, (idx) {
                          final form = _forms[idx];
                          final formId = form['id'] as String;
                          final title = form['title'] as String? ?? 'Mock Paper ${idx + 1}';
                          final setLabel = _formatSetCode(form, idx);
                          final isBusy = _loadingFormId == formId;
                          final isFree = PremiumService.instance.isPaperFree(formId: formId, index: idx);
                          final isLocked = !isFree && !isUnlocked;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isLocked
                                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                    : AppColors.sealGold.withValues(alpha: 0.6),
                                width: 1.0,
                              ),
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
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isFree ? AppColors.correctGreen : AppColors.sealGold,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          setLabel,
                                          style: TextStyle(
                                            fontSize: setLabel.length > 3 ? 12 : 15,
                                            fontWeight: FontWeight.bold,
                                            color: isFree ? AppColors.correctGreen : AppColors.sealGold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.bold,
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
                                          const SizedBox(height: 3),
                                          Text(
                                            '150 प्रश्न · 150 मिनट · पूर्ण प्रामाणिक मॉक',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Action Button
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isLocked
                                        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))
                                        : (isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9)),
                                    foregroundColor: isLocked
                                        ? AppColors.sealGold
                                        : (isDark ? AppColors.sealGoldLight : AppColors.primary),
                                    minimumSize: const Size(double.infinity, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: BorderSide(
                                        color: isLocked
                                            ? AppColors.sealGold.withValues(alpha: 0.5)
                                            : (isDark ? AppColors.sealGoldLight : AppColors.primary),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                  onPressed: isBusy ? null : () => _startMockPaper(form, idx),
                                  icon: isBusy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Icon(
                                          isLocked ? Icons.lock_rounded : Icons.menu_book_rounded,
                                          size: 18,
                                          color: isLocked ? AppColors.sealGold : null,
                                        ),
                                  label: Text(
                                    isBusy
                                        ? 'पेपर खुल रहा है...'
                                        : (isLocked
                                            ? '🔒 $title पास से अनलॉक करें'
                                            : '📖 $title हल करें'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
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
}
