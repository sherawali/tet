import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/test_session.dart';
import '../models/mock_config.dart';
import '../database/db_helper.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_strings.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_dialogs.dart';
import '../design_system/app_snack_bar.dart';
import '../widgets/app_card.dart';
import '../widgets/app_state_views.dart';
import '../widgets/question_report_sheet.dart';
import '../services/html_booklet_builder.dart';
import 'result_screen.dart';

/// Standalone Real-Time HTML Question Booklet Screen
/// Renders authentic board test booklet via webview_flutter with full
/// two-way state synchronization and offline SQLite persistence.
class HtmlBookletScreen extends StatefulWidget {
  final TestSession session;

  const HtmlBookletScreen({
    super.key,
    required this.session,
  });

  @override
  State<HtmlBookletScreen> createState() => _HtmlBookletScreenState();
}

class _HtmlBookletScreenState extends State<HtmlBookletScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _htmlContent;
  Timer? _loadWatchdog;

  @override
  void initState() {
    super.initState();
    // Immersive sticky for full exam focus
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_htmlContent != null) return;

    // The booklet is built once, with the theme the app is currently using,
    // so the booklet and the Flutter UI always look the same.
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      _htmlContent = HtmlBookletBuilder.buildHtml(widget.session, isDark: isDark);
      _initWebView();
    } catch (e) {
      setState(() {
        _errorMessage = 'बुकलेट तैयार करने में त्रुटि: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _loadWatchdog?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _initWebView() {
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(isDark ? AppColors.primaryDark : AppColors.lightCard)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (url) {
              _loadWatchdog?.cancel();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = null;
                });
              }
            },
            onWebResourceError: (error) {
              // Ignore benign minor resource errors (like favicon 404)
              if (error.errorCode != -1 && error.description.contains('ERR_FILE_NOT_FOUND')) return;
              _loadWatchdog?.cancel();
              if (mounted && _isLoading) {
                setState(() {
                  _errorMessage = 'बुकलेट लोड करने में समस्या: ${error.description}';
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..addJavaScriptChannel(
          'BookletChannel',
          onMessageReceived: _handleJsMessage,
        )
        ..loadHtmlString(_htmlContent!);

      _controller = controller;

      // Watchdog: a booklet is a local string, so it must render in a
      // moment.  If the WebView does not report back (broken WebView, stuck
      // resource) the overlay is released anyway so the candidate is never
      // stuck on a spinner.
      _loadWatchdog?.cancel();
      _loadWatchdog = Timer(const Duration(seconds: 8), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'WebView इनिशियलाइज़ नहीं हो सका: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJsMessage(JavaScriptMessage message) async {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'selectOption':
          final qIndex = data['qIndex'] as int?;
          final optIndex = data['optionIndex'] as int?;
          if (qIndex != null && optIndex != null) {
            setState(() {
              widget.session.selectedAnswers[qIndex] = optIndex;
              widget.session.visitedIndices.add(qIndex);
            });
          }
          break;

        case 'toggleReview':
          final qIndex = data['qIndex'] as int?;
          final isRev = data['isReviewed'] as bool? ?? false;
          if (qIndex != null) {
            setState(() {
              if (isRev) {
                widget.session.markedForReview.add(qIndex);
              } else {
                widget.session.markedForReview.remove(qIndex);
              }
            });
          }
          break;

        case 'resetTest':
          setState(() {
            widget.session.selectedAnswers.clear();
            widget.session.markedForReview.clear();
          });
          break;

        case 'exitTest':
          final nav = Navigator.of(context);
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            nav.pop();
          }
          break;

        case 'refreshTest':
          _controller?.loadHtmlString(_htmlContent ?? '');
          break;

        case 'testSubmitted':
          _onTestSubmittedFromHtml(data);
          break;

        case 'requestReport':
          final qIndex = data['qIndex'] as int? ?? 0;
          final qNum = data['qNum'] as int? ?? (qIndex + 1);
          if (qIndex >= 0 && qIndex < widget.session.questions.length) {
            final q = widget.session.questions[qIndex];
            QuestionReportSheet.show(
              context,
              question: q,
              questionNumber: qNum,
              paperTitle: widget.session.paperTitle ?? widget.session.setCode,
              userAnswer: widget.session.selectedAnswers[qIndex],
            );
          }
          break;

        case 'reportQuestion':
          final qIndex = data['qIndex'] as int? ?? 0;
          final qNum = data['qNum'] as int? ?? (qIndex + 1);
          final reason = data['reason']?.toString() ?? 'गलत उत्तर / प्रश्न';
          final comment = data['comment']?.toString();
          final qId = (qIndex < widget.session.questions.length)
              ? widget.session.questions[qIndex].id
              : 'Q$qNum';

          final reportId = await DbHelper.instance.saveQuestionReport(
            questionId: qId,
            paperFormId: widget.session.paperTitle ?? widget.session.setCode,
            questionNumber: qNum,
            reason: reason,
            comment: comment,
          );
          final reportCode = 'REP-${DateTime.now().year}-${reportId.toString().padLeft(4, '0')}';
          if (mounted) {
            AppSnackBar.showReportSuccess(
              context,
              questionNumber: qNum,
              reportCode: reportCode,
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('Booklet JS Message parse error: $e');
    }
  }

  Future<void> _onTestSubmittedFromHtml(Map<String, dynamic> data) async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    final respMap = data['responses'] as Map<String, dynamic>?;
    if (respMap != null) {
      respMap.forEach((k, v) {
        final qIndex = (int.tryParse(k) ?? 0) - 1;
        if (qIndex >= 0 && qIndex < widget.session.questions.length) {
          final answer = v is num ? v.toInt() : int.tryParse(v.toString());
          if (answer != null && answer >= 0 && answer <= 3) {
            widget.session.selectedAnswers[qIndex] = answer;
            widget.session.visitedIndices.add(qIndex);
          }
        }
      });
    }

    final elapsed = (data['elapsedSeconds'] as num?)?.toInt() ??
        widget.session.elapsedSeconds;
    final score = widget.session.calculateScore();

    widget.session.isCompleted = true;
    widget.session.elapsedSeconds = elapsed.clamp(
      0,
      widget.session.timeLimitSeconds,
    );
    widget.session.endTime = DateTime.now();

    // Record mistakes and save the complete session.  The full snapshot is
    // what allows a completed test to be reopened from History.
    try {
      await DbHelper.instance.saveTestHistory(
        id: widget.session.id,
        mode: widget.session.config.mode.shortTitle,
        sectionFilter: widget.session.config.sectionFilter,
        score: score,
        total: widget.session.questions.length,
        timeSpentSeconds: widget.session.elapsedSeconds,
        sessionJson: widget.session.encode(),
      );
      await DbHelper.instance.recordSessionMistakes(widget.session);
    } catch (e) {
      debugPrint('Error saving test results to DB: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultScreen(session: widget.session),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final answered = widget.session.selectedAnswers.length;
    final total = widget.session.questions.length;

    final leave = await AppDialogs.confirm(
      context,
      title: 'परीक्षा से बाहर निकलें?',
      message: AppStrings.exitExamMessage(total, answered),
      confirmLabel: '✕ बाहर निकलें',
      cancelLabel: '▶ हल करना जारी रखें',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );

    return leave;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkBg : AppColors.lightCard;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.primary,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Container(
            color: surface,
            child: Stack(
            children: [
              if (_controller != null)
                WebViewWidget(controller: _controller!)
              else if (_errorMessage != null)
                Center(
                  child: AppEmptyState(
                    icon: Icons.error_outline_rounded,
                    accent: AppColors.danger,
                    title: _errorMessage!,
                    actionLabel: 'दोबारा प्रयास करें',
                    onAction: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _initWebView();
                    },
                  ),
                ),
              if (_isLoading)
                Container(
                  color: surface,
                  child: Center(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.xl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: isDark ? AppColors.accentBright : AppColors.primary,
                              strokeWidth: 2.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'प्रश्न-पुस्तिका लोड हो रही है / Loading Booklet...',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
