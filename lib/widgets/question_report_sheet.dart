import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/app_snack_bar.dart';
import '../models/question.dart';
import '../database/db_helper.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87.withValues(alpha: 0.75),
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
  String _selectedReason = 'उत्तर गलत है (Wrong Answer Key)';
  String? _suggestedOption;
  bool _isSubmitting = false;
  bool _hasAlreadyReported = false;

  final List<Map<String, dynamic>> _reasons = [
    {
      'title': 'उत्तर गलत है (Wrong Answer Key)',
      'subtitle': 'दी गई उत्तर कुंजी या सही विकल्प गलत है',
      'icon': Icons.cancel_outlined,
      'color': const Color(0xFFEF4444),
    },
    {
      'title': 'अधूरा या अस्पष्ट प्रश्न (Incomplete Question)',
      'subtitle': 'प्रश्न का वाक्य अधूरा है या कोई विकल्प छूटा हुआ है',
      'icon': Icons.help_outline_rounded,
      'color': const Color(0xFFF59E0B),
    },
    {
      'title': 'अनुवाद या वर्तनी अशुद्धि (Translation / Typo)',
      'subtitle': 'हिन्दी/अंग्रेजी अनुवाद में गड़बड़ी या व्याकरण अशुद्धि है',
      'icon': Icons.translate_rounded,
      'color': const Color(0xFF38BDF8),
    },
    {
      'title': 'सूत्र या चित्र समस्या (Formula / Diagram)',
      'subtitle': 'गणितीय सूत्र, समीकरण या चित्र स्पष्ट दिखाई नहीं दे रहा',
      'icon': Icons.functions_rounded,
      'color': const Color(0xFFA855F7),
    },
    {
      'title': 'अन्य समस्या (Other Issue)',
      'subtitle': 'पाठ्यक्रम से बाहर या अन्य कोई त्रुटि',
      'icon': Icons.error_outline_rounded,
      'color': const Color(0xFF10B981),
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkPreviousReport();
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
    _commentController.dispose();
    super.dispose();
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

      if (mounted) {
        Navigator.pop(context);
        widget.onReportSubmitted?.call();

        AppSnackBar.showReportSuccess(
          context,
          questionNumber: widget.questionNumber,
          reportCode: reportCode,
          title: 'रिपोर्ट दर्ज कर ली गई है',
          message: 'प्रश्न ${widget.questionNumber} · संदर्भ: $reportCode · विशेषज्ञ दल जांच करेगा',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(
          context,
          title: 'रिपोर्ट सबमिट नहीं हो सकी',
          message: 'त्रुटि: $e. कृपया पुनः प्रयास करें।',
        );
      }
    }
  }

  void _copyReportToClipboard() {
    HapticFeedback.lightImpact();
    final q = widget.question;
    final optionsList = q.optionsHindi.isNotEmpty ? q.optionsHindi : (q.optionsEnglish ?? []);
    final optionsText = optionsList.asMap().entries.map((e) => '(${String.fromCharCode(65 + e.key)}) ${e.value}').join('\n');
    final userOptStr = widget.userAnswer != null ? String.fromCharCode(65 + widget.userAnswer!) : 'छोड़ा गया';
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
${_suggestedOption != null ? '💡 छात्र द्वारा सुझाया गया सही विकल्प: ($_suggestedOption)\n' : ''}💬 अतिरिक्त विवरण: ${_commentController.text.trim().isEmpty ? 'कोई नहीं' : _commentController.text.trim()}
📅 दिनांक: ${DateTime.now().toLocal().toString().split('.')[0]}
━━━━━━━━━━━━━━━━━━━━''';

    Clipboard.setData(ClipboardData(text: summary));

    AppSnackBar.showSuccess(
      context,
      title: 'रिपोर्ट कॉपी हो गई है',
      message: 'विवरण क्लिपबोर्ड पर कॉपी हो गया। आप इसे WhatsApp/Email पर भेज सकते हैं।',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final q = widget.question;
    final qPreview = q.qHindi.trim().isNotEmpty ? q.qHindi.trim() : (q.qEnglish ?? '');
    final cleanPreview = qPreview.replaceAll(RegExp(r'\s+'), ' ');
    final shortPreview = cleanPreview.length > 110 ? '${cleanPreview.substring(0, 110)}...' : cleanPreview;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  // Illuminated glowing Flag Badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFB45309)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'प्रश्न में त्रुटि रिपोर्ट करें',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Q${widget.questionNumber}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.paperTitle != null
                              ? '${widget.paperTitle} · प्रश्न संख्या ${widget.questionNumber}'
                              : 'प्रश्न संख्या ${widget.questionNumber} का विवरण दर्ज करें',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansDevanagari(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'मेरी रिपोर्ट्स देखें',
                    icon: const Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 22),
                    onPressed: () {
                      ReportedQuestionsSheet.show(context);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: borderColor, height: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Previous report notice
                    if (_hasAlreadyReported) ...[
                      InkWell(
                        onTap: () => ReportedQuestionsSheet.show(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'आप इस प्रश्न की रिपोर्ट पहले दर्ज कर चुके हैं। (पिछली रिपोर्ट देखने हेतु टैप करें)',
                                  style: GoogleFonts.notoSansDevanagari(
                                    fontSize: 12,
                                    color: const Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFF59E0B), size: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Question preview card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.format_quote_rounded, size: 16, color: const Color(0xFFF59E0B)),
                              const SizedBox(width: 6),
                              Text(
                                'प्रश्न का संक्षिप्त अंश:',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textSecondary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'सही उत्तर: (${String.fromCharCode(65 + q.answer)})',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            shortPreview,
                            style: GoogleFonts.notoSansDevanagari(
                              fontSize: 13,
                              height: 1.45,
                              color: textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Title: Reason
                    Text(
                      'इस प्रश्न में क्या समस्या है? (समस्या चुनें)',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Reason Selector Cards
                    ..._reasons.map((r) {
                      final title = r['title'] as String;
                      final subtitle = r['subtitle'] as String;
                      final icon = r['icon'] as IconData;
                      final accent = r['color'] as Color;
                      final isSelected = _selectedReason == title;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedReason = title);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.12)
                                  : (isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
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
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                          color: isSelected ? textPrimary : textPrimary.withValues(alpha: 0.85),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: GoogleFonts.notoSansDevanagari(
                                          fontSize: 11.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
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
                    if (_selectedReason.contains('Wrong Answer') || _selectedReason.contains('उत्तर गलत')) ...[
                      const SizedBox(height: 10),
                      Text(
                        'आपके अनुसार सही उत्तर क्या होना चाहिए?',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['A', 'B', 'C', 'D'].map((opt) {
                          final isOptSel = _suggestedOption == opt;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _suggestedOption = isOptSel ? null : opt;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isOptSel
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                        : cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isOptSel ? const Color(0xFFF59E0B) : borderColor,
                                      width: isOptSel ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    '($opt)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isOptSel ? const Color(0xFFF59E0B) : textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Additional Comment Input
                    Text(
                      'अतिरिक्त विवरण / टिप्पणी (वैकल्पिक)',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      maxLength: 300,
                      style: GoogleFonts.notoSansDevanagari(
                        fontSize: 13.5,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'पुस्तक संदर्भ, सही उत्तर का कारण या प्रश्न में क्या छूटा है संक्षेप में लिखें...',
                        hintStyle: GoogleFonts.notoSansDevanagari(
                          fontSize: 12.5,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                          icon: const Icon(Icons.share_outlined, size: 16, color: Color(0xFF10B981)),
                          label: Text(
                            'कॉपी',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Primary Submit Button
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD97706), Color(0xFFB45309)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          'रिपोर्ट सबमिट करें',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
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
    );
  }
}

/// Dedicated Screen / Modal to view and track all reported questions
class ReportedQuestionsSheet extends StatefulWidget {
  const ReportedQuestionsSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87.withValues(alpha: 0.8),
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
        title: 'रिपोर्ट हटा दी गई',
        message: 'प्रश्न $qNum की रिपोर्ट सफलतापूर्वक हटा दी गई है।',
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
${opt != null && opt.toString().isNotEmpty ? '💡 सुझाया गया सही विकल्प: ($opt)\n' : ''}💬 टिप्पणी: ${comment ?? 'कोई नहीं'}
📅 दिनांक: $date
━━━━━━━━━━━━━━━━━━━━''';

    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.showSuccess(
      context,
      title: 'रिपोर्ट विवरण कॉपी हो गया',
      message: 'क्लिपबोर्ड पर कॉपी हो गया।',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.history_edu_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'मेरी रिपोर्ट की गई समस्याएं',
                              style: GoogleFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_reports.length}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'आपके द्वारा रिपोर्ट किए गए प्रश्नों की स्थिति',
                          style: GoogleFonts.notoSansDevanagari(
                            fontSize: 12,
                            color: textSecondary,
                          ),
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
            const SizedBox(height: 10),
            Divider(color: borderColor, height: 1),

            // Body List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                      ),
                    )
                  : _reports.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
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
                                  'कोई रिपोर्ट दर्ज नहीं है',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'यदि किसी प्रश्न में उत्तर या प्रश्न अधूरा लगे, तो प्रश्न कार्ड पर "🚩 रिपोर्ट" बटन दबाकर रिपोर्ट दर्ज करें।',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.notoSansDevanagari(
                                    fontSize: 13,
                                    color: textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          itemCount: _reports.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final r = _reports[idx];
                            final id = r['id'] as int? ?? 0;
                            final qNum = r['question_number'] as int? ?? 0;
                            final paper = r['paper_form_id']?.toString() ?? 'TET Paper';
                            final reason = r['reason']?.toString() ?? 'त्रुटि';
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

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor, width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: QNum badge + Status + Copy + Delete
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFFD97706).withValues(alpha: 0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'प्रश्न Q$qNum',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF38BDF8)),
                                            const SizedBox(width: 4),
                                            Text(
                                              status == 'verified'
                                                  ? 'सत्यापित'
                                                  : 'समीक्षाधीन (Under Review)',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF38BDF8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.copy_rounded, size: 17, color: textSecondary),
                                        tooltip: 'कॉपी करें',
                                        onPressed: () => _copySingleReport(r),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                        tooltip: 'हटाएं',
                                        onPressed: () => _deleteReport(id, qNum),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Paper and Code
                                  Row(
                                    children: [
                                      Text(
                                        paper,
                                        style: GoogleFonts.notoSansDevanagari(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '· $reportCode',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Reason badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'समस्या: $reason',
                                      style: GoogleFonts.notoSansDevanagari(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),

                                  // Stem preview if present
                                  if (stem != null && stem.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      stem,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.notoSansDevanagari(
                                        fontSize: 12,
                                        color: textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],

                                  // Suggested Option
                                  if (opt != null && opt.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '💡 छात्र द्वारा सुझाया गया सही उत्तर: विकल्प ($opt)',
                                      style: GoogleFonts.notoSansDevanagari(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],

                                  // Comment if present
                                  if (comment != null && comment.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'टिप्पणी: $comment',
                                      style: GoogleFonts.notoSansDevanagari(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: textPrimary.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],

                                  // Date
                                  if (displayDate.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        displayDate,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          color: textSecondary.withValues(alpha: 0.7),
                                        ),
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

