import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_snack_bar.dart';
import '../design_system/app_typography.dart';
import '../models/question.dart';
import '../database/db_helper.dart';
import '../services/github_report_service.dart';
import '../services/language_service.dart';
import '../design_system/app_motion.dart';
import '../design_system/app_sheet.dart';

/// Ultra-Premium Question Report Bottom Sheet
/// Matches the authentic Examination Authority & Obsidian Slate luxury aesthetic.
class QuestionReportSheet extends StatefulWidget {
  final Question question;
  final int questionNumber;
  final String? paperTitle;
  final int? userAnswer;
  final VoidCallback? onReportSubmitted;

  const QuestionReportSheet({
    super.key,
    required this.question,
    required this.questionNumber,
    this.paperTitle,
    this.userAnswer,
    this.onReportSubmitted,
  });

  /// Static helper to show this sheet from any screen
  static Future<void> show(
    BuildContext context, {
    required Question question,
    required int questionNumber,
    String? paperTitle,
    int? userAnswer,
    VoidCallback? onReportSubmitted,
  }) {
    HapticFeedback.mediumImpact();
    return AppSheet.show(
      context,
      builder: (ctx) => QuestionReportSheet(
        question: question,
        questionNumber: questionNumber,
        paperTitle: paperTitle,
        userAnswer: userAnswer,
        onReportSubmitted: onReportSubmitted,
      ),
    );
  }

  @override
  State<QuestionReportSheet> createState() => _QuestionReportSheetState();
}

