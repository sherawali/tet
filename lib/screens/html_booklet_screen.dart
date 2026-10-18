import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/test_session.dart';
import '../models/mock_config.dart';
import '../database/db_helper.dart';
import '../design_system/app_colors.dart';
import '../services/html_booklet_builder.dart';

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
  String? _errorMessage;
  late final String _htmlContent;

  @override
  void initState() {
    super.initState();
    // Immersive sticky for full exam focus
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      _htmlContent = HtmlBookletBuilder.buildHtml(widget.session);
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _initWebView() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (url) {
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
        ..loadHtmlString(_htmlContent);

      _controller = controller;
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
          _controller?.loadHtmlString(_htmlContent);
          break;

        case 'testSubmitted':
          _onTestSubmittedFromHtml(data);
          break;

        case 'reportQuestion':
          final qIndex = data['qIndex'] as int? ?? 0;
          final qNum = data['qNum'] as int? ?? (qIndex + 1);
          final reason = data['reason']?.toString() ?? 'गलत उत्तर / प्रश्न';
          final comment = data['comment']?.toString();
          final qId = (qIndex < widget.session.questions.length)
              ? widget.session.questions[qIndex].id
              : 'Q$qNum';

          await DbHelper.instance.saveQuestionReport(
            questionId: qId,
            paperFormId: widget.session.paperTitle ?? widget.session.setCode,
            questionNumber: qNum,
            reason: reason,
            comment: comment,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ प्रश्न $qNum की रिपोर्ट दर्ज कर ली गई है। धन्यवाद!'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('Booklet JS Message parse error: $e');
    }
  }

  Future<void> _onTestSubmittedFromHtml(Map<String, dynamic> data) async {
    final score = data['score'] as int? ?? widget.session.calculateScore();
    final elapsed = data['elapsedSeconds'] as int? ?? widget.session.elapsedSeconds;

    final respMap = data['responses'] as Map<String, dynamic>?;
    if (respMap != null) {
      respMap.forEach((k, v) {
        final qIndex = (int.tryParse(k) ?? 0) - 1;
        if (qIndex >= 0 && v is int) {
          widget.session.selectedAnswers[qIndex] = v;
          widget.session.visitedIndices.add(qIndex);
        }
      });
    }

    widget.session.isCompleted = true;
    widget.session.elapsedSeconds = elapsed;
    widget.session.endTime = DateTime.now();

    // Record mistakes and save test history to SQLite
    try {
      await DbHelper.instance.saveTestHistory(
        id: widget.session.id,
        mode: widget.session.config.mode.shortTitle,
        sectionFilter: widget.session.config.sectionFilter,
        score: score,
        total: widget.session.questions.length,
        timeSpentSeconds: elapsed,
        sessionJson: '{}',
      );
      await DbHelper.instance.recordSessionMistakes(widget.session);
    } catch (e) {
      debugPrint('Error saving test results to DB: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 परीक्षा समाप्त! प्राप्तांक: $score / ${widget.session.questions.length}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    final answered = widget.session.selectedAnswers.length;
    final total = widget.session.questions.length;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('परीक्षा से बाहर निकलें?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('आपने $total में से $answered प्रश्न हल किए हैं।'),
            const SizedBox(height: 12),
            const Text(
              'यदि आप अभी बाहर जाते हैं, तो आपका मौजूदा टेस्ट सत्र समाप्त हो जाएगा।',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('▶ हल करना जारी रखें', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, 'exit'),
            child: const Text('✕ बाहर निकलें', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return action == 'exit';
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Container(
            color: Colors.white,
            child: Stack(
            children: [
              if (_controller != null)
                WebViewWidget(controller: _controller!)
              else if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _initWebView();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('दोबारा प्रयास करें'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isLoading)
                Container(
                  color: Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 14),
                        Text(
                          'प्रश्न-पुस्तिका लोड हो रही है / Loading Booklet...',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
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
