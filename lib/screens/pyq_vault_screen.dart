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

class PyqVaultScreen extends StatefulWidget {
  const PyqVaultScreen({super.key});

  @override
  State<PyqVaultScreen> createState() => _PyqVaultScreenState();
}

class _PyqVaultScreenState extends State<PyqVaultScreen> {
  final DbHelper _db = DbHelper.instance;
  final MockEngine _engine = MockEngine();
  List<Map<String, dynamic>> _forms = [];
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
    final forms = await _db.getAvailablePaperForms(paper: paper, isPyqOnly: true);
    if (!mounted) return;
    setState(() {
      _forms = forms;
      _isLoading = false;
    });
  }

  Future<void> _startPyqPaper(Map<String, dynamic> form, int index) async {
    final isPremium = PremiumService.instance.isPremiumUnlocked.value;
    if (!isPremium && index > 0) {
      PremiumPaywallModal.show(context);
      return;
    }

    final formId = form['id'] as String;
    setState(() => _generatingFormId = formId);
    try {
      final data = await _engine.loadPrebuiltPaper(paperFormId: formId);
      if (!mounted) return;
      setState(() => _generatingFormId = null);

      if (data.questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('इस वर्ष के प्रश्न उपलब्ध नहीं हैं')),
        );
        return;
      }

      final cleanId = formId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final config = MockConfig(
        mode: MockMode.pyq,
        seed: 2026100 + index * 999,
        totalQuestions: data.questions.length,
        timeLimitMinutes: 150,
        exam: ExamService.instance.examCode,
      );

      final session = TestSession(
        id: 'pyq_${cleanId}_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        questions: data.questions,
        passages: data.passages,
        paperTitle: form['title']?.toString(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.loadError(e.toString()))),
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
    return 'PYQ';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPaper = ExamService.instance.selectedPaper;
    final isPaper2 = currentPaper == 2;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text('${AppStrings.pyqVaultTitle} (Paper $currentPaper)'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.sealGold))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Vault Hero Banner
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.sealGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_edu_rounded, color: AppColors.sealGold, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    AppStrings.pyqVaultTitle,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  AppBadge(
                                    label: AppStrings.isHindi ? 'विगत वर्ष प्रश्न-पत्र' : 'Past Year Papers',
                                    color: AppColors.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppStrings.isHindi
                                    ? '${_forms.length} विगत वर्षों के प्रश्न-पत्र सम्पूर्ण हल सहित उपलब्ध हैं।'
                                    : '${_forms.length} Previous year question papers available with solutions.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                  height: 1.35,
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.sealGold.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 20, color: AppColors.sealGold),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'विषय स्ट्रीम (Section IV)',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  ExamService.instance.isMathScienceStream
                                      ? 'गणित एवं विज्ञान (60 प्रश्न)'
                                      : 'सामाजिक अध्ययन (60 प्रश्न)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.sealGold,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            onPressed: () {
                              final newStream = ExamService.instance.isMathScienceStream
                                  ? AppStream.socialStudies
                                  : AppStream.mathScience;
                              ExamService.instance.setStream(newStream).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                            child: const Text('स्ट्रीम बदलें ⇄', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Official Real PYQ Cards
                  ValueListenableBuilder<bool>(
                    valueListenable: PremiumService.instance.isPremiumUnlocked,
                    builder: (context, isUnlocked, _) {
                      if (_forms.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.sealGold),
                              const SizedBox(height: 12),
                              Text(
                                'पेपर $currentPaper के लिए कोई PYQ उपलब्ध नहीं है',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: List.generate(_forms.length, (idx) {
                          final form = _forms[idx];
                          final formId = form['id'] as String;
                          final title = form['title'] as String? ?? (AppStrings.isHindi ? 'विगत वर्ष प्रश्न-पत्र' : 'Previous Year Paper');
                          final yearBadge = _extractYearLabel(form);
                          final isBusy = _generatingFormId == formId;
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
                                          yearBadge,
                                          style: TextStyle(
                                            fontSize: yearBadge.length > 3 ? 12 : 14,
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
                                            AppStrings.isHindi
                                                ? '150 प्रश्न · 150 मिनट · सम्पूर्ण हल सहित'
                                                : '150 Questions · 150 Mins · Complete Solutions',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
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
                                  onPressed: isBusy ? null : () => _startPyqPaper(form, idx),
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