class _QuestionReportSheetState extends State<QuestionReportSheet> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _scrollController = ScrollController();
  String _selectedReason = 'wrong_answer';
  String? _suggestedOption;
  bool _isSubmitting = false;
  bool _hasAlreadyReported = false;

  List<Map<String, dynamic>> get _reasons {
    final isHi = LanguageService.instance.isHindi;
    return [
      {
        'id': 'wrong_answer',
        'title': isHi ? 'उत्तर कुंजी गलत है' : 'Wrong Answer Key',
        'subtitle': isHi ? 'दी गई उत्तर कुंजी या सही विकल्प गलत है' : 'Given answer key or correct option is incorrect',
        'icon': Icons.cancel_outlined,
        'color': AppColors.danger,
      },
      {
        'id': 'incomplete',
        'title': isHi ? 'अधूरा या अस्पष्ट प्रश्न' : 'Incomplete or Unclear Question',
        'subtitle': isHi ? 'प्रश्न का वाक्य अधूरा है या कोई विकल्प छूटा हुआ है' : 'Question text is incomplete or option missing',
        'icon': Icons.help_outline_rounded,
        'color': AppColors.goldBright,
      },
      {
        'id': 'typo',
        'title': isHi ? 'अनुवाद या वर्तनी अशुद्धि' : 'Translation or Typo Error',
        'subtitle': isHi ? 'अनुवाद में गड़बड़ी या व्याकरण अशुद्धि है' : 'Grammar error or translation issue',
        'icon': Icons.translate_rounded,
        'color': AppColors.accentBright,
      },
      {
        'id': 'formula_diagram',
        'title': isHi ? 'सूत्र या चित्र समस्या' : 'Formula or Diagram Issue',
        'subtitle': isHi ? 'गणितीय सूत्र, समीकरण या चित्र स्पष्ट नहीं है' : 'Math formula or diagram not rendering clearly',
        'icon': Icons.functions_rounded,
        'color': AppColors.violet,
      },
      {
        'id': 'other',
        'title': isHi ? 'अन्य समस्या' : 'Other Issue',
        'subtitle': isHi ? 'पाठ्यक्रम से बाहर या अन्य कोई त्रुटि' : 'Out of syllabus or other issues',
        'icon': Icons.error_outline_rounded,
        'color': AppColors.success,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _commentFocusNode.addListener(_onFocusChange);
    _checkPreviousReport();
  }

  void _onFocusChange() {
    if (_commentFocusNode.hasFocus) {
      Future.delayed(AppMotion.slow, () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: AppMotion.slow,
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _checkPreviousReport() async {
    final reported = await DbHelper.instance.hasQuestionBeenReported(
      questionId: widget.question.id,
      paperFormId: widget.paperTitle,
    );
    if (mounted && reported) {
      setState(() => _hasAlreadyReported = true);
    }
  }

  @override
  void dispose() {
    _commentFocusNode.removeListener(_onFocusChange);
    _commentFocusNode.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Opens the secure GitHub API Key / Token setup dialog
  Future<void> _showApiKeySetupDialog(BuildContext context) async {
    HapticFeedback.lightImpact();
    final isConfigured = await GitHubReportService.instance.hasConfiguredToken();
    final tokenController = TextEditingController();
    bool isObscured = true;
    bool isTesting = false;
    String statusMsg = isConfigured
        ? '✅ GitHub कुंजी सक्रिय है (एन्क्रिप्टेड सुरक्षित)'
        : '⚠️ कोई कुंजी सक्रिय नहीं — रिपोर्ट ऑफ़लाइन सुरक्षित रहेंगी';

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? AppColors.primaryLight : AppColors.darkTextPrimary;
          final textColor = isDark ? AppColors.darkTextPrimary : AppColors.primary;

          return AlertDialog(
            backgroundColor: isDark ? AppColors.primary : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.roundedLg,
              side: const BorderSide(color: AppColors.goldBright, width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.goldBright.withValues(alpha: 0.15),
                    borderRadius: AppRadius.roundedMd,
                  ),
                  child: const Icon(Icons.key_rounded, color: AppColors.goldBright, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'GitHub कुंजी सेटअप',
                    style: AppTypography.titleLarge(color: textColor),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.instance.isHindi ? 'छात्रों द्वारा रिपोर्ट की गई समस्याएं सीधे GitHub Issues पर दर्ज होंगी। कुंजी (Key) ऐप में XOR Base64 मानक से 100% एन्क्रिप्ट होकर सुरक्षित रहती है।' : 'Student reports go straight to GitHub Issues. The key is XOR Base64 encrypted in the app at 100%.',
                    style: AppTypography.caption(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: AppRadius.roundedSm,
                      border: Border.all(
                        color: isConfigured ? AppColors.success : AppColors.goldBright,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      statusMsg,
                      style: AppTypography.labelMedium(color: isConfigured ? AppColors.success : AppColors.goldBright),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    LanguageService.instance.isHindi ? 'नया सुरक्षा टोकन (Personal Access Token) पेस्ट करें:' : 'Paste a new Personal Access Token:',
                    style: AppTypography.labelMedium(color: textColor),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: tokenController,
                    obscureText: isObscured,
                    style: AppTypography.courierPrime(
                      fontSize: 13,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ghp_... या github_pat_...',
                      hintStyle: AppTypography.courierPrime(
                        fontSize: 12,
                        color: AppColors.lightTextMuted,
                      ),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscured ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                        ),
                        onPressed: () => setDlgState(() => isObscured = !isObscured),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (isConfigured)
                TextButton(
                  onPressed: () async {
                    await GitHubReportService.instance.clearCustomToken();
                    setDlgState(() {
                      statusMsg = LanguageService.instance.isHindi ? 'टोकन हटा दिया गया (अब ऑफ़लाइन)' : 'Token removed (offline now)';
                    });
                    if (context.mounted) {
                      AppSnackBar.showSuccess(
                        context,
                        title: LanguageService.instance.isHindi
                            ? 'टोकन हटाया गया'
                            : 'Token removed',
                        message: LanguageService.instance.isHindi
                            ? 'GitHub टोकन हटा दिया गया है।'
                            : 'The GitHub token has been removed.',
                      );
                    }
                  },
                  child: Text(
                    LanguageService.instance.isHindi ? 'हटाएं' : 'Remove',
                    style: AppTypography.outfit(color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(LanguageService.instance.isHindi ? 'रद्द करें' : 'Cancel', style: AppTypography.outfit(color: AppColors.lightTextMuted)),
              ),
              ElevatedButton(
                onPressed: isTesting
                    ? null
                    : () async {
                        final raw = tokenController.text.trim();
                        if (raw.isEmpty) {
                          setDlgState(() => statusMsg = LanguageService.instance.isHindi ? '❌ कृपया टोकन दर्ज करें' : '❌ Please enter a token');
                          return;
                        }
                        setDlgState(() {
                          isTesting = true;
                          statusMsg = LanguageService.instance.isHindi ? 'सत्यापन हो रहा है...' : 'Verifying...';
                        });

                        final isValid = await GitHubReportService.instance.verifyToken(raw);
                        if (!isValid) {
                          setDlgState(() {
                            isTesting = false;
                            statusMsg = '❌ अमान्य टोकन या नेटवर्क त्रुटि। कृपया जांचें।';
                          });
                          return;
                        }

                        // Encrypt and save
                        await GitHubReportService.instance.setCustomEncryptedToken(raw);
                        // Sync pending
                        final synced = await GitHubReportService.instance.syncPendingReports();

                        setDlgState(() {
                          isTesting = false;
                          statusMsg = '✅ टोकन सफलतापूर्वक एन्क्रिप्ट और सक्रिय हुआ!';
                        });

                        if (context.mounted) {
                          Navigator.pop(dlgCtx);
                          AppSnackBar.showSuccess(
                            context,
                            title: LanguageService.instance.isHindi ? 'GitHub कुंजी सक्रिय हो गई!' : 'GitHub key active!',
                            message: LanguageService.instance.isHindi ? 'कुंजी एन्क्रिप्ट हो गई। $synced बाकी रिपोर्ट सिंक हो गईं।' : 'Key encrypted. $synced pending reports have synced.',
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldBright,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                ),
                child: isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkTextPrimary),
                      )
                    : Text(
                        LanguageService.instance.isHindi ? 'एन्क्रिप्ट और सहेजें' : 'Encrypt and save',
                        style: AppTypography.outfit(fontWeight: FontWeight.bold, color: AppColors.lightTextPrimary),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final q = widget.question;
      final qStem = q.qHindi.trim().isNotEmpty ? q.qHindi.trim() : (q.qEnglish ?? '');
      final truncatedStem = qStem.length > 200 ? '${qStem.substring(0, 200)}...' : qStem;

      final reportId = await DbHelper.instance.saveQuestionReport(
        questionId: q.id,
        paperFormId: widget.paperTitle ?? 'Practice Set',
        questionNumber: widget.questionNumber,
        reason: _selectedReason,
        comment: _commentController.text.trim(),
        suggestedOption: _suggestedOption,
        questionStem: truncatedStem,
        userAnswer: widget.userAnswer,
        correctAnswer: q.answer,
        status: 'submitted',
      );

      final reportCode = 'REP-${DateTime.now().year}-${reportId.toString().padLeft(4, '0')}';

      // Asynchronously post to GitHub Issues (if online and token configured)
      unawaited(
        GitHubReportService.instance.sendReportToGitHub(
          reportId: reportId,
          questionId: q.id,
          questionNumber: widget.questionNumber,
          paperTitle: widget.paperTitle ?? 'Practice Set',
          reason: _selectedReason,
          comment: _commentController.text.trim(),
          suggestedOption: _suggestedOption,
          questionStem: truncatedStem,
          userAnswer: widget.userAnswer,
          correctAnswer: q.answer,
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onReportSubmitted?.call();

        AppSnackBar.showReportSuccess(
          context,
          questionNumber: widget.questionNumber,
          reportCode: reportCode,
          title: LanguageService.instance.isHindi ? 'रिपोर्ट दर्ज कर ली गई है' : 'Report recorded',
          message: LanguageService.instance.isHindi ? 'प्रश्न ${widget.questionNumber} · संदर्भ: $reportCode · विशेषज्ञ दल जांच करेगा' : 'Question ${widget.questionNumber} · ref: $reportCode · the expert team will inspect it',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(
          context,
          title: LanguageService.instance.isHindi ? 'रिपोर्ट सबमिट नहीं हो सकी' : 'Report could not submit',
          message: LanguageService.instance.isHindi ? 'त्रुटि: $e. कृपया पुनः प्रयास करें।' : 'Error: $e. Please try again.',
        );
      }
    }
  }

  void _copyReportToClipboard() {
    HapticFeedback.lightImpact();
    final q = widget.question;
    final optionsList = q.optionsHindi.isNotEmpty ? q.optionsHindi : (q.optionsEnglish ?? []);
    final optionsText = optionsList.asMap().entries.map((e) => '(${String.fromCharCode(65 + e.key)}) ${e.value}').join('\n');
    final userOptStr = widget.userAnswer != null ? String.fromCharCode(65 + widget.userAnswer!) : (LanguageService.instance.isHindi ? 'छोड़ा गया' : 'Skipped');
    final correctOptStr = String.fromCharCode(65 + q.answer);

    final summary = '''🚩 [TET Exam App - प्रश्न त्रुटि रिपोर्ट]
━━━━━━━━━━━━━━━━━━━━
📄 परीक्षा/सेट: ${widget.paperTitle ?? 'TET अभ्यास सेट'}
❓ प्रश्न सं: ${widget.questionNumber} (ID: ${q.id})
📝 प्रश्न: ${q.qHindi}
📋 विकल्प:
$optionsText
━━━━━━━━━━━━━━━━━━━━
🎯 आधिकारिक उत्तर: ($correctOptStr)
👤 छात्र चयन: ($userOptStr)
⚠️ समस्या: $_selectedReason
${_suggestedOption != null ? '💡 छात्र द्वारा सुझाया गया सही विकल्प: ($_suggestedOption)\n' : ''}💬 अतिरिक्त विवरण: ${_commentController.text.trim().isEmpty ? (LanguageService.instance.isHindi ? 'कोई नहीं' : 'None') : _commentController.text.trim()}
📅 दिनांक: ${DateTime.now().toLocal().toString().split('.')[0]}
━━━━━━━━━━━━━━━━━━━━''';

    Clipboard.setData(ClipboardData(text: summary));

    AppSnackBar.showSuccess(
      context,
      title: LanguageService.instance.isHindi ? 'रिपोर्ट कॉपी हो गई है' : 'Report copied',
      message: LanguageService.instance.isHindi ? 'विवरण क्लिपबोर्ड पर कॉपी हो गया। आप इसे WhatsApp/Email पर भेज सकते हैं।' : 'Details copied to the clipboard. You can share them on WhatsApp/Email.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface = isDark ? AppColors.primary : AppColors.lightCard;
    final cardBg = isDark ? AppColors.primaryLight : AppColors.darkTextPrimary;
    final borderColor = isDark ? AppColors.lightTextSecondary : AppColors.borderStrong;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted;

    final q = widget.question;
    final qPreview = q.qHindi.trim().isNotEmpty ? q.qHindi.trim() : (q.qEnglish ?? '');
    final cleanPreview = qPreview.replaceAll(RegExp(r'\s+'), ' ');
    final shortPreview = cleanPreview.length > 110 ? '${cleanPreview.substring(0, 110)}...' : cleanPreview;

    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets;
    final screenHeight = mediaQuery.size.height;
    final isKeyboardOpen = viewInsets.bottom > 60;
    final availableHeight = screenHeight - viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: isKeyboardOpen
              ? (availableHeight * 0.95).clamp(280.0, availableHeight)
              : screenHeight * 0.86,
        ),
        decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(
          color: AppColors.goldBright.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle pill
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.deskGray : AppColors.lightBorder,
                  borderRadius: AppRadius.roundedMd,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  // Illuminated glowing Flag Badge (Tap to setup/check GitHub API key)
                  InkWell(
                    onTap: () => _showApiKeySetupDialog(context),
                    borderRadius: AppRadius.roundedMd,
                    child: Tooltip(
                      message: 'GitHub कुंजी सेटअप',
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.sealGoldLight, AppColors.sealGold],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: AppRadius.roundedMd,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sealGoldLight.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.flag_rounded, color: AppColors.darkTextPrimary, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                LanguageService.instance.isHindi ? 'प्रश्न में त्रुटि रिपोर्ट' : 'Report a question error',
                                style: AppTypography.titleMedium(color: textPrimary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: AppColors.sealGoldLight.withValues(alpha: 0.15),
                                borderRadius: AppRadius.roundedSm,
                                border: Border.all(
                                  color: AppColors.sealGoldLight.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Q${widget.questionNumber}',
                                style: AppTypography.labelSmall(color: AppColors.goldBright),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.paperTitle != null
                              ? '${widget.paperTitle} · प्रश्न संख्या ${widget.questionNumber}'
                              : (LanguageService.instance.isHindi
                                  ? 'प्रश्न संख्या ${widget.questionNumber} का विवरण दर्ज करें'
                                  : 'Report the details of question ${widget.questionNumber}'),
                          style: AppTypography.bodySmall(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    constraints: const BoxConstraints(),
                    tooltip: LanguageService.instance.isHindi ? 'मेरी रिपोर्ट्स देखें' : 'View my reports',
                    icon: const Icon(Icons.history_rounded, color: AppColors.goldBright, size: 21),
                    onPressed: () {
                      ReportedQuestionsSheet.show(context);
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 21),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: borderColor, height: 1),

            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Previous report notice
                    if (_hasAlreadyReported) ...[
                      InkWell(
                        onTap: () => ReportedQuestionsSheet.show(context),
                        borderRadius: AppRadius.roundedMd,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.goldBright.withValues(alpha: 0.12),
                            borderRadius: AppRadius.roundedMd,
                            border: Border.all(
                              color: AppColors.goldBright.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.history_rounded, color: AppColors.goldBright, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  LanguageService.instance.isHindi ? 'आप इस प्रश्न की रिपोर्ट पहले दर्ज कर चुके हैं। (पिछली रिपोर्ट देखने हेतु टैप करें)' : 'You have already reported this question. (Tap to see the earlier report)',
                                  style: AppTypography.labelMedium(color: AppColors.goldBright),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.goldBright, size: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Question preview card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: AppRadius.roundedMd,
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.format_quote_rounded, size: 16, color: AppColors.goldBright),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                LanguageService.instance.isHindi ? 'प्रश्न का संक्षिप्त अंश:' : 'Short excerpt of the question:',
                                style: AppTypography.labelMedium(color: textSecondary),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.roundedSm,
                                ),
                                child: Text(
                                  LanguageService.instance.isHindi ? 'सही उत्तर: (${String.fromCharCode(65 + q.answer)})' : 'Correct answer: (${String.fromCharCode(65 + q.answer)})',
                                  style: AppTypography.labelSmall(color: AppColors.success),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            shortPreview,
                            style: AppTypography.bodyMedium(color: textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Title: Reason
                    Text(
                      LanguageService.instance.isHindi ? 'इस प्रश्न में क्या समस्या है? (समस्या चुनें)' : 'What is wrong with this question? (Choose the issue)',
                      style: AppTypography.titleSmall(color: textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Reason Selector Cards
                    ..._reasons.map((r) {
                      final id = r['id'] as String;
                      final title = r['title'] as String;
                      final subtitle = r['subtitle'] as String;
                      final icon = r['icon'] as IconData;
                      final accent = r['color'] as Color;
                      final isSelected = _selectedReason == id || _selectedReason == title;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedReason = id);
                          },
                          borderRadius: AppRadius.roundedMd,
                          child: AnimatedContainer(
                            duration: AppMotion.base,
                            curve: AppMotion.standard,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.12)
                                  : (isDark ? AppColors.darkCard : AppColors.darkTextPrimary),
                              borderRadius: AppRadius.roundedMd,
                              border: Border.all(
                                color: isSelected ? accent : borderColor,
                                width: isSelected ? 1.6 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.18),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Icon Circle
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent.withValues(alpha: isSelected ? 0.25 : 0.1),
                                  ),
                                  child: Icon(icon, color: accent, size: 18),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: AppTypography.titleSmall(color: isSelected ? textPrimary : textPrimary.withValues(alpha: 0.85)),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        subtitle,
                                        style: AppTypography.bodySmall(color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? accent : textSecondary.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Suggested Option (shows when wrong answer is selected)
                    if (_selectedReason == 'wrong_answer' || _selectedReason.contains('Wrong Answer') || _selectedReason.contains('उत्तर गलत')) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        LanguageService.instance.isHindi
                            ? 'आपके अनुसार सही उत्तर क्या होना चाहिए?'
                            : 'What do you believe is the correct answer?',
                        style: AppTypography.labelMedium(color: AppColors.goldBright),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['A', 'B', 'C', 'D'].map((opt) {
                          final isOptSel = _suggestedOption == opt;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _suggestedOption = isOptSel ? null : opt;
                                  });
                                },
                                borderRadius: AppRadius.roundedSm,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isOptSel
                                        ? AppColors.goldBright.withValues(alpha: 0.2)
                                        : cardBg,
                                    borderRadius: AppRadius.roundedSm,
                                    border: Border.all(
                                      color: isOptSel ? AppColors.goldBright : borderColor,
                                      width: isOptSel ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    '($opt)',
                                    style: AppTypography.titleSmall(color: isOptSel ? AppColors.goldBright : textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.base),

                    // Additional Comment Input with Keyboard Dismiss Option
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LanguageService.instance.isHindi ? 'अतिरिक्त विवरण / टिप्पणी (वैकल्पिक)' : 'Extra details / comment (optional)',
                          style: AppTypography.labelMedium(color: textPrimary),
                        ),
                        if (isKeyboardOpen)
                          InkWell(
                            onTap: () => FocusScope.of(context).unfocus(),
                            borderRadius: AppRadius.roundedSm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: AppColors.goldBright.withValues(alpha: 0.15),
                                borderRadius: AppRadius.roundedSm,
                                border: Border.all(
                                  color: AppColors.goldBright.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.keyboard_hide_rounded, size: 14, color: AppColors.goldBright),
                                  const SizedBox(width: 4),
                                  Text(
                                    LanguageService.instance.isHindi ? 'कीबोर्ड छुपाएं' : 'Hide keyboard',
                                    style: AppTypography.labelSmall(color: AppColors.goldBright),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      maxLines: 3,
                      maxLength: 300,
                      textInputAction: TextInputAction.done,
                      scrollPadding: const EdgeInsets.only(bottom: 160),
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      onTap: () {
                        Future.delayed(AppMotion.slow, () {
                          if (mounted && _scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: AppMotion.slow,
                              curve: Curves.easeOutCubic,
                            );
                          }
                        });
                      },
                      style: AppTypography.titleSmall(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: LanguageService.instance.isHindi ? 'पुस्तक संदर्भ, सही उत्तर का कारण या प्रश्न में क्या छूटा है संक्षेप में लिखें...' : 'Book reference, why the key is right, or what is missing — briefly...',
                        hintStyle: AppTypography.caption(color: textSecondary.withValues(alpha: 0.7)),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.roundedMd,
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.roundedMd,
                          borderSide: const BorderSide(color: AppColors.goldBright, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.roundedMd,
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit & Action Buttons
                    Row(
                      children: [
                        // WhatsApp / Clipboard Share Button
                        OutlinedButton.icon(
                          onPressed: _copyReportToClipboard,
                          icon: const Icon(Icons.share_outlined, size: 16, color: AppColors.success),
                          label: Text(
                            LanguageService.instance.isHindi ? 'कॉपी' : 'Copy',
                            style: AppTypography.labelMedium(color: AppColors.success),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.success, width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Primary Submit Button
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.sealGoldLight, AppColors.sealGold],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: AppRadius.roundedMd,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.sealGoldLight.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitReport,
                              style: ElevatedButton.styleFrom(
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkTextPrimary),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.send_rounded, size: 18, color: AppColors.darkTextPrimary),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(
                                          LanguageService.instance.isHindi ? 'रिपोर्ट सबमिट करें' : 'Submit the report',
                                          style: AppTypography.titleMedium(color: AppColors.darkTextPrimary),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

/// Dedicated Screen / Modal to view and track all reported questions
class ReportedQuestionsSheet extends StatefulWidget {
  const ReportedQuestionsSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return AppSheet.show(
      context,
      builder: (ctx) => const ReportedQuestionsSheet(),
    );
  }

  @override
  State<ReportedQuestionsSheet> createState() => _ReportedQuestionsSheetState();
}

class _ReportedQuestionsSheetState extends State<ReportedQuestionsSheet> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reports = await DbHelper.instance.getQuestionReports();
    if (mounted) {
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteReport(int id, int qNum) async {
    HapticFeedback.lightImpact();
    await DbHelper.instance.deleteQuestionReport(id);
    await _loadReports();
    if (mounted) {
      AppSnackBar.showSuccess(
        context,
        title: LanguageService.instance.isHindi ? 'रिपोर्ट हटा दी गई' : 'Report removed',
        message: LanguageService.instance.isHindi ? 'प्रश्न $qNum की रिपोर्ट सफलतापूर्वक हटा दी गई है।' : 'The report of question $qNum has been removed.',
      );
    }
  }

  void _copySingleReport(Map<String, dynamic> r) {
    HapticFeedback.lightImpact();
    final qNum = r['question_number'];
    final qId = r['question_id'];
    final paper = r['paper_form_id'];
    final reason = r['reason'];
    final comment = r['comment'];
    final stem = r['question_stem'] ?? '';
    final opt = r['suggested_option'];
    final id = r['id'];
    final date = r['created_at'];

    final text = '''🚩 [TET Exam App - प्रश्न त्रुटि रिपोर्ट #$id]
━━━━━━━━━━━━━━━━━━━━
📄 परीक्षा: $paper
❓ प्रश्न सं: $qNum (ID: $qId)
📝 प्रश्न अंश: $stem
⚠️ समस्या: $reason
${opt != null && opt.toString().isNotEmpty ? '💡 सुझाया गया सही विकल्प: ($opt)\n' : ''}💬 टिप्पणी: ${comment ?? (LanguageService.instance.isHindi ? 'कोई नहीं' : 'None')}
📅 दिनांक: $date
━━━━━━━━━━━━━━━━━━━━''';

    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.showSuccess(
      context,
      title: LanguageService.instance.isHindi ? 'रिपोर्ट विवरण कॉपी हो गया' : 'Report details copied',
      message: LanguageService.instance.isHindi ? 'क्लिपबोर्ड पर कॉपी हो गया।' : 'Copied to the clipboard.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface = isDark ? AppColors.primary : AppColors.lightCard;
    final cardBg = isDark ? AppColors.primaryLight : AppColors.darkTextPrimary;
    final borderColor = isDark ? AppColors.lightTextSecondary : AppColors.borderStrong;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(
          color: AppColors.goldBright.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.deskGray : AppColors.lightBorder,
                  borderRadius: AppRadius.roundedMd,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.goldBright.withValues(alpha: 0.15),
                      borderRadius: AppRadius.roundedMd,
                      border: Border.all(
                        color: AppColors.goldBright.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.history_edu_rounded, color: AppColors.goldBright, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                LanguageService.instance.isHindi ? 'मेरी रिपोर्ट की गई समस्याएं' : 'My reported issues',
                                style: AppTypography.titleMedium(color: textPrimary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: AppRadius.roundedMd,
                              ),
                              child: Text(
                                '${_reports.length}',
                                style: AppTypography.labelMedium(color: AppColors.success),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          LanguageService.instance.isHindi ? 'प्रश्नों की समीक्षा स्थिति · 7 दिनों में स्वतः निस्तारित' : 'Review status of reports · auto-cleared in 7 days',
                          style: AppTypography.bodySmall(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: borderColor, height: 1),

            // Body List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldBright),
                      ),
                    )
                  : _reports.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Icon(Icons.check_circle_outline_rounded, size: 32, color: textSecondary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  LanguageService.instance.isHindi ? 'कोई रिपोर्ट दर्ज नहीं है' : 'No report filed yet',
                                  style: AppTypography.titleMedium(color: textPrimary),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  LanguageService.instance.isHindi ? 'यदि किसी प्रश्न में उत्तर या प्रश्न अधूरा लगे, तो प्रश्न कार्ड पर "🚩 रिपोर्ट" बटन दबाकर रिपोर्ट दर्ज करें।' : 'If an answer or a question looks incomplete, press the "🚩 Report" button on the question card to file one.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium(color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.lg),
                          itemCount: _reports.length,
                          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                          itemBuilder: (ctx, idx) {
                            final r = _reports[idx];
                            final id = r['id'] as int? ?? 0;
                            final qNum = r['question_number'] as int? ?? 0;
                            final paper = r['paper_form_id']?.toString() ?? 'TET Paper';
                            final reason = r['reason']?.toString() ?? (LanguageService.instance.isHindi ? 'त्रुटि' : 'Error');
                            final comment = r['comment']?.toString();
                            final stem = r['question_stem']?.toString();
                            final opt = r['suggested_option']?.toString();
                            final status = r['status']?.toString() ?? 'submitted';
                            final dateStr = r['created_at']?.toString() ?? '';

                            String displayDate = '';
                            try {
                              if (dateStr.isNotEmpty) {
                                final dt = DateTime.parse(dateStr).toLocal();
                                displayDate = '${dt.day}/${dt.month}/${dt.year} · ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                              }
                            } catch (_) {
                              displayDate = dateStr;
                            }

                            final reportCode = 'REP-${DateTime.now().year}-${id.toString().padLeft(4, '0')}';

                                  final isSolved = status == 'solved' || status == 'resolved';
                                  final isVerified = status == 'verified';

                                  return Container(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: AppRadius.roundedBase,
                                      border: Border.all(
                                        color: isSolved
                                            ? AppColors.success.withValues(alpha: 0.4)
                                            : borderColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top row: QNum badge + Status pill (Flexible) + Actions
                                        Row(
                                          children: [
                                            // Question Number badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                              decoration: BoxDecoration(
                                                color: AppColors.sealGoldLight.withValues(alpha: 0.15),
                                                borderRadius: AppRadius.roundedSm,
                                                border: Border.all(
                                                  color: AppColors.sealGoldLight.withValues(alpha: 0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'Q$qNum',
                                                style: AppTypography.labelSmall(color: AppColors.goldBright),
                                              ),
                                            ),
                                            const SizedBox(width: AppSpacing.sm),

                                            // Status Badge (Flexible so it never overflows)
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                                decoration: BoxDecoration(
                                                  color: isSolved
                                                      ? AppColors.success.withValues(alpha: 0.15)
                                                      : (isVerified
                                                          ? AppColors.accentBright.withValues(alpha: 0.15)
                                                          : AppColors.goldBright.withValues(alpha: 0.12)),
                                                  borderRadius: AppRadius.roundedSm,
                                                  border: Border.all(
                                                    color: isSolved
                                                        ? AppColors.success.withValues(alpha: 0.35)
                                                        : (isVerified
                                                            ? AppColors.accentBright.withValues(alpha: 0.35)
                                                            : AppColors.goldBright.withValues(alpha: 0.3)),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isSolved
                                                          ? Icons.check_circle_rounded
                                                          : (isVerified
                                                              ? Icons.verified_rounded
                                                              : Icons.pending_actions_rounded),
                                                      size: 11.5,
                                                      color: isSolved
                                                          ? AppColors.success
                                                          : (isVerified
                                                              ? AppColors.accentBright
                                                              : AppColors.goldBright),
                                                    ),
                                                    const SizedBox(width: AppSpacing.xs),
                                                    Flexible(
                                                      child: Text(
                                                        isSolved
                                                            ? (LanguageService.instance.isHindi ? 'हल हो गया' : 'Solved')
                                                            : (isVerified
                                                                ? (LanguageService.instance.isHindi ? 'सत्यापित' : 'Verified')
                                                                : (LanguageService.instance.isHindi ? 'समीक्षाधीन' : 'Under Review')),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: AppTypography.labelSmall(color: isSolved
                                                              ? AppColors.success
                                                              : (isVerified
                                                                  ? AppColors.accentBright
                                                                  : AppColors.goldBright)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),

                                            // Copy button
                                            IconButton(
                                              padding: const EdgeInsets.all(AppSpacing.xs),
                                              constraints: const BoxConstraints(),
                                              icon: Icon(Icons.copy_rounded, size: 16, color: textSecondary),
                                              tooltip: LanguageService.instance.isHindi ? 'कॉपी करें' : 'Copy',
                                              onPressed: () => _copySingleReport(r),
                                            ),
                                            const SizedBox(width: 8),

                                            // Delete button
                                            IconButton(
                                              padding: const EdgeInsets.all(AppSpacing.xs),
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.danger),
                                              tooltip: LanguageService.instance.isHindi ? 'हटाएं' : 'Remove',
                                              onPressed: () => _deleteReport(id, qNum),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.sm),

                                        // Paper and Code (Full width, ellipsis safe)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                paper,
                                                style: AppTypography.labelMedium(color: textPrimary),
                                              ),
                                            ),
                                            const SizedBox(width: AppSpacing.xs),
                                            Text(
                                              reportCode,
                                              style: AppTypography.bodySmall(color: textSecondary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.xs),

                                        // Reason badge + Date row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                                decoration: BoxDecoration(
                                                  color: AppColors.danger.withValues(alpha: 0.1),
                                                  borderRadius: AppRadius.roundedSm,
                                                ),
                                                child: Text(
                                                  (LanguageService.instance.isHindi ? 'समस्या: ' : 'Issue: ') + reason,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: AppTypography.labelSmall(color: AppColors.danger),
                                                ),
                                              ),
                                            ),
                                            if (displayDate.isNotEmpty) ...[
                                              const SizedBox(width: AppSpacing.sm),
                                              Text(
                                                displayDate,
                                                style: AppTypography.labelSmall(color: textSecondary.withValues(alpha: 0.7)),
                                              ),
                                            ],
                                          ],
                                        ),

                                  // Stem preview if present
                                  if (stem != null && stem.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      stem,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall(
                                        color: textSecondary,
                                      ).copyWith(height: 1.4),
                                    ),
                                  ],

                                  // Suggested Option
                                  if (opt != null && opt.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '💡 छात्र द्वारा सुझाया गया सही उत्तर: विकल्प ($opt)',
                                      style: AppTypography.labelMedium(color: AppColors.goldBright),
                                    ),
                                  ],

                                  // Comment if present
                                  if (comment != null && comment.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      (LanguageService.instance.isHindi ? 'टिप्पणी: ' : 'Comment: ') + comment,
                                      style: AppTypography.bodySmall(
                                        color: textPrimary.withValues(alpha: 0.85),
                                      ).copyWith(fontStyle: FontStyle.italic),
                                    ),
                                  ],

                                  // Date
                                  if (displayDate.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        displayDate,
                                        style: AppTypography.labelSmall(color: textSecondary.withValues(alpha: 0.7)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

