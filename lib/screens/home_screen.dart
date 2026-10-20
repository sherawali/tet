import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_strings.dart';
import '../services/language_service.dart';

import '../widgets/app_badge.dart';
import '../models/mock_config.dart';
import '../models/test_session.dart';
import '../models/question.dart';
import '../models/passage.dart';
import '../database/db_helper.dart';
import '../services/sync_service.dart';
import '../services/mock_engine.dart';
import 'mock_series_screen.dart';
import 'subject_detail_screen.dart';
import 'result_screen.dart';
import '../widgets/flash_message_banner.dart';
import '../services/premium_service.dart';
import '../services/in_app_update_service.dart';
import '../services/exam_service.dart';
import '../services/exam_rules.dart';
import '../widgets/premium_paywall_modal.dart';
import '../widgets/question_report_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DbHelper _db = DbHelper.instance;
  final SyncService _syncService = SyncService();
  final MockEngine _engine = MockEngine();

  int _totalQuestions = 0;
  int _pyqCount = 0;
  List<Map<String, dynamic>> _history = [];
  List<String> _pyqYears = [];
  List<Map<String, dynamic>> _paperForms = [];
  List<Map<String, dynamic>> _pyqForms = [];
  List<Map<String, dynamic>> _mockForms = [];
  late final PageController _heroCarouselController = PageController();
  int _currentCarouselPage = 0;
  Timer? _carouselTimer;
  DateTime? _lastBackPressTime;
  bool _isLoading = false;
  int _selectedTab = 0;

  // Offline Database & Sync Status
  String _dbSizeStr = '3.5 MB';
  String _lastSyncedStr = 'अभी नहीं';
  bool _isSyncing = false;
  bool _isOptimizing = false;
  double _syncProgress = 0.0;
  String _syncProgressStatus = '';
  bool _hasRemoteUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkRemoteUpdateSilently();
    SyncService.onDatabaseUpdated.addListener(_onDatabaseUpdatedListener);
  }

  void _checkRemoteUpdateSilently() async {
    try {
      final available = await _syncService.isUpdateAvailable(checkRawGitHub: true);
      if (available && mounted) {
        setState(() => _hasRemoteUpdate = true);
      }
    } catch (_) {}
  }

  void _onDatabaseUpdatedListener() {
    if (mounted) {
      _loadData();
    }
  }

  List<Map<String, dynamic>> get _carouselItems {
    if (ExamService.instance.selectedPaper == 1) {
      final list = <Map<String, dynamic>>[..._pyqForms];
      list.addAll(_mockForms.take(5));
      return list;
    } else {
      if (_pyqForms.isNotEmpty) return _pyqForms;
      return _mockForms.take(8).toList();
    }
  }

  void _startCarouselAutoPlay() {
    _carouselTimer?.cancel();
    final items = _carouselItems;
    if (items.length <= 1) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final currentList = _carouselItems;
      if (currentList.isEmpty) return;
      final nextPage = (_currentCarouselPage + 1) % currentList.length;
      if (_heroCarouselController.hasClients) {
        _heroCarouselController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _heroCarouselController.dispose();
    SyncService.onDatabaseUpdated.removeListener(_onDatabaseUpdatedListener);
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentExam = ExamService.instance.examCode;
    final total = await _db.getQuestionCount(currentExam);
    final pyq = await _db.getPyqCount(currentExam);
    final history = await _db.getTestHistory();
    final years = await _db.getDistinctPyqYears(currentExam);

    // Database physical size & sync timestamp
    final sizeBytes = await _db.getDatabaseSizeBytes();
    final lastSynced = await _db.getMeta('last_synced');
    String sizeFormatted = '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    String syncedFormatted = AppStrings.dbNeverSynced;
    if (lastSynced != null) {
      try {
        final dt = DateTime.parse(lastSynced).toLocal();
        final now = DateTime.now();
        final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        syncedFormatted = isToday ? 'आज $hour:$min' : '${dt.day}/${dt.month}/${dt.year} $hour:$min';
      } catch (_) {
        syncedFormatted = lastSynced;
      }
    }

    final examName = ExamService.instance.isUtet ? 'utet' : 'ctet';
    final forms = await _db.getAvailablePaperForms(exam: examName, paper: ExamService.instance.selectedPaper);
    final pyqs = await _db.getAvailablePaperForms(exam: examName, paper: ExamService.instance.selectedPaper, isPyqOnly: true);
    final mocks = await _db.getAvailablePaperForms(exam: examName, paper: ExamService.instance.selectedPaper, isPyqOnly: false);

    if (mounted) {
      _carouselTimer?.cancel();
      if (_heroCarouselController.hasClients) {
        _heroCarouselController.jumpToPage(0);
      }
      setState(() {
        _currentCarouselPage = 0;
        _totalQuestions = total;
        _pyqCount = pyq;
        _history = history;
        _pyqYears = years;
        _paperForms = forms;
        _pyqForms = pyqs;
        _mockForms = mocks;
        _dbSizeStr = sizeFormatted;
        _lastSyncedStr = syncedFormatted;
      });
      _startCarouselAutoPlay();
    }
  }

  Future<void> _startMockTest(
    MockConfig config, {
    String? formId,
    String? paperTitle,
    String? setCode,
  }) async {
    setState(() => _isLoading = true);

    try {
      ({List<Question> questions, Map<String, Passage> passages}) mockData;
      if (formId != null) {
        mockData = await _engine.loadPrebuiltPaper(paperFormId: formId);
      } else if (_paperForms.isNotEmpty) {
        mockData = await _engine.loadPrebuiltPaper(paperFormId: _paperForms.first['id'] as String);
      } else {
        mockData = await _engine.generateMock(config);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (mockData.questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('इस पेपर के प्रश्न लोड नहीं हो सके')),
        );
        return;
      }

      final session = TestSession(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        questions: mockData.questions,
        passages: mockData.passages,
        paperTitle: paperTitle,
        setCode: setCode,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExamService.instance.buildExamScreen(session: session),
        ),
      ).then((_) => _loadData());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.loadError(e.toString()))),
      );
    }
  }

  void _showSyncFeedbackModal(SyncResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdded = result.success && result.newQuestionsAdded > 0;
    final isUpToDate = result.success && (result.isUpToDate || result.newQuestionsAdded == 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
              color: isAdded
                  ? AppColors.sealGold
                  : (isUpToDate ? AppColors.correctGreen : AppColors.danger),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top drag notch
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: (isAdded
                              ? AppColors.sealGold
                              : (isUpToDate ? AppColors.correctGreen : AppColors.danger))
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isAdded
                            ? AppColors.sealGold
                            : (isUpToDate ? AppColors.correctGreen : AppColors.danger),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isAdded
                          ? Icons.auto_awesome_rounded
                          : (isUpToDate ? Icons.verified_rounded : Icons.cloud_off_rounded),
                      color: isAdded
                          ? AppColors.sealGold
                          : (isUpToDate ? AppColors.correctGreen : AppColors.danger),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    isAdded
                        ? AppStrings.syncSuccessAddedTitle(result.newQuestionsAdded)
                        : (isUpToDate
                            ? AppStrings.syncUpToDateTitle
                            : AppStrings.syncErrorTitle),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    isAdded
                        ? AppStrings.syncSuccessAddedDesc(result.totalCount)
                        : (isUpToDate
                            ? AppStrings.syncUpToDateDesc(result.totalCount)
                            : AppStrings.syncErrorDesc(result.message)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Metric Chips
                  if (result.success)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.sealGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.sealGold, width: 1),
                          ),
                          child: Text(
                            AppStrings.syncTotalQuestionsChip(result.totalCount),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.sealGold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.correctGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.correctGreen, width: 1),
                          ),
                          child: Text(
                            AppStrings.syncOfflineChip,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.correctGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Action button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAdded
                          ? AppColors.sealGold
                          : (isDark ? AppColors.darkCardElevated : AppColors.primary),
                      foregroundColor: isAdded ? Colors.black : Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (isAdded) {
                        setState(() => _selectedTab = 0); // Focus on Booklets
                      }
                    },
                    icon: Icon(
                      isAdded ? Icons.menu_book_rounded : Icons.check_circle_outline_rounded,
                      size: 20,
                    ),
                    label: Text(
                      isAdded
                          ? (LanguageService.instance.isHindi ? 'प्रश्न-पुस्तिका हल करना शुरू करें' : 'Start Solving Booklet')
                          : AppStrings.syncContinueBtn,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _syncProgress = 0.05;
      _syncProgressStatus = AppStrings.settingsSyncChecking;
    });

    final result = await _syncService.syncQuestionBank(
      force: true,
      onProgress: (prog, msg) {
        if (mounted) {
          setState(() {
            _syncProgress = prog;
            _syncProgressStatus = msg;
          });
        }
      },
    );
    await _loadData();
    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      if (result.success) {
        _hasRemoteUpdate = false;
      }
    });
    _showSyncFeedbackModal(result);
  }

  Future<void> _optimizeDatabase() async {
    setState(() => _isOptimizing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sealGold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppStrings.dbOptimizingToast,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final res = await _db.optimizeDatabase();
      await _loadData();
      if (!mounted) return;
      setState(() => _isOptimizing = false);
      _showOptimizeFeedbackModal(res);
    } catch (_) {
      if (mounted) setState(() => _isOptimizing = false);
    }
  }

  Future<void> _confirmCleanAndResync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppStrings.dbCleanDialogTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          AppStrings.dbCleanDialogDesc,
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.dbCancelBtn),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppStrings.dbCleanConfirmBtn,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _cleanAndResync();
    }
  }

  Future<void> _cleanAndResync() async {
    setState(() {
      _isSyncing = true;
      _syncProgress = 0.05;
      _syncProgressStatus = AppStrings.settingsSyncChecking;
    });

    final result = await _syncService.cleanResyncQuestionBank(
      onProgress: (prog, msg) {
        if (mounted) {
          setState(() {
            _syncProgress = prog;
            _syncProgressStatus = msg;
          });
        }
      },
    );

    await _loadData();
    if (mounted) {
      setState(() {
        _isSyncing = false;
      });
      _showSyncFeedbackModal(result);
    }
  }

  void _showOptimizeFeedbackModal(Map<String, dynamic> result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bytesSaved = result['bytesSaved'] as int? ?? 0;
    final savedKb = (bytesSaved / 1024).toStringAsFixed(1);
    final totalQ = result['questionCount'] as int? ?? _totalQuestions;
    final orphanDeleted = result['orphanDeleted'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: AppColors.sealGold, width: 1.5),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.sealGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.sealGold, width: 2),
                    ),
                    child: const Icon(Icons.bolt_rounded, size: 36, color: AppColors.sealGold),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.dbOptimizeDoneTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.dbOptimizeDoneDesc(savedKb),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.sealGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.sealGold, width: 1),
                        ),
                        child: Text(
                          AppStrings.dbTotalQuestionsChip(totalQ),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.sealGold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.correctGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.correctGreen, width: 1),
                        ),
                        child: Text(
                          AppStrings.dbSpaceFreedChip(savedKb),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.correctGreen),
                        ),
                      ),
                      if (orphanDeleted > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary, width: 1),
                          ),
                          child: Text(
                            AppStrings.dbOrphanDeletedChip(orphanDeleted),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sealGold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(AppStrings.syncContinueBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yearsStr = _pyqYears.isNotEmpty
        ? (_pyqYears.length == 1 ? _pyqYears.first : '${_pyqYears.first}–${_pyqYears.last}')
        : '2023–2025';

    return AnimatedBuilder(
      animation: Listenable.merge([
        LanguageService.instance.currentLanguage,
        ExamService.instance.currentExam,
      ]),
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;

            // 1. If currently on Subjects, History, or Settings, switch smoothly to Home tab!
            if (_selectedTab != 0) {
              setState(() => _selectedTab = 0);
              return;
            }

            // 2. On Home tab: double back press exit with prominent high-contrast toast
            final now = DateTime.now();
            if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
              _lastBackPressTime = now;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.sealGold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.doubleBackExit,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF0F172A), // Deep Slate Navy
                  elevation: 8,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.sealGold, width: 1.2),
                  ),
                ),
              );
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            appBar: AppBar(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Row(
                children: [
                  ValueListenableBuilder<AppPaper>(
                    valueListenable: ExamService.instance.currentPaper,
                    builder: (context, currentPaper, _) {
                      return ValueListenableBuilder<AppExam>(
                        valueListenable: ExamService.instance.currentExam,
                        builder: (context, currentExam, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.sealGold.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.sealGold, width: 1.2),
                            ),
                            child: Text(
                              ExamService.instance.shortNameWithPaper,
                              style: const TextStyle(
                                color: AppColors.sealGoldSubtle,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.appTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          AppStrings.appSubtitle,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: AppStrings.myReportsTooltip,
                  icon: const Icon(
                    Icons.flag_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                  onPressed: () => ReportedQuestionsSheet.show(context),
                ),
                IconButton(
                  tooltip: AppStrings.bankSyncTooltip,
                  icon: Icon(
                    Icons.sync_rounded,
                    color: isDark ? AppColors.sealGoldLight : Colors.white,
                  ),
                  onPressed: _syncNow,
                ),
                const SizedBox(width: 8),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedTab,
              onTap: (idx) => setState(() => _selectedTab = idx),
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              selectedItemColor: isDark ? AppColors.sealGoldLight : AppColors.primary,
              unselectedItemColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.menu_book_rounded),
                  label: AppStrings.navBooklets,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.category_rounded),
                  label: AppStrings.navSubjects,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.history_rounded),
                  label: AppStrings.navHistory,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_suggest_rounded),
                  label: AppStrings.navSettings,
                ),
              ],
            ),
            body: SafeArea(
              child: _isLoading
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.sealGold),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.loadingGenerating,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: _buildCurrentTabContent(_selectedTab, isDark, yearsStr),
                    ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildCurrentTabContent(int tabIndex, bool isDark, String yearsStr) {
    switch (tabIndex) {
      case 0:
        return _buildBookletsTab(isDark, yearsStr);
      case 1:
        return _buildSubjectsTab(isDark);
      case 2:
        return _buildHistoryTab(isDark);
      case 3:
        return _buildSettingsTab(isDark);
      default:
        return _buildBookletsTab(isDark, yearsStr);
    }
  }

  Widget _buildBookletsTab(bool isDark, String yearsStr) {
    final isHi = AppStrings.isHindi;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. Target Exam Switcher (UTET / CTET)
        _buildExamSwitcher(isDark),

        // Remote Test & Question Bank Update Notification Banner
        if (_hasRemoteUpdate) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF38BDF8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF0F172A), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHi ? '📢 नया प्रश्न बैंक व टेस्ट उपलब्ध है!' : '📢 New Test Bank & Mocks Available!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHi ? 'नवीनतम प्रश्न व सुधार ऑफ़लाइन डाउनलोड करने के लिए टैप करें।' : 'Tap to sync latest questions for offline practice.',
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _syncNow,
                  child: Text(
                    isHi ? 'अपडेट' : 'Update',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Remote Flash Message Carousel Banner (GitHub-controlled)
        FlashMessageBanner(
          onActionTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MockSeriesScreen()),
            );
          },
        ),

        // 2. HERO CAROUSEL: Auto-Rotating & Swipeable Board PYQ Carousel
        _buildHeroPyqCarousel(isDark),
        const SizedBox(height: 16),

        // 3. Section Heading: Complete Exam Booklets
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: ExamService.instance.isPaper2 ? const Color(0xFF8B5CF6) : AppColors.sealGold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _mockForms.isNotEmpty
                  ? (isHi
                      ? '2026 मॉडल प्रश्न-पत्र (${_mockForms.length} सेट)'
                      : '2026 Model Test Papers (${_mockForms.length} Sets)')
                  : (isHi
                      ? 'विगत वर्ष प्रश्न-पत्र (${_paperForms.length} सेट)'
                      : 'Previous Year Solved Papers (${_paperForms.length} Sets)'),
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ).copyWith(fontSize: 14.5),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if ((_mockForms.isNotEmpty ? _mockForms : _paperForms).isNotEmpty) ...[
          ...(_mockForms.isNotEmpty ? _mockForms : _paperForms).asMap().entries.map((entry) {
            final idx = entry.key;
            final f = entry.value;
            final formId = f['id'] as String;
            final title = AppStrings.formatPaperTitle(f, isHindi: isHi);
            final rawSet = f['set_code']?.toString() ?? 'SET ${(idx + 1).toString().padLeft(2, "0")}';
            final setChar = AppStrings.formatSetBadge(rawSet, isHindi: isHi);
            final isFree = PremiumService.instance.isPaperFree(formId: formId, index: idx);
            final isPyq = rawSet == 'PYQ' || rawSet.contains('20');
            final tag = isFree
                ? (isHi ? 'निःशुल्क' : 'FREE')
                : (isPyq
                    ? (isHi ? 'विगत वर्ष' : 'PAST PAPER')
                    : (isHi ? '150 प्रश्न सेट' : '150Q Mock Set'));
            final tagColor = isFree
                ? AppColors.correctGreen
                : (isPyq ? AppColors.violet : AppColors.sealGold);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildBookletTile(
                setChar: setChar,
                title: title,
                subtitle: isHi
                    ? '150 प्रश्न · 150 मिनट · सम्पूर्ण हल सहित'
                    : '150 Questions · 150 Mins · Complete Solutions',
                tag: tag,
                tagColor: tagColor,
                mode: isPyq ? MockMode.pyq : MockMode.predicted,
                isDark: isDark,
                formId: formId,
                isFree: isFree,
              ),
            );
          }),
        ] else ...[
          _buildBookletTile(
            setChar: isHi ? 'सेट-01' : 'SET-01',
            title: isHi ? 'UTET 2026 पेपर-1 मॉडल प्रश्न-पत्र 01' : 'UTET 2026 Paper-1 Model Test Paper 01',
            subtitle: isHi
                ? '150 प्रश्न · 150 मिनट · सम्पूर्ण हल सहित'
                : '150 Questions · 150 Mins · Complete Solutions',
            tag: isHi ? 'निःशुल्क' : 'FREE',
            tagColor: AppColors.correctGreen,
            mode: MockMode.predicted,
            isDark: isDark,
            isFree: true,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }



  Widget _buildExamSwitcher(bool isDark) {
    return ValueListenableBuilder<AppPaper>(
      valueListenable: ExamService.instance.currentPaper,
      builder: (context, currentPaper, _) {
        return ValueListenableBuilder<AppExam>(
          valueListenable: ExamService.instance.currentExam,
          builder: (context, currentExam, _) {
            final isCtet = currentExam == AppExam.ctet;
            final isP2 = currentPaper == AppPaper.paper2;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  // Row 1: Exam Switcher (UTET vs CTET)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (isCtet) {
                              await ExamService.instance.setExam(AppExam.utet);
                              _loadData();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            decoration: BoxDecoration(
                              color: !isCtet
                                  ? (isDark ? AppColors.sealGold : AppColors.primary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !isCtet
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🌲 UTET',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: !isCtet
                                          ? (isDark ? AppColors.darkBg : Colors.white)
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.isHindi ? '(उत्तराखण्ड)' : '(Uttarakhand)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: !isCtet ? FontWeight.w600 : FontWeight.normal,
                                      color: !isCtet
                                          ? (isDark ? AppColors.darkBg.withValues(alpha: 0.8) : Colors.white70)
                                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (!isCtet) {
                              await ExamService.instance.setExam(AppExam.ctet);
                              _loadData();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            decoration: BoxDecoration(
                              color: isCtet
                                  ? (isDark ? AppColors.sealGold : AppColors.primary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isCtet
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🏛️ CTET',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isCtet
                                          ? (isDark ? AppColors.darkBg : Colors.white)
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.isHindi ? '(केन्द्रीय)' : '(Central)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isCtet ? FontWeight.w600 : FontWeight.normal,
                                      color: isCtet
                                          ? (isDark ? AppColors.darkBg.withValues(alpha: 0.8) : Colors.white70)
                                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Row 2: Paper Switcher (Paper-1: Class 1-5 vs Paper-2: Class 6-8)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardElevated : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              if (isP2) {
                                _carouselTimer?.cancel();
                                await ExamService.instance.setPaper(AppPaper.paper1);
                                _loadData();
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                              decoration: BoxDecoration(
                                color: !isP2
                                    ? (isDark ? const Color(0xFF0284C7).withValues(alpha: 0.22) : const Color(0xFFE0F2FE))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: !isP2
                                    ? Border.all(color: const Color(0xFF0284C7), width: 1.5)
                                    : null,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      !isP2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      size: 13,
                                      color: !isP2 ? const Color(0xFF0284C7) : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppStrings.isHindi ? 'पेपर-1 (कक्षा 1–5)' : 'Paper-1 (Classes 1–5)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: !isP2 ? FontWeight.w800 : FontWeight.w600,
                                        color: !isP2
                                            ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1))
                                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              if (!isP2) {
                                _carouselTimer?.cancel();
                                await ExamService.instance.setPaper(AppPaper.paper2);
                                _loadData();
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isP2
                                    ? (isDark ? const Color(0xFF8B5CF6).withValues(alpha: 0.25) : const Color(0xFFF3E8FF))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isP2
                                    ? Border.all(color: const Color(0xFF8B5CF6), width: 1.5)
                                    : null,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isP2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      size: 13,
                                      color: isP2 ? const Color(0xFF8B5CF6) : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppStrings.isHindi ? 'पेपर-2 (कक्षा 6–8)' : 'Paper-2 (Classes 6–8)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isP2 ? FontWeight.w800 : FontWeight.w600,
                                        color: isP2
                                            ? (isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9))
                                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsExamCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.sealGold,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sealGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, color: AppColors.sealGold, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.targetExamHeading,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.isHindi
                          ? 'मॉक टेस्ट और प्रश्न-पत्र बदलने के लिए परीक्षा चुनें'
                          : 'Select exam to switch mock papers & questions',
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
          const SizedBox(height: 16),
          ValueListenableBuilder<AppExam>(
            valueListenable: ExamService.instance.currentExam,
            builder: (context, currentExam, _) {
              final isCtet = currentExam == AppExam.ctet;
              return Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        if (isCtet) {
                          await ExamService.instance.setExam(AppExam.utet);
                          _loadData();
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: !isCtet
                              ? AppColors.sealGold.withValues(alpha: 0.2)
                              : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: !isCtet ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: !isCtet ? 2.0 : 1.0,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                !isCtet ? Icons.check_circle_rounded : Icons.circle_outlined,
                                color: !isCtet ? AppColors.sealGold : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '🌲 UTET I & II',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        if (!isCtet) {
                          await ExamService.instance.setExam(AppExam.ctet);
                          _loadData();
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isCtet
                              ? AppColors.sealGold.withValues(alpha: 0.2)
                              : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCtet ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: isCtet ? 2.0 : 1.0,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isCtet ? Icons.check_circle_rounded : Icons.circle_outlined,
                                color: isCtet ? AppColors.sealGold : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '🏛️ CTET',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Paper 1 vs Paper 2 Selection
          ValueListenableBuilder<AppPaper>(
            valueListenable: ExamService.instance.currentPaper,
            builder: (context, currentPaper, _) {
              final isP2 = currentPaper == AppPaper.paper2;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.paperSelectorHeader,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (isP2) {
                              await ExamService.instance.setPaper(AppPaper.paper1);
                              _loadData();
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: !isP2
                                  ? AppColors.sealGold.withValues(alpha: 0.2)
                                  : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: !isP2 ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                width: !isP2 ? 2.0 : 1.0,
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    !isP2 ? Icons.check_circle_rounded : Icons.circle_outlined,
                                    color: !isP2 ? AppColors.sealGold : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppStrings.paper1Tab,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (!isP2) {
                              await ExamService.instance.setPaper(AppPaper.paper2);
                              _loadData();
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isP2
                                  ? AppColors.sealGold.withValues(alpha: 0.2)
                                  : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isP2 ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                width: isP2 ? 2.0 : 1.0,
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isP2 ? Icons.check_circle_rounded : Icons.circle_outlined,
                                    color: isP2 ? AppColors.sealGold : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppStrings.paper2Tab,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTestModeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.sealGold,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sealGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.devices_rounded, color: AppColors.sealGold, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.testModeHeader,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.testModeDesc,
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
          const SizedBox(height: 16),
          ValueListenableBuilder<AppTestMode>(
            valueListenable: ExamService.instance.currentTestMode,
            builder: (context, currentMode, _) {
              final isCbt = currentMode == AppTestMode.cbt;
              return Column(
                children: [
                  // Option 1: CBT Mode (Recommended)
                  InkWell(
                    onTap: () => ExamService.instance.setTestMode(AppTestMode.cbt),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCbt
                            ? AppColors.sealGold.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCbt ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: isCbt ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCbt ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isCbt ? AppColors.sealGold : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.cbtModeTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  AppStrings.cbtModeSub,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option 2: Booklet Mode
                  InkWell(
                    onTap: () => ExamService.instance.setTestMode(AppTestMode.booklet),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !isCbt
                            ? AppColors.sealGold.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !isCbt ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: !isCbt ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !isCbt ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: !isCbt ? AppColors.sealGold : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.bookletModeTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  AppStrings.bookletModeSub,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTetLanguagesCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.sealGold,
          width: 1.5,
        ),
      ),
      child: ValueListenableBuilder<String>(
        valueListenable: ExamService.instance.currentLang1,
        builder: (context, lang1, _) {
          return ValueListenableBuilder<String>(
            valueListenable: ExamService.instance.currentLang2,
            builder: (context, lang2, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.sealGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: AppColors.sealGold, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.langCardTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.langCardSubtitle,
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
                  const SizedBox(height: 16),

                  // Section 1: भाषा प्रथम
                  Row(
                    children: [
                      const Icon(Icons.looks_one_rounded, color: AppColors.sealGold, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.lang1Heading,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLangChoiceChip(
                        title: AppStrings.langHindiLabel,
                        selected: lang1 == 'hindi',
                        onTap: () => ExamService.instance.setLang1('hindi'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildLangChoiceChip(
                        title: AppStrings.langEnglishLabel,
                        selected: lang1 == 'english',
                        onTap: () => ExamService.instance.setLang1('english'),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section 2: भाषा द्वितीय
                  Row(
                    children: [
                      const Icon(Icons.looks_two_rounded, color: AppColors.sealGold, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.lang2Heading,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLangChoiceChip(
                        title: AppStrings.langEnglishLabel,
                        selected: lang2 == 'english',
                        onTap: () => ExamService.instance.setLang2('english'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildLangChoiceChip(
                        title: AppStrings.langHindiLabel,
                        selected: lang2 == 'hindi',
                        onTap: () => ExamService.instance.setLang2('hindi'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildLangChoiceChip(
                        title: '🔒 ${AppStrings.langSanskritLabel}',
                        selected: false,
                        onTap: () => _showSanskritUpcomingDialog(context),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Info box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.sealGold),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppStrings.langNotice,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showSanskritUpcomingDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.sealGold, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: AppColors.sealGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.sanskritUpcomingTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          AppStrings.sanskritUpcomingDesc,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sealGold,
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppStrings.understoodBtn),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAppUpdate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.checkingUpdate)),
    );
    try {
      final info = await InAppUpdateService.instance.checkForUpdate();
      if (!mounted) return;
      if (info != null && (info.immediateUpdateAllowed || info.flexibleUpdateAllowed)) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdateService.instance.performImmediateUpdate();
        } else {
          final started = await InAppUpdateService.instance.startFlexibleUpdate();
          if (started && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.updateFound)),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.appUpToDate)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.appUpToDate)),
        );
      }
    }
  }

  Widget _buildLangChoiceChip({
    required String title,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.sealGold.withValues(alpha: 0.2)
                : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: selected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.sealGold : Colors.grey,
                size: 15,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected
                        ? AppColors.sealGold
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Subject Section Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
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
                child: const Icon(Icons.category_rounded, color: AppColors.sealGold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.subjectPracticeHeading,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.subjectPracticeDesc,
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
        ),
        const SizedBox(height: 16),

        _buildSubjectGrid(isDark),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    final passCount = _history.where((h) {
      final s = (h['score'] as num?)?.toInt() ?? 0;
      final t = (h['total'] as num?)?.toInt() ?? 150;
      return ExamRules.isGeneralPass(s, t);
    }).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Heading & Summary
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.historyTitle,
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ).copyWith(fontSize: 16),
            ),
            if (_history.isNotEmpty)
              AppBadge(
                label: AppStrings.historySummary(_history.length, passCount),
                color: AppColors.sealGold,
                isSolid: true,
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (_history.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.0,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.sealGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_toggle_off_rounded, color: AppColors.sealGold, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.historyEmptyTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.historyEmptyDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sealGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    AppStrings.historyStartCta,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  onPressed: () {
                    final featured = _paperForms.isNotEmpty ? _paperForms.first : null;
                    _startMockTest(
                      MockConfig(
                        mode: MockMode.predicted,
                        seed: DateTime.now().millisecondsSinceEpoch,
                      ),
                      formId: featured?['id'] as String?,
                      paperTitle: featured?['title']?.toString(),
                      setCode: featured?['set_code']?.toString(),
                    );
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          ..._history.map((h) => _buildHistoryCard(h, isDark)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 0. Premium All-Access Pass Status Card
        ValueListenableBuilder<bool>(
          valueListenable: PremiumService.instance.isPremiumUnlocked,
          builder: (context, isUnlocked, _) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.sealGold,
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sealGold.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.sealGold.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUnlocked ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded,
                          color: AppColors.sealGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.premiumPassTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isUnlocked ? AppStrings.premiumActiveStatus : AppStrings.premiumPriceBadge,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w600,
                                color: isUnlocked ? AppColors.correctGreen : AppColors.sealGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isUnlocked)
                        const Icon(Icons.check_circle_rounded, color: AppColors.correctGreen, size: 24),
                    ],
                  ),
                  if (!isUnlocked) ...[
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.premiumPassSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sealGold,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => PremiumPaywallModal.show(context),
                      icon: const Icon(Icons.stars_rounded, size: 20),
                      label: Text(
                        AppStrings.premiumUnlockBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        // 1. Target Exam Switcher Card
        _buildSettingsExamCard(isDark),

        // 2. Default Test Mode Card (CBT vs Booklet)
        _buildSettingsTestModeCard(isDark),

        // 3. TET Exam Language 1 & Language 2 Selector
        _buildSettingsTetLanguagesCard(isDark),

        // 4. Language Switcher Card (App UI)
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.sealGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.translate_rounded, color: AppColors.sealGold, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.settingsLangHeader,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.settingsLangDesc,
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
              const SizedBox(height: 16),

              // Interactive Language Buttons
              ValueListenableBuilder<AppLang>(
                valueListenable: LanguageService.instance.currentLanguage,
                builder: (context, currentLang, _) {
                  final isHindi = currentLang == AppLang.hi;
                  return Row(
                    children: [
                      // Hindi option
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            LanguageService.instance.setLanguage(AppLang.hi);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isHindi
                                  ? AppColors.sealGold.withValues(alpha: 0.2)
                                  : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isHindi ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                width: isHindi ? 2.0 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isHindi)
                                  const Icon(Icons.check_circle_rounded, color: AppColors.sealGold, size: 18)
                                else
                                  const Icon(Icons.circle_outlined, color: Colors.grey, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.langHindiLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // English option
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            LanguageService.instance.setLanguage(AppLang.en);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: !isHindi
                                  ? AppColors.sealGold.withValues(alpha: 0.2)
                                  : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: !isHindi ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                width: !isHindi ? 2.0 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isHindi)
                                  const Icon(Icons.check_circle_rounded, color: AppColors.sealGold, size: 18)
                                else
                                  const Icon(Icons.circle_outlined, color: Colors.grey, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'English',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Offline Question Bank & Database Management Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storage_rounded, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.settingsBankHeader,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.bankInfo(_totalQuestions, _pyqCount, 5),
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
              const SizedBox(height: 12),

              // Database Metrics Badges
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.data_usage_rounded, size: 14, color: AppColors.sealGold),
                        const SizedBox(width: 4),
                        Text(
                          '${AppStrings.dbStorageSizeLabel}: $_dbSizeStr',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_toggle_off_rounded, size: 14, color: AppColors.correctGreen),
                        const SizedBox(width: 4),
                        Text(
                          '${AppStrings.dbLastSyncedLabel}: $_lastSyncedStr',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                AppStrings.settingsBankDesc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.35,
                ),
              ),

              // Active Sync Progress indicator
              if (_isSyncing) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _syncProgress > 0 ? _syncProgress : null,
                    minHeight: 6,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sealGold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _syncProgressStatus.isNotEmpty ? _syncProgressStatus : AppStrings.settingsSyncChecking,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Action Button 1: Check & Update (Normal Sync)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? AppColors.sealGoldLight : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                      width: 1.2,
                    ),
                  ),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: _isSyncing ? null : _syncNow,
                icon: const Icon(Icons.sync_rounded, size: 20),
                label: Text(
                  AppStrings.settingsBankSyncBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),

              // Action Buttons Row: Clean & Re-sync + Deep Optimize
              Row(
                children: [
                  // Clean & Re-sync Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isSyncing ? null : _confirmCleanAndResync,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppStrings.dbCleanResyncBtn,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Deep Optimize Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.sealGoldLight : AppColors.sealGold,
                        side: BorderSide(
                          color: AppColors.sealGold.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: (_isOptimizing || _isSyncing) ? null : _optimizeDatabase,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppStrings.dbOptimizeBtn,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Mathematical Probability Model Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.sealGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_graph_rounded, color: AppColors.sealGold, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.settingsModelHeader,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            AppBadge(label: 'Verified ${AppStrings.currentExamYear}', color: AppColors.sealGold),
                            AppBadge(
                              label: AppStrings.isHindi ? 'मानक ब्लूप्रिंट' : 'Exam Blueprint',
                              color: AppColors.cdp,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.settingsModelDesc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. In-App Update (IAU) Card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.sealGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update_rounded, color: AppColors.sealGold, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.checkUpdateBtn,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.updateAvailableDesc,
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.sealGoldLight : AppColors.primary,
                  side: BorderSide(
                    color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  minimumSize: const Size(double.infinity, 42),
                ),
                onPressed: _checkAppUpdate,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  AppStrings.checkUpdateBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // 5. App Info Footer
        Center(
          child: Text(
            AppStrings.settingsAbout,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMetaChip(IconData icon, String label, bool isDark, [bool isPaper2 = false]) {
    final chipColor = isPaper2
        ? const Color(0xFFA78BFA)
        : (isDark ? AppColors.sealGoldLight : const Color(0xFF0284C7));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPyqCarousel(bool isDark) {
    final carouselList = _carouselItems;
    if (carouselList.isEmpty) {
      return _buildHeroBookletCard(isDark);
    }

    final isPaper2 = ExamService.instance.isPaper2;
    final isHi = LanguageService.instance.isHindi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (isPaper2 ? const Color(0xFF8B5CF6) : AppColors.sealGold).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: isPaper2 ? const Color(0xFF8B5CF6) : AppColors.sealGold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isPaper2
                      ? (isHi ? 'विगत वर्ष प्रश्न-पत्र' : 'Previous Year Papers')
                      : (isHi ? 'विगत वर्ष एवं मॉडल प्रश्न-पत्र' : 'Previous Papers & Mocks'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_currentCarouselPage + 1}/${carouselList.length} ${isHi ? "प्रश्न-पत्र" : "Papers"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaper2 ? const Color(0xFFA78BFA) : (isDark ? AppColors.sealGoldLight : const Color(0xFF0284C7)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Swipeable Carousel PageView
        SizedBox(
          height: 220,
          child: PageView.builder(
            key: ValueKey('hero_carousel_${ExamService.instance.selectedPaper}_${carouselList.length}'),
            controller: _heroCarouselController,
            itemCount: carouselList.length,
            onPageChanged: (idx) {
              setState(() => _currentCarouselPage = idx);
            },
            itemBuilder: (context, index) {
              final form = carouselList[index];
              final formId = form['id'] as String;
              final title = AppStrings.formatPaperTitle(form, isHindi: isHi);
              final rawSet = form['set_code']?.toString() ?? 'SET';
              final stampParts = AppStrings.getStampParts(rawSet, isHindi: isHi);
              final isPyq = rawSet.contains('20') || rawSet == 'PYQ' || (form['is_pyq'] == 1);
              final isLatest = index == 0 && isPyq;
              final isCardFree = PremiumService.instance.isPaperFree(formId: formId, index: index);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? (isPaper2
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0F172A), Color(0xFF3B0764)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0F172A), Color(0xFF0C4A6E)],
                            ))
                      : (isPaper2
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Color(0xFFFAF5FF)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Color(0xFFF0F9FF)],
                            )),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPaper2
                        ? const Color(0xFF8B5CF6)
                        : (isDark ? AppColors.sealGold : const Color(0xFF0284C7)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Row: Stamp Badge (Left) + Class & Status Badges (Right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Stamp Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: Border.all(
                              color: isPaper2
                                  ? const Color(0xFF8B5CF6)
                                  : (isDark ? AppColors.sealGold : const Color(0xFF0284C7)),
                              width: 1.4,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                stampParts.top,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: isPaper2
                                      ? const Color(0xFFA78BFA)
                                      : (isDark ? AppColors.sealGoldLight : const Color(0xFF0284C7)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                stampParts.bottom,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isPaper2
                                      ? const Color(0xFFA78BFA)
                                      : (isDark ? AppColors.sealGoldLight : const Color(0xFF0284C7)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badges (Right) - Wrapped in Flexible FittedBox to prevent any overflow on narrow screens
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCardFree) ...[
                                  AppBadge(
                                    label: isHi ? 'निःशुल्क' : 'FREE',
                                    color: AppColors.correctGreen,
                                    isSolid: true,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                AppBadge(
                                  label: isPaper2
                                      ? (isHi ? 'कक्षा 6-8' : 'Classes 6-8')
                                      : (isHi ? 'कक्षा 1-5' : 'Classes 1-5'),
                                  color: isPaper2 ? const Color(0xFF8B5CF6) : const Color(0xFF0284C7),
                                  isSolid: false,
                                ),
                                const SizedBox(width: 5),
                                AppBadge(
                                  label: isPyq
                                      ? (isLatest ? (isHi ? '✨ नवीन' : '✨ LATEST') : (isHi ? 'विगत वर्ष' : 'PAST PAPER'))
                                      : (isHi ? '2026 मॉडल' : '2026 MOCK'),
                                  color: isPyq ? (isLatest ? AppColors.correctGreen : AppColors.violet) : AppColors.sealGold,
                                  isSolid: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Full Width Title (Two lines max, never truncates into `...`)
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),

                    // Subtitle
                    Text(
                      isPyq
                          ? (isHi ? '150 प्रामाणिक प्रश्न · सम्पूर्ण हल सहित' : '150 Authentic Questions · Complete Solutions')
                          : (isHi ? '150 सम्भावित प्रश्न · 2026 परीक्षा पैटर्न' : '150 Predicted Questions · 2026 Exam Pattern'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      ),
                    ),

                    // Meta Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetaChip(Icons.quiz_outlined, isHi ? '150 प्रश्न' : '150 Questions', isDark, isPaper2),
                        _buildMetaChip(Icons.timer_outlined, isHi ? '150 मिनट' : '150 Minutes', isDark, isPaper2),
                        _buildMetaChip(Icons.military_tech_outlined, isHi ? '150 अंक' : '150 Marks', isDark, isPaper2),
                      ],
                    ),

                    // Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPaper2
                            ? (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED))
                            : (isDark ? AppColors.sealGold : const Color(0xFF0284C7)),
                        foregroundColor: (isPaper2 || !isDark) ? Colors.white : AppColors.darkBg,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(double.infinity, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 1,
                      ),
                      onPressed: () {
                        final isFree = PremiumService.instance.isPaperFree(formId: formId, index: index);
                        final isUnlocked = PremiumService.instance.isPremiumUnlocked.value;
                        if (!isFree && !isUnlocked) {
                          PremiumPaywallModal.show(context);
                          return;
                        }
                        final randSeed = Random().nextInt(999999);
                        final config = MockConfig(
                          mode: isPyq ? MockMode.pyq : MockMode.predicted,
                          seed: randSeed,
                          totalQuestions: 150,
                          timeLimitMinutes: 150,
                          exam: ExamService.instance.examCode,
                        );
                        _startMockTest(
                          config,
                          formId: formId,
                          paperTitle: title,
                          setCode: AppStrings.formatSetBadge(rawSet, isHindi: isHi),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 18,
                            color: (isPaper2 || !isDark) ? Colors.white : AppColors.darkBg,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isHi ? 'प्रश्न-पुस्तिका हल करें' : 'Start Test Booklet',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: (isPaper2 || !isDark) ? Colors.white : AppColors.darkBg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Carousel Dot Indicators
        if (carouselList.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(carouselList.length, (dotIdx) {
              final isSelected = dotIdx == _currentCarouselPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 20 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isPaper2
                          ? const Color(0xFF8B5CF6)
                          : (isDark ? AppColors.sealGold : const Color(0xFF0284C7)))
                      : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroBookletCard(bool isDark) {
    final featuredForm = _paperForms.isNotEmpty ? _paperForms.first : null;
    final featuredFormId = featuredForm?['id'] as String?;
    final rawBadge = featuredForm?['set_code']?.toString() ?? 'M-01';
    final stampParts = AppStrings.getStampParts(rawBadge, isHindi: AppStrings.isHindi);
    final featuredTitle = featuredForm != null ? AppStrings.formatPaperTitle(featuredForm) : AppStrings.heroTitle;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.sealGold,
          width: 2.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Hit-Rate Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: AppColors.sealGold,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppStrings.hitRibbon,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Paper Stamp Box
                    Container(
                      constraints: const BoxConstraints(minWidth: 54, minHeight: 54),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stampParts.top,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              stampParts.bottom,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  featuredTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                              AppBadge(
                                label: AppStrings.premiumFreeBadge,
                                color: AppColors.correctGreen,
                                isSolid: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.heroDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Meta Info Box (Wrap - 100% overflow safe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 16,
                            color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            AppStrings.heroTotalQuestions,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            AppStrings.heroTime,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.military_tech_outlined,
                            size: 16,
                            color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            AppStrings.heroMarks,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action Button: Open Booklet
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.sealGold : AppColors.primary,
                    foregroundColor: isDark ? AppColors.darkBg : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    final randSeed = Random().nextInt(999999);
                    final config = MockConfig(
                      mode: MockMode.predicted,
                      seed: randSeed,
                      totalQuestions: 150,
                      timeLimitMinutes: 150,
                      exam: ExamService.instance.examCode,
                    );
                    _startMockTest(config, formId: featuredFormId);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 22,
                        color: isDark ? AppColors.darkBg : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.heroBtn,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkBg : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookletTile({
    required String setChar,
    required String title,
    required String subtitle,
    required String tag,
    required Color tagColor,
    required MockMode mode,
    required bool isDark,
    String? formId,
    bool isFree = false,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.instance.isPremiumUnlocked,
      builder: (context, isUnlocked, _) {
        final bool canOpen = isFree || isUnlocked;

        return InkWell(
          onTap: () {
            if (!canOpen) {
              PremiumPaywallModal.show(context);
              return;
            }
            final randSeed = Random().nextInt(999999);
            final config = MockConfig(
              mode: mode,
              seed: randSeed,
              totalQuestions: 150,
              timeLimitMinutes: 150,
              exam: ExamService.instance.examCode,
            );
            _startMockTest(
              config,
              formId: formId,
              paperTitle: title,
              setCode: setChar,
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Builder(
            builder: (context) {
              final isHi = LanguageService.instance.isHindi;
              final stampParts = AppStrings.getStampParts(setChar, isHindi: isHi);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    // Clean Adaptive SET Stamp (Never overflows)
                    Container(
                      constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stampParts.top,
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              stampParts.bottom,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (canOpen)
                            AppBadge(label: tag, color: tagColor)
                          else
                            AppBadge(
                              label: AppStrings.premiumLockedBadge,
                              color: AppColors.sealGold,
                              isSolid: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),
                Icon(
                  canOpen ? Icons.arrow_forward_ios_rounded : Icons.lock_rounded,
                  size: canOpen ? 18 : 22,
                  color: canOpen
                      ? (isDark ? AppColors.darkIconMuted : AppColors.lightIconMuted)
                      : AppColors.sealGold,
                ),
              ],
            ),
          );
        },
      ),
    );
  },
);
  }

  Widget _buildSubjectGrid(bool isDark) {
    final isPaper2 = ExamService.instance.isPaper2;
    final isHi = LanguageService.instance.isHindi;
    final List<Map<String, dynamic>> subjects = isPaper2
        ? [
            {'sec': 'cdp', 'name': AppStrings.sectionName('cdp'), 'color': AppColors.cdp, 'label': isHi ? 'खण्ड I' : 'Section I'},
            {'sec': 'hindi', 'name': AppStrings.sectionName('hindi'), 'color': AppColors.hindi, 'label': isHi ? 'खण्ड II' : 'Section II'},
            {'sec': 'english', 'name': AppStrings.sectionName('english'), 'color': AppColors.english, 'label': isHi ? 'खण्ड III' : 'Section III'},
            {'sec': 'math', 'name': AppStrings.sectionName('math'), 'color': AppColors.math, 'label': isHi ? 'खण्ड IV (A)' : 'Section IV (A)'},
            {'sec': 'science', 'name': AppStrings.sectionName('science'), 'color': AppColors.science, 'label': isHi ? 'खण्ड IV (B)' : 'Section IV (B)'},
            {'sec': 'social', 'name': AppStrings.sectionName('social'), 'color': AppColors.social, 'label': isHi ? 'खण्ड IV (C)' : 'Section IV (C)'},
          ]
        : [
            {'sec': 'cdp', 'name': AppStrings.sectionName('cdp'), 'color': AppColors.cdp, 'label': isHi ? 'खण्ड I' : 'Section I'},
            {'sec': 'hindi', 'name': AppStrings.sectionName('hindi'), 'color': AppColors.hindi, 'label': isHi ? 'खण्ड II' : 'Section II'},
            {'sec': 'english', 'name': AppStrings.sectionName('english'), 'color': AppColors.english, 'label': isHi ? 'खण्ड III' : 'Section III'},
            {'sec': 'math', 'name': AppStrings.sectionName('math'), 'color': AppColors.math, 'label': isHi ? 'खण्ड IV' : 'Section IV'},
            {'sec': 'evs', 'name': AppStrings.sectionName('evs'), 'color': AppColors.evs, 'label': isHi ? 'खण्ड V' : 'Section V'},
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: subjects.map((s) {
            final sec = s['sec'] as String;
            final name = AppStrings.sectionName(sec);
            final color = s['color'] as Color;
            final label = s['label'] as String;

            return SizedBox(
              width: itemWidth,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SubjectDetailScreen(
                        section: sec,
                        sectionName: name,
                        sectionColor: color,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.subjectCardSetsInfo,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _openHistorySession(Map<String, dynamic> history) async {
    final raw = history['session_json']?.toString();
    if (raw == null || raw.isEmpty || raw == '{}') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('इस पुराने परिणाम का विस्तृत विवरण उपलब्ध नहीं है।'),
        ),
      );
      return;
    }

    try {
      final session = TestSession.decode(raw);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(session: session, fromHistory: true),
        ),
      );
    } catch (error) {
      debugPrint('Unable to reopen history session: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('परिणाम खोलने में त्रुटि हुई।')),
      );
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> h, bool isDark) {
    final score = (h['score'] as num?)?.toInt() ?? 0;
    final total = (h['total'] as num?)?.toInt() ?? 150;
    final mode = h['mode'] as String? ?? 'predicted';
    final isPass = ExamRules.isGeneralPass(score, total);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openHistorySession(h),
          child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isPass ? AppColors.success : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.historyMockType(mode),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          isPass ? AppStrings.historyQualified : AppStrings.historyPracticeNeeded,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPass ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '$score / $total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
