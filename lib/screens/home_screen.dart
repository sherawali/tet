import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../design_system/app_colors.dart';
import '../design_system/app_dialogs.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_shadows.dart';
import '../design_system/app_spacing.dart';
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
import '../services/section_catalog.dart';
import '../services/bank_facts.dart';
import '../services/exam_rules.dart';
import '../widgets/premium_paywall_modal.dart';
import '../widgets/question_report_sheet.dart';
import '../design_system/app_motion.dart';
import '../design_system/app_sheet.dart';

/// One card look for the whole home screen.
///
/// Every surface of this screen shares the same radius, the same border and
/// the same shadow, so the screen reads as one premium sheet instead of a
/// pile of differently rounded boxes.
class _HomeCard {
  const _HomeCard._();

  /// The one padding every card uses.
  static const EdgeInsets padding = EdgeInsets.all(AppSpacing.base);

  /// The one radius every card uses.
  static const BorderRadius radius = AppRadius.roundedBase;

  /// The one decoration every card uses.
  static BoxDecoration card(
    bool isDark, {
    Color? borderColor,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: radius,
      border: Border.all(
        color: borderColor ??
            (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        width: borderWidth,
      ),
      boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
    );
  }
}

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
  /// Question count per section for the selected exam and paper.
  Map<String, int> _sectionCounts = <String, int>{};
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
  bool _isCheckingUpdate = false;
  double _syncProgress = 0.0;
  String _syncProgressStatus = '';
  bool _hasRemoteUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkRemoteUpdateSilently();
    SyncService.onDatabaseUpdated.addListener(_onDatabaseUpdatedListener);
    // The stream can also be changed in the PYQ vault, so the home screen
    // has to follow it.
    ExamService.instance.currentStream.addListener(_onStreamChanged);
    // A flexible update downloads in the background; when the store says the
    // new version is ready, offer the restart here (the home screen lives
    // for the whole session, the splash screen does not).
    InAppUpdateService.instance.flexibleUpdateReady.addListener(
      _onFlexibleUpdateReady,
    );
  }

  void _onFlexibleUpdateReady() {
    if (!InAppUpdateService.instance.flexibleUpdateReady.value) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.updateReadyToast),
        duration: const Duration(seconds: 60),
        action: SnackBarAction(
          label: AppStrings.updateRestartBtn,
          onPressed: () {
            InAppUpdateService.instance.completeFlexibleUpdate();
          },
        ),
      ),
    );
  }

  void _onStreamChanged() {
    if (mounted) {
      _loadData();
    }
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
          duration: AppMotion.page,
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
    ExamService.instance.currentStream.removeListener(_onStreamChanged);
    InAppUpdateService.instance.flexibleUpdateReady.removeListener(
      _onFlexibleUpdateReady,
    );
    super.dispose();
  }

  /// Re-reads the stored test history (a finished test is written while the
  /// candidate is away from this screen).
  Future<void> _refreshHistoryIfNeeded() async {
    try {
      final history = await _db.getTestHistory();
      if (!mounted) return;
      if (history.length == _history.length) {
        final newest = history.isNotEmpty ? history.first['timestamp'] : null;
        final currentNewest =
            _history.isNotEmpty ? _history.first['timestamp'] : null;
        if (newest == currentNewest) return;
      }
      setState(() => _history = history);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final currentExam = ExamService.instance.examCode;
    final total = await _db.getQuestionCount(currentExam);
    final pyq = await _db.getPyqCount(currentExam);
    final history = await _db.getTestHistory();
    final years = await _db.getDistinctPyqYears(
      currentExam,
      ExamService.instance.selectedPaper,
    );

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

    await BankFacts.refresh(_db);
    final examName = ExamService.instance.isUtet ? 'utet' : 'ctet';
    final sectionCounts = await _db.getSectionCountsForPaper(
      exam: examName,
      paper: ExamService.instance.selectedPaper,
    );
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
        _sectionCounts = sectionCounts;
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

    AppSheet.show(
      context,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top drag notch
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.base),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(AppRadius.full),
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
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  Text(
                    isAdded
                        ? AppStrings.syncSuccessAddedTitle(result.newQuestionsAdded)
                        : (isUpToDate
                            ? AppStrings.syncUpToDateTitle
                            : AppStrings.syncErrorTitle),
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ).copyWith(letterSpacing: 0.3),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Subtitle
                  Text(
                    isAdded
                        ? AppStrings.syncSuccessAddedDesc(result.totalCount)
                        : (isUpToDate
                            ? AppStrings.syncUpToDateDesc(result.totalCount)
                            : AppStrings.syncErrorDesc(result.message)),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Metric Chips
                  if (result.success)
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sealGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.sealGold, width: 1),
                          ),
                          child: Text(
                            AppStrings.syncTotalQuestionsChip(result.totalCount),
                            style: AppTypography.labelMedium(
                              color: AppColors.sealGold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.correctGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.correctGreen, width: 1),
                          ),
                          child: Text(
                            AppStrings.syncOfflineChip,
                            style: AppTypography.labelMedium(
                              color: AppColors.correctGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.lg),

                  // Action button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAdded
                          ? AppColors.sealGold
                          : (isDark ? AppColors.darkCardElevated : AppColors.primary),
                      foregroundColor: isAdded
                          ? AppColors.primaryDark
                          : AppColors.darkTextPrimary,
                      minimumSize: const Size(double.infinity, 44),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
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
                      style: AppTypography.labelMedium(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                AppStrings.dbOptimizingToast,
                style: AppTypography.labelMedium(),
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
    final confirmed = await AppDialogs.confirm(
      context,
      title: AppStrings.dbCleanDialogTitle,
      message: AppStrings.dbCleanDialogDesc,
      confirmLabel: AppStrings.dbCleanConfirmBtn,
      cancelLabel: AppStrings.dbCancelBtn,
      destructive: true,
      icon: Icons.cleaning_services_rounded,
      isHindi: AppStrings.isHindi,
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

    AppSheet.show(
      context,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border.all(color: AppColors.sealGold, width: 1.5),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.base),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(AppRadius.full),
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
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.dbOptimizeDoneTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.dbOptimizeDoneDesc(savedKb),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sealGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.sealGold, width: 1),
                        ),
                        child: Text(
                          AppStrings.dbTotalQuestionsChip(totalQ),
                          style: AppTypography.labelMedium(color: AppColors.sealGold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.correctGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.correctGreen, width: 1),
                        ),
                        child: Text(
                          AppStrings.dbSpaceFreedChip(savedKb),
                          style: AppTypography.labelMedium(color: AppColors.correctGreen),
                        ),
                      ),
                      if (orphanDeleted > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.primary, width: 1),
                          ),
                          child: Text(
                            AppStrings.dbOrphanDeletedChip(orphanDeleted),
                            style: AppTypography.labelMedium(color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sealGold,
                      foregroundColor: AppColors.primaryDark,
                      minimumSize: const Size(double.infinity, 44),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(AppStrings.syncContinueBtn, style: AppTypography.labelMedium()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          AppStrings.doubleBackExit,
                          style: AppTypography.labelMedium(
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.primary, // Deep Slate Navy
                  elevation: 8,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.base,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: _HomeCard.radius,
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
              foregroundColor: AppColors.darkTextPrimary,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.sealGold.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.sealGold, width: 1.2),
                            ),
                            child: Text(
                              ExamService.instance.shortNameWithPaper,
                              style: AppTypography.labelMedium(
                                color: AppColors.sealGoldSubtle,
                              ).copyWith(letterSpacing: 0.5),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.appTitle,
                          style: AppTypography.titleSmall(
                            color: AppColors.darkTextPrimary,
                          ).copyWith(letterSpacing: 0.3),
                        ),
                        Text(
                          AppStrings.appSubtitle,
                          style: AppTypography.labelSmall(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.darkTextSecondary,
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
                    color: AppColors.goldBright,
                  ),
                  onPressed: () => ReportedQuestionsSheet.show(context),
                ),
                IconButton(
                  tooltip: _syncActionLabel,
                  icon: Icon(
                    Icons.sync_rounded,
                    color: isDark ? AppColors.sealGoldLight : AppColors.darkTextPrimary,
                  ),
                  onPressed: _isSyncing ? null : _syncNow,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedTab,
              onTap: (idx) => setState(() => _selectedTab = idx),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              selectedItemColor: isDark ? AppColors.sealGoldLight : AppColors.primary,
              unselectedItemColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              selectedLabelStyle: AppTypography.labelMedium(),
              unselectedLabelStyle: AppTypography.labelSmall(),
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
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        margin:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                        decoration: _HomeCard.card(isDark),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.sealGold),
                            const SizedBox(height: AppSpacing.base),
                            Text(
                              AppStrings.loadingGenerating,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelMedium(
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      children: [
        // 1. Target Exam Switcher (UTET / CTET)
        _buildExamSwitcher(isDark),

        // Remote Test & Question Bank Update Notification Banner
        if (_hasRemoteUpdate) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: _HomeCard.radius,
              border: Border.all(color: AppColors.accentBright, width: 1.5),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.accentBright,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_download_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHi ? '📢 नया प्रश्न बैंक व टेस्ट उपलब्ध है!' : '📢 New Test Bank & Mocks Available!',
                        style: AppTypography.labelMedium(color: AppColors.darkTextPrimary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        isHi ? 'नवीनतम प्रश्न व सुधार ऑफ़लाइन डाउनलोड करने के लिए टैप करें।' : 'Tap to sync latest questions for offline practice.',
                        style: AppTypography.labelSmall(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBright,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: const Size(0, 32),
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
                  ),
                  onPressed: _isSyncing ? null : _syncNow,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isSyncing ? _syncingLabel : _syncActionLabel,
                      style: AppTypography.labelSmall(),
                    ),
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
        const SizedBox(height: AppSpacing.base),

        // 3. Section Heading: Complete Exam Booklets
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: ExamService.instance.isPaper2 ? AppColors.violetBright : AppColors.sealGold,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _mockForms.isNotEmpty
                    ? (isHi
                        ? '2026 मॉडल प्रश्न-पत्र (${_mockForms.length} सेट)'
                        : '2026 Model Test Papers (${_mockForms.length} Sets)')
                    : (isHi
                        ? 'विगत वर्ष प्रश्न-पत्र (${_paperForms.length} सेट)'
                        : 'Previous Year Solved Papers (${_paperForms.length} Sets)'),
                style: AppTypography.titleMedium(
                  color:
                      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
            if (ExamService.instance.isPaper2) ...[
              const SizedBox(width: AppSpacing.sm),
              _buildStreamBadge(isDark),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        if ((_mockForms.isNotEmpty ? _mockForms : _paperForms).isNotEmpty) ...[
          ...(_mockForms.isNotEmpty ? _mockForms : _paperForms).asMap().entries.map((entry) {
            final idx = entry.key;
            final f = entry.value;
            final formId = f['id'] as String;
            final title = _paperTitle(f, isHi: isHi);
            final rawSet = f['set_code']?.toString() ?? 'SET ${(idx + 1).toString().padLeft(2, "0")}';
            final setChar = AppStrings.formatSetBadge(rawSet, isHindi: isHi);
            final isFree = PremiumService.instance.isPaperFree(formId: formId, index: idx);
            final isPyq = rawSet == 'PYQ' || rawSet.contains('20');
            final tag = isFree
                ? (isHi ? 'निःशुल्क' : 'FREE')
                : (isPyq
                    ? (isHi ? 'विगत वर्ष' : 'PAST PAPER')
                    : (isHi ? '${BankFacts.questionsPerPaper} प्रश्न सेट' : '${BankFacts.questionsPerPaper}Q Mock Set'));
            final tagColor = isFree
                ? AppColors.correctGreen
                : (isPyq ? AppColors.violet : AppColors.sealGold);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildBookletTile(
                setChar: setChar,
                title: title,
                subtitle: isHi
                    ? '${BankFacts.questionsPerPaper} प्रश्न · ${BankFacts.questionsPerPaper} मिनट · सम्पूर्ण हल सहित'
                    : '${BankFacts.questionsPerPaper} Questions · ${BankFacts.questionsPerPaper} Mins · Complete Solutions',
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
                ? '${BankFacts.questionsPerPaper} प्रश्न · ${BankFacts.questionsPerPaper} मिनट · सम्पूर्ण हल सहित'
                : '${BankFacts.questionsPerPaper} Questions · ${BankFacts.questionsPerPaper} Mins · Complete Solutions',
            tag: isHi ? 'निःशुल्क' : 'FREE',
            tagColor: AppColors.correctGreen,
            mode: MockMode.predicted,
            isDark: isDark,
            isFree: true,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }



  /// The title of a paper.
  ///
  /// A paper-2 title always names the stream the paper belongs to, so a
  /// Social Studies paper is never mistaken for a Mathematics & Science paper
  /// and the other way round.
  String _paperTitle(Map<String, dynamic> form, {required bool isHi}) {
    final title = AppStrings.formatPaperTitle(form, isHindi: isHi);
    final paper = form['paper'] is int
        ? form['paper'] as int
        : (form['id']?.toString().contains('p2') == true ? 2 : 1);
    if (paper != 2) return title;

    final social = ExamService.instance.isSocialStream;
    final tag = social
        ? (isHi ? '(सामाजिक अध्ययन)' : '(Social Studies)')
        : (isHi ? '(गणित एवं विज्ञान)' : '(Mathematics & Science)');
    // A title that already names a stream is left alone, so the stream is
    // never written twice.
    final markers = ['Social Studies', 'सामाजिक अध्ययन', 'Mathematics & Science', 'गणित एवं विज्ञान'];
    for (final marker in markers) {
      if (title.contains(marker)) return title;
    }

    const separator = ' · ';
    final index = title.indexOf(separator);
    if (index < 0) return '$title$separator$tag';
    return '${title.substring(0, index + separator.length)}'
        '$tag$separator${title.substring(index + separator.length)}';
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
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.primarySubtle,
                borderRadius: _HomeCard.radius,
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
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: AnimatedContainer(
                            duration: AppMotion.base,
                            curve: AppMotion.standard,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: !isCtet
                                  ? (isDark ? AppColors.sealGold : AppColors.primary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              boxShadow: !isCtet ? AppShadows.soft : null,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🌲 UTET',
                                    style: AppTypography.labelMedium(
                                      color: !isCtet
                                          ? (isDark ? AppColors.darkBg : AppColors.darkTextPrimary)
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    AppStrings.isHindi ? '(उत्तराखण्ड)' : '(Uttarakhand)',
                                    style: AppTypography.labelSmall(
                                      color: !isCtet
                                          ? (isDark ? AppColors.darkBg.withValues(alpha: 0.8) : AppColors.darkTextSecondary)
                                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (!isCtet) {
                              await ExamService.instance.setExam(AppExam.ctet);
                              _loadData();
                            }
                          },
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: AnimatedContainer(
                            duration: AppMotion.base,
                            curve: AppMotion.standard,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isCtet
                                  ? (isDark ? AppColors.sealGold : AppColors.primary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              boxShadow: isCtet ? AppShadows.soft : null,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🏛️ CTET',
                                    style: AppTypography.labelMedium(
                                      color: isCtet
                                          ? (isDark ? AppColors.darkBg : AppColors.darkTextPrimary)
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    AppStrings.isHindi ? '(केन्द्रीय)' : '(Central)',
                                    style: AppTypography.labelSmall(
                                      color: isCtet
                                          ? (isDark ? AppColors.darkBg.withValues(alpha: 0.8) : AppColors.darkTextSecondary)
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

                  const SizedBox(height: AppSpacing.sm),

                  // Row 2: Paper Switcher (Paper-1: Class 1-5 vs Paper-2: Class 6-8)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCardElevated
                          : AppColors.lightCard,
                      borderRadius: _HomeCard.radius,
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
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: AnimatedContainer(
                              duration: AppMotion.base,
                              curve: AppMotion.standard,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                                horizontal: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: !isP2
                                    ? (isDark ? AppColors.accent.withValues(alpha: 0.22) : AppColors.accentSoft)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: !isP2
                                    ? Border.all(color: AppColors.accent, width: 1.5)
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
                                      color: !isP2 ? AppColors.accent : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      AppStrings.paper1Label,
                                      style: AppTypography.labelSmall(
                                        color: !isP2
                                            ? (isDark ? AppColors.accentBright : AppColors.accentDark)
                                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              if (!isP2) {
                                _carouselTimer?.cancel();
                                await ExamService.instance.setPaper(AppPaper.paper2);
                                _loadData();
                              }
                            },
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: AnimatedContainer(
                              duration: AppMotion.base,
                              curve: AppMotion.standard,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                                horizontal: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: isP2
                                    ? (isDark ? AppColors.violetBright.withValues(alpha: 0.25) : AppColors.violetSoft)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: isP2
                                    ? Border.all(color: AppColors.violetBright, width: 1.5)
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
                                      color: isP2 ? AppColors.violetBright : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      AppStrings.paper2Label,
                                      style: AppTypography.labelSmall(
                                        color: isP2
                                            ? (isDark ? AppColors.violetLight : AppColors.violet)
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
                  _buildStreamSwitcherRow(isDark),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Paper 2 has two streams (Mathematics & Science / Social Studies).
  /// Without this row the candidate cannot tell which one a paper belongs
  /// to, so the stream is always visible and switchable.
  Widget _buildStreamSwitcherRow(bool isDark) {
    if (!ExamService.instance.isPaper2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppStrings.streamSwitcherLabel,
              style: AppTypography.labelSmall(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardElevated : AppColors.lightCard,
            borderRadius: _HomeCard.radius,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStreamOption(isDark, social: false),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildStreamOption(isDark, social: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreamOption(bool isDark, {required bool social}) {
    final active = ExamService.instance.isSocialStream == social;
    const streamBlue = AppColors.accent;
    const streamViolet = AppColors.violetBright;
    final accent = social ? streamViolet : streamBlue;
    final accentText = social
        ? (isDark ? AppColors.violetLight : AppColors.violet)
        : (isDark ? AppColors.accentBright : AppColors.accentDark);
    final tint = social
        ? (isDark ? streamViolet.withValues(alpha: 0.25) : AppColors.violetSoft)
        : (isDark ? streamBlue.withValues(alpha: 0.22) : AppColors.accentSoft);

    return InkWell(
      onTap: () async {
        if (active) return;
        await ExamService.instance.setStream(
          social ? AppStream.socialStudies : AppStream.mathScience,
        );
        if (!mounted) return;
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.streamChanged)),
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.standard,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: active ? tint : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: active ? Border.all(color: accent, width: 1.5) : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 13,
                color: active
                    ? accent
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                social ? AppStrings.streamSocialStudies : AppStrings.streamMathScience,
                style: AppTypography.labelSmall(
                  color: active
                      ? accentText
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsExamCard(bool isDark) {
    return _settingsCard(
      isDark: isDark,
      icon: Icons.school_rounded,
      title: AppStrings.targetExamHeading,
      subtitle: AppStrings.isHindi
          ? 'मॉक टेस्ट और प्रश्न-पत्र बदलने के लिए परीक्षा चुनें'
          : 'Select exam to switch mock papers & questions',
      children: [
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
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                          horizontal: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: !isCtet
                              ? AppColors.sealGold.withValues(alpha: 0.2)
                              : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
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
                                color: !isCtet
                                    ? AppColors.sealGold
                                    : (isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted),
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '🌲 UTET I & II',
                                style: AppTypography.labelMedium(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        if (!isCtet) {
                          await ExamService.instance.setExam(AppExam.ctet);
                          _loadData();
                        }
                      },
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                          horizontal: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: isCtet
                              ? AppColors.sealGold.withValues(alpha: 0.2)
                              : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
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
                                color: isCtet
                                    ? AppColors.sealGold
                                    : (isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted),
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '🏛️ CTET',
                                style: AppTypography.labelMedium(),
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
          const SizedBox(height: AppSpacing.md),

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
                    style: AppTypography.labelMedium(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: !isP2
                                  ? AppColors.sealGold.withValues(alpha: 0.2)
                                  : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
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
                                    color: !isP2
                                      ? AppColors.sealGold
                                      : (isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted),
                                    size: 16,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    AppStrings.paper1Tab,
                                    style: AppTypography.labelMedium(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (!isP2) {
                              await ExamService.instance.setPaper(AppPaper.paper2);
                              _loadData();
                            }
                          },
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isP2
                                  ? AppColors.sealGold.withValues(alpha: 0.2)
                                  : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
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
                                    color: isP2
                                      ? AppColors.sealGold
                                      : (isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted),
                                    size: 16,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    AppStrings.paper2Tab,
                                    style: AppTypography.labelMedium(),
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
    );
  }

  /// Debug only: lets the tester look at the paid app and the free app
  /// without paying anything.  The card is not part of a release build.
  Widget _buildDebugProPassCard(bool isDark) {
    return _settingsCard(
      isDark: isDark,
      icon: Icons.bug_report_rounded,
      iconColor: AppColors.correctGreen,
      title: AppStrings.debugProPassTitle,
      subtitle: AppStrings.debugProPassDesc,
      children: [
          ValueListenableBuilder<bool>(
            valueListenable: PremiumService.instance.isPremiumUnlocked,
            builder: (context, isUnlocked, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: isUnlocked,
                    onChanged: (value) async {
                      await PremiumService.instance.setDebugPremiumOverride(value);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? AppStrings.debugProPassPaid
                                : AppStrings.debugProPassFree,
                          ),
                        ),
                      );
                    },
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.correctGreen,
                    title: Text(
                      isUnlocked
                          ? AppStrings.debugProPassPaid
                          : AppStrings.debugProPassFree,
                      style: AppTypography.labelMedium(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      AppStrings.debugProPassSwitchSub,
                      style: AppTypography.labelSmall(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildSettingsTestModeCard(bool isDark) {
    return _settingsCard(
      isDark: isDark,
      icon: Icons.devices_rounded,
      title: AppStrings.testModeHeader,
      subtitle: AppStrings.testModeDesc,
      children: [
          ValueListenableBuilder<AppTestMode>(
            valueListenable: ExamService.instance.currentTestMode,
            builder: (context, currentMode, _) {
              final isCbt = currentMode == AppTestMode.cbt;
              return Column(
                children: [
                  // Option 1: CBT Mode (Recommended)
                  InkWell(
                    onTap: () => ExamService.instance.setTestMode(AppTestMode.cbt),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.standard,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isCbt
                            ? AppColors.sealGold.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isCbt ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: isCbt ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCbt ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isCbt
                                ? AppColors.sealGold
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.cbtModeTitle,
                                  style: AppTypography.labelMedium(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  AppStrings.cbtModeSub,
                                  style: AppTypography.labelSmall(
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
                  const SizedBox(height: AppSpacing.sm),

                  // Option 2: Booklet Mode
                  InkWell(
                    onTap: () => ExamService.instance.setTestMode(AppTestMode.booklet),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.standard,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: !isCbt
                            ? AppColors.sealGold.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: !isCbt ? AppColors.sealGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: !isCbt ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !isCbt ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: !isCbt
                                ? AppColors.sealGold
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.bookletModeTitle,
                                  style: AppTypography.labelMedium(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  AppStrings.bookletModeSub,
                                  style: AppTypography.labelSmall(
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
    );
  }

  Widget _buildSettingsTetLanguagesCard(bool isDark) {
    return _settingsCard(
      isDark: isDark,
      icon: Icons.school_rounded,
      title: AppStrings.langCardTitle,
      subtitle: AppStrings.langCardSubtitle,
      children: [
          ValueListenableBuilder<String>(
        valueListenable: ExamService.instance.currentLang1,
        builder: (context, lang1, _) {
          return ValueListenableBuilder<String>(
            valueListenable: ExamService.instance.currentLang2,
            builder: (context, lang2, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: भाषा प्रथम
                  Row(
                    children: [
                      const Icon(Icons.looks_one_rounded, color: AppColors.sealGold, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        AppStrings.lang1Heading,
                        style: AppTypography.labelMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _buildLangChoiceChip(
                        title: AppStrings.langHindiLabel,
                        selected: lang1 == 'hindi',
                        onTap: () => ExamService.instance.setLang1('hindi'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildLangChoiceChip(
                        title: AppStrings.langEnglishLabel,
                        selected: lang1 == 'english',
                        onTap: () => ExamService.instance.setLang1('english'),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Section 2: भाषा द्वितीय
                  Row(
                    children: [
                      const Icon(Icons.looks_two_rounded, color: AppColors.sealGold, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        AppStrings.lang2Heading,
                        style: AppTypography.labelMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _buildLangChoiceChip(
                        title: AppStrings.langEnglishLabel,
                        selected: lang2 == 'english',
                        onTap: () => ExamService.instance.setLang2('english'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildLangChoiceChip(
                        title: AppStrings.langHindiLabel,
                        selected: lang2 == 'hindi',
                        onTap: () => ExamService.instance.setLang2('hindi'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildLangChoiceChip(
                        title: '🔒 ${AppStrings.langSanskritLabel}',
                        selected: false,
                        onTap: () => _showSanskritUpcomingDialog(context),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Info box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.primary : AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.sealGold),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            AppStrings.langNotice,
                            style: AppTypography.labelSmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.deskGray,
                            ).copyWith(height: 1.35),
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
    ],
    );
  }

  void _showSanskritUpcomingDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.primary : AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.sealGold, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: AppColors.sealGold),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                AppStrings.sanskritUpcomingTitle,
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          AppStrings.sanskritUpcomingDesc,
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ).copyWith(height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sealGold,
              foregroundColor: AppColors.primary,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
            ),
            child: Text(AppStrings.understoodBtn),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // The settings tab
  //
  // Every card of the tab has the same padding, the same radius, the same
  // border and the same shadow, and every action has one wording that is
  // used for the title of its card and for its button.
  // -----------------------------------------------------------------------

  /// The wording of an action of the settings tab.
  String get _syncActionLabel =>
      AppStrings.isHindi ? 'प्रश्न बैंक सिंक करें' : 'Sync the question bank';
  String get _optimizeActionLabel =>
      AppStrings.isHindi ? 'डेटाबेस ऑप्टिमाइज़ करें' : 'Optimise the database';
  String get _updateActionLabel =>
      AppStrings.isHindi ? 'अपडेट की जाँच करें' : 'Check for update';
  String get _resyncActionLabel =>
      AppStrings.isHindi ? 'बैंक फिर से डाउनलोड करें' : 'Re-download the bank';

  /// The wording of an action while it is working.
  String get _syncingLabel =>
      AppStrings.isHindi ? 'सिंक हो रहा है…' : 'Syncing…';
  String get _optimizingLabel =>
      AppStrings.isHindi ? 'ऑप्टिमाइज़ हो रहा है…' : 'Optimising…';
  String get _checkingUpdateLabel =>
      AppStrings.isHindi ? 'जाँच हो रही है…' : 'Checking…';

  /// The message of an action that needs a connection.
  String get _offlineMessage => AppStrings.isHindi
      ? 'आपका डिवाइस ऑफलाइन है। इंटरनेट जोड़कर फिर कोशिश करें।'
      : 'Your device is offline. Connect to the internet and try again.';

  String get _updateFailedMessage => AppStrings.isHindi
      ? 'अपडेट की जाँच नहीं हो सकी। कृपया फिर कोशिश करें।'
      : 'The update could not be checked. Please try again.';

  /// The note about the day the active pass runs out.
  String _passExpiryNote() {
    final service = PremiumService.instance;
    if (service.activeExpiry == null) return '';
    // Day 1 is the last day: the note must not vanish before the lock does.
    final days = service.activePassDaysLeft;
    if (days == null || days <= 0) return '';
    final product = service.activeProductId;
    final renews = product == null
        ? ''
        : ' · ${AppStrings.proPackRenewsAt(service.priceOf(product))}';
    return '${AppStrings.proPackExpirySoon(days)}$renews';
  }

  /// The one card of the settings tab.
  Widget _settingsCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
    Color? iconColor,
  }) {
    final accent = iconColor ?? AppColors.sealGold;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      padding: _HomeCard.padding,
      decoration: _HomeCard.card(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextMuted,
                      ).copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          ...children,
        ],
      ),
    );
  }

  /// One action button of the settings tab.
  ///
  /// The label always fits (it is shortened with an ellipsis when the button
  /// is narrow) and the button shows a spinner while it works.
  Widget _settingsActionButton({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isBusy = false,
    bool isDanger = false,
  }) {
    final foreground = isDanger
        ? AppColors.danger
        : (isDark ? AppColors.sealGoldLight : AppColors.primary);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: isDark
            ? AppColors.darkTextMuted
            : AppColors.lightTextMuted,
        side: BorderSide(
          color: isDanger
              ? AppColors.danger.withValues(alpha: 0.6)
              : foreground.withValues(alpha: 0.7),
          width: 1.2,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        minimumSize: const Size(0, 44),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBusy)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            )
          else
            Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.labelMedium(color: foreground),
            ),
          ),
        ],
      ),
    );
  }

  /// A quick probe that tells whether the device can reach the internet.
  ///
  /// The update check must not pretend to work while the device is offline,
  /// so the button asks the network before it starts.
  Future<bool> _isDeviceOnline() async {
    const probes = <String>[
      'https://www.gstatic.com/generate_204',
      'https://play.googleapis.com',
    ];
    for (final probe in probes) {
      try {
        final response = await http
            .head(Uri.parse(probe))
            .timeout(const Duration(seconds: 6));
        if (response.statusCode < 500) return true;
      } catch (_) {
        // Try the next probe.
      }
    }
    return false;
  }

  Future<void> _checkAppUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    final online = await _isDeviceOnline();
    if (!mounted) return;
    if (!online) {
      setState(() => _isCheckingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_offlineMessage)),
      );
      return;
    }

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
          SnackBar(content: Text(_updateFailedMessage)),
        );
      }
    }
    if (mounted) setState(() => _isCheckingUpdate = false);
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.sealGold.withValues(alpha: 0.2)
                : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                color: selected
                    ? AppColors.sealGold
                    : (isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted),
                size: 15,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  title,
                  style: AppTypography.labelMedium(
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      children: [
        // Subject Section Header Card
        Container(
          padding: _HomeCard.padding,
          decoration: _HomeCard.card(isDark),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.sealGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.category_rounded, color: AppColors.sealGold, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.subjectPracticeHeading,
                      style: AppTypography.titleSmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.subjectPracticeDesc,
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Paper 2 has two streams, so the active one is named here.
              if (ExamService.instance.isPaper2) ...[
                const SizedBox(width: AppSpacing.sm),
                _buildStreamBadge(isDark),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),

        _buildSubjectGrid(isDark),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    // The history is filled while the candidate is inside a test, so it has
    // to be re-read every time the tab is opened - otherwise the list stays
    // empty until the app is restarted.
    _refreshHistoryIfNeeded();
    final passCount = _history.where((h) {
      final s = (h['score'] as num?)?.toInt() ?? 0;
      final t = (h['total'] as num?)?.toInt() ?? BankFacts.questionsPerPaper;
      return ExamRules.isGeneralPass(s, t);
    }).length;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      children: [
        // Heading & Summary
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.historyTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (_history.isNotEmpty)
              Flexible(
                child: AppBadge(
                  label: AppStrings.historySummary(_history.length, passCount),
                  color: AppColors.sealGold,
                  isSolid: true,
                  wrap: true,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        if (_history.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xxl,
            ),
            decoration: _HomeCard.card(isDark),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: AppColors.sealGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_toggle_off_rounded, color: AppColors.sealGold, size: 36),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  AppStrings.historyEmptyTitle,
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.historyEmptyDesc,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                  ).copyWith(height: 1.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sealGold,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    AppStrings.historyStartCta,
                    style: AppTypography.labelMedium(),
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
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildSettingsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      children: [
        // 0. Pro Pass status
        ValueListenableBuilder<bool>(
          valueListenable: PremiumService.instance.isPremiumUnlocked,
          builder: (context, isUnlocked, _) {
            return _settingsCard(
              isDark: isDark,
              icon: isUnlocked
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_outline_rounded,
              title: AppStrings.premiumPassTitle,
              subtitle: isUnlocked
                  ? AppStrings.premiumActiveStatus
                  : AppStrings.premiumPriceBadge,
              children: [
                if (isUnlocked) ...[
                  if (_passExpiryNote().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _passExpiryNote(),
                      style: AppTypography.labelSmall(
                        color: isDark
                            ? AppColors.sealGoldLight
                            : AppColors.sealGold,
                      ).copyWith(height: 1.35),
                    ),
                  ],
                ] else ...[
                  Text(
                    AppStrings.premiumPassSubtitle,
                    style: AppTypography.bodySmall(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextMuted,
                    ).copyWith(height: 1.35),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sealGold,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                          horizontal: AppSpacing.base,
                        ),
                        minimumSize: const Size(0, 44),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.roundedSm,
                        ),
                      ),
                      onPressed: () => PremiumPaywallModal.show(context),
                      icon: const Icon(Icons.stars_rounded, size: 20),
                      label: Text(
                        AppStrings.premiumUnlockBtn,
                        style: AppTypography.labelMedium(),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),

        // 1. Target exam, paper level and the paper-2 stream
        _buildSettingsExamCard(isDark),

        // 1b. Debug only: switch between the free and the paid experience
        if (kDebugMode) _buildDebugProPassCard(isDark),

        // 2. Default test mode (CBT vs booklet)
        _buildSettingsTestModeCard(isDark),

        // 3. The languages of the exam paper
        _buildSettingsTetLanguagesCard(isDark),

        // 4. The language of the app
        _settingsCard(
          isDark: isDark,
          icon: Icons.translate_rounded,
          title: AppStrings.settingsLangHeader,
          subtitle: AppStrings.settingsLangDesc,
          children: [
            ValueListenableBuilder<AppLang>(
              valueListenable: LanguageService.instance.currentLanguage,
              builder: (context, currentLang, _) {
                final isHindi = currentLang == AppLang.hi;
                return Row(
                  children: [
                    Expanded(
                      child: _languageOption(
                        isDark,
                        isSelected: isHindi,
                        label: AppStrings.langHindiLabel,
                        onTap: () =>
                            LanguageService.instance.setLanguage(AppLang.hi),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _languageOption(
                        isDark,
                        isSelected: !isHindi,
                        label: AppStrings.langEnglishLabel,
                        onTap: () =>
                            LanguageService.instance.setLanguage(AppLang.en),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),

        // 5. The offline question bank and the database of the app
        _buildSettingsBankCard(isDark),

        // 6. The analysis model of the exam
        _buildSettingsModelCard(isDark),

        // 7. The update of the app
        _settingsCard(
          isDark: isDark,
          icon: Icons.system_update_rounded,
          title: _updateActionLabel,
          subtitle: AppStrings.updateAvailableDesc,
          children: [
            _settingsActionButton(
              isDark: isDark,
              icon: Icons.refresh_rounded,
              label: _isCheckingUpdate
                  ? _checkingUpdateLabel
                  : _updateActionLabel,
              onPressed: _isCheckingUpdate ? null : _checkAppUpdate,
              isBusy: _isCheckingUpdate,
            ),
          ],
        ),

        // 8. App info footer
        Center(
          child: Text(
            AppStrings.settingsAbout,
            style: AppTypography.labelSmall(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// The offline question bank and the database of the app.
  Widget _buildSettingsBankCard(bool isDark) {
    return _settingsCard(
      isDark: isDark,
      icon: Icons.storage_rounded,
      iconColor: AppColors.success,
      title: AppStrings.settingsBankHeader,
      subtitle: AppStrings.bankInfo(
        _totalQuestions,
        _pyqCount,
        BankFacts.subjectCount,
      ),
      children: [
        // The size of the database and the time of the last sync
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _settingsMetricChip(
              isDark: isDark,
              icon: Icons.data_usage_rounded,
              iconColor: AppColors.sealGold,
              label: '${AppStrings.dbStorageSizeLabel}: $_dbSizeStr',
            ),
            _settingsMetricChip(
              isDark: isDark,
              icon: Icons.history_toggle_off_rounded,
              iconColor: AppColors.correctGreen,
              label: '${AppStrings.dbLastSyncedLabel}: $_lastSyncedStr',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        Text(
          AppStrings.settingsBankDesc,
          style: AppTypography.bodySmall(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextMuted,
          ).copyWith(height: 1.35),
        ),

        // The progress of a running sync
        if (_isSyncing) ...[
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.roundedFull,
            child: LinearProgressIndicator(
              value: _syncProgress > 0 ? _syncProgress : null,
              minHeight: 6,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.sealGold),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _syncProgressStatus.isNotEmpty
                ? _syncProgressStatus
                : AppStrings.settingsSyncChecking,
            style: AppTypography.labelSmall(
              color: isDark ? AppColors.sealGoldLight : AppColors.primary,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        // Sync the question bank
        _settingsActionButton(
          isDark: isDark,
          icon: Icons.sync_rounded,
          label: _isSyncing ? _syncingLabel : _syncActionLabel,
          onPressed: _isSyncing ? null : _syncNow,
          isBusy: _isSyncing,
        ),
        const SizedBox(height: AppSpacing.sm),

        // Re-download the bank (the confirm dialog explains that the academy
        // record of the user is kept safe)
        Row(
          children: [
            Expanded(
              child: _settingsActionButton(
                isDark: isDark,
                icon: Icons.delete_sweep_rounded,
                label: _isSyncing ? _syncingLabel : _resyncActionLabel,
                onPressed: _isSyncing ? null : _confirmCleanAndResync,
                isBusy: _isSyncing,
                isDanger: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _settingsActionButton(
                isDark: isDark,
                icon: Icons.bolt_rounded,
                label: _isOptimizing ? _optimizingLabel : _optimizeActionLabel,
                onPressed:
                    (_isOptimizing || _isSyncing) ? null : _optimizeDatabase,
                isBusy: _isOptimizing,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The analysis model that prepares the questions of the exam.
  Widget _buildSettingsModelCard(bool isDark) {
    return _settingsCard(
      isDark: isDark,
      icon: Icons.auto_graph_rounded,
      title: AppStrings.settingsModelHeader,
      subtitle: AppStrings.settingsModelDesc,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            AppBadge(
              label: 'Verified ${AppStrings.currentExamYear}',
              color: AppColors.sealGold,
            ),
            AppBadge(
              label: AppStrings.isHindi ? 'मानक ब्लूप्रिंट' : 'Exam Blueprint',
              color: AppColors.cdp,
            ),
          ],
        ),
      ],
    );
  }

  /// One language of the app.
  Widget _languageOption(
    bool isDark, {
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.roundedSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.sealGold.withValues(alpha: 0.2)
              : (isDark ? AppColors.darkCardElevated : AppColors.lightBg),
          borderRadius: AppRadius.roundedSm,
          border: Border.all(
            color: isSelected
                ? AppColors.sealGold
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: isSelected
                  ? AppColors.sealGold
                  : (isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted),
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium(
                  color: isSelected
                      ? AppColors.sealGold
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One measurement of the database (the size, the time of the last sync).
  Widget _settingsMetricChip({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardElevated : AppColors.primarySubtle,
        borderRadius: AppRadius.roundedFull,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMetaChip(IconData icon, String label, bool isDark, [bool isPaper2 = false]) {
    final chipColor = isPaper2
        ? AppColors.violetLight
        : (isDark ? AppColors.sealGoldLight : AppColors.accent);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipColor),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.labelSmall(
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: (isPaper2 ? AppColors.violetBright : AppColors.sealGold).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: isPaper2 ? AppColors.violetBright : AppColors.sealGold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isPaper2
                      ? (isHi ? 'विगत वर्ष प्रश्न-पत्र' : 'Previous Year Papers')
                      : (isHi ? 'विगत वर्ष एवं मॉडल प्रश्न-पत्र' : 'Previous Papers & Mocks'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ).copyWith(letterSpacing: 0.2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isPaper2) _buildStreamBadge(isDark),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardElevated : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_currentCarouselPage + 1}/${carouselList.length} ${isHi ? "प्रश्न-पत्र" : "Papers"}',
                  style: AppTypography.labelSmall(
                    color: isPaper2 ? AppColors.violetLight : (isDark ? AppColors.sealGoldLight : AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Swipeable Carousel PageView
        SizedBox(
          height: 268,
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
              final title = _paperTitle(form, isHi: isHi);
              final rawSet = form['set_code']?.toString() ?? 'SET';
              final stampParts = AppStrings.getStampParts(rawSet, isHindi: isHi);
              final isPyq = rawSet.contains('20') || rawSet == 'PYQ' || (form['is_pyq'] == 1);
              final isLatest = index == 0 && isPyq;
              final isCardFree = PremiumService.instance.isPaperFree(formId: formId, index: index);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? (isPaper2
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.paper2VioletDeep],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.paper2BlueDeep],
                            ))
                      : (isPaper2
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.lightCard, AppColors.paper2VioletSoft],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.lightCard, AppColors.paper2BlueSoft],
                            )),
                  borderRadius: _HomeCard.radius,
                  border: Border.all(
                    color: isPaper2
                        ? AppColors.violetBright
                        : (isDark ? AppColors.sealGold : AppColors.accent),
                    width: 1.5,
                  ),
                  boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.primaryLight : AppColors.primarySubtle,
                            border: Border.all(
                              color: isPaper2
                                  ? AppColors.violetBright
                                  : (isDark ? AppColors.sealGold : AppColors.accent),
                              width: 1.4,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                stampParts.top,
                                style: AppTypography.outfit(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: isPaper2
                                      ? AppColors.violetLight
                                      : (isDark
                                          ? AppColors.sealGoldLight
                                          : AppColors.accent),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                stampParts.bottom,
                                style: AppTypography.labelMedium(
                                  color: isPaper2
                                      ? AppColors.violetLight
                                      : (isDark ? AppColors.sealGoldLight : AppColors.accent),
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
                                  const SizedBox(width: AppSpacing.xs),
                                ],
                                AppBadge(
                                  label: isPaper2
                                      ? (isHi ? 'कक्षा 6-8' : 'Classes 6-8')
                                      : (isHi ? 'कक्षा 1-5' : 'Classes 1-5'),
                                  color: isPaper2 ? AppColors.violetBright : AppColors.accent,
                                  isSolid: false,
                                ),
                                const SizedBox(width: AppSpacing.xs),
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

                    // Full width title: it wraps, it never truncates
                    Text(
                      title,
                      style: AppTypography.titleSmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ).copyWith(height: 1.25),
                    ),

                    // Subtitle
                    Text(
                      isPyq
                          ? (isHi ? '${BankFacts.questionsPerPaper} प्रामाणिक प्रश्न · सम्पूर्ण हल सहित' : '${BankFacts.questionsPerPaper} Authentic Questions · Complete Solutions')
                          : (isHi ? '${BankFacts.questionsPerPaper} सम्भावित प्रश्न · 2026 परीक्षा पैटर्न' : '${BankFacts.questionsPerPaper} Predicted Questions · 2026 Exam Pattern'),
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      ),
                    ),

                    // Meta Chips
                    Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _buildMetaChip(Icons.quiz_outlined, isHi ? '${BankFacts.questionsPerPaper} प्रश्न' : '${BankFacts.questionsPerPaper} Questions', isDark, isPaper2),
                        _buildMetaChip(Icons.timer_outlined, isHi ? '${BankFacts.questionsPerPaper} मिनट' : '${BankFacts.questionsPerPaper} Minutes', isDark, isPaper2),
                        _buildMetaChip(Icons.military_tech_outlined, isHi ? '${BankFacts.questionsPerPaper} अंक' : '${BankFacts.questionsPerPaper} Marks', isDark, isPaper2),
                      ],
                    ),

                    // Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPaper2
                            ? (isDark ? AppColors.violetBright : AppColors.math)
                            : (isDark ? AppColors.sealGold : AppColors.accent),
                        foregroundColor: (isPaper2 || !isDark) ? AppColors.darkTextPrimary : AppColors.darkBg,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        minimumSize: const Size(double.infinity, 38),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
                        elevation: 1,
                      ),
                      onPressed: () {
                        final isFree = PremiumService.instance.isPaperFree(formId: formId, index: index);
                        final isUnlocked = PremiumService.instance.hasUnlockedAccess;
                        if (!isFree && !isUnlocked) {
                          PremiumPaywallModal.show(context);
                          return;
                        }
                        final randSeed = Random().nextInt(999999);
                        final config = MockConfig(
                          mode: isPyq ? MockMode.pyq : MockMode.predicted,
                          seed: randSeed,
                          totalQuestions: BankFacts.questionsPerPaper,
                          timeLimitMinutes: BankFacts.questionsPerPaper,
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
                            color: (isPaper2 || !isDark) ? AppColors.darkTextPrimary : AppColors.darkBg,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            isHi ? 'प्रश्न-पुस्तिका हल करें' : 'Start Test Booklet',
                            style: AppTypography.labelMedium(
                              color: (isPaper2 || !isDark) ? AppColors.darkTextPrimary : AppColors.darkBg,
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(carouselList.length, (dotIdx) {
              final isSelected = dotIdx == _currentCarouselPage;
              return AnimatedContainer(
                duration: AppMotion.slow,
                curve: AppMotion.standard,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                width: isSelected ? 20 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isPaper2
                          ? AppColors.violetBright
                          : (isDark ? AppColors.sealGold : AppColors.accent))
                      : (isDark
                          ? AppColors.darkTextMuted.withValues(alpha: 0.6)
                          : AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(AppRadius.full),
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
    final featuredTitle = featuredForm != null ? _paperTitle(featuredForm, isHi: AppStrings.isHindi) : AppStrings.heroTitle;

    return Container(
      decoration: _HomeCard.card(
        isDark,
        borderColor: AppColors.sealGold,
        borderWidth: 2.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Hit-Rate Ribbon
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.sealGold,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.base),
                topRight: Radius.circular(AppRadius.base),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.darkTextPrimary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    AppStrings.hitRibbon,
                    style: AppTypography.labelSmall(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: _HomeCard.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Paper Stamp Box
                    Container(
                      constraints: const BoxConstraints(minWidth: 54, minHeight: 54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardElevated : AppColors.darkTextPrimary,
                        border: Border.all(
                          color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stampParts.top,
                            style: AppTypography.outfit(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              stampParts.bottom,
                              style: AppTypography.titleMedium(
                                color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                              ).copyWith(height: 1.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleSmall(
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
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppStrings.heroDesc,
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                            ).copyWith(height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Meta Info Box (Wrap - 100% overflow safe)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 16,
                            color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            AppStrings.heroTotalQuestions,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMedium(
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
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            AppStrings.heroTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMedium(
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
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            AppStrings.heroMarks,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMedium(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Action Button: Open Booklet
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.sealGold : AppColors.primary,
                    foregroundColor: isDark ? AppColors.darkBg : AppColors.darkTextPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    minimumSize: const Size(double.infinity, 44),
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
                  ),
                  onPressed: () {
                    final randSeed = Random().nextInt(999999);
                    final config = MockConfig(
                      mode: MockMode.predicted,
                      seed: randSeed,
                      totalQuestions: BankFacts.questionsPerPaper,
                      timeLimitMinutes: BankFacts.questionsPerPaper,
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
                        color: isDark ? AppColors.darkBg : AppColors.darkTextPrimary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        AppStrings.heroBtn,
                        style: AppTypography.titleSmall(
                          color: isDark ? AppColors.darkBg : AppColors.darkTextPrimary,
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
        // A single paper pass or an expired pass must not open everything.
        final bool canOpen = isFree || PremiumService.instance.hasUnlockedAccess;

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
              totalQuestions: BankFacts.questionsPerPaper,
              timeLimitMinutes: BankFacts.questionsPerPaper,
              exam: ExamService.instance.examCode,
            );
            _startMockTest(
              config,
              formId: formId,
              paperTitle: title,
              setCode: setChar,
            );
          },
          borderRadius: _HomeCard.radius,
          child: Builder(
            builder: (context) {
              final isHi = LanguageService.instance.isHindi;
              final stampParts = AppStrings.getStampParts(setChar, isHindi: isHi);

              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: _HomeCard.card(isDark, borderWidth: 1.2),
                child: Row(
                  children: [
                    // Clean Adaptive SET Stamp (Never overflows)
                    Container(
                      constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardElevated : AppColors.darkTextPrimary,
                        border: Border.all(
                          color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stampParts.top,
                            style: AppTypography.outfit(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              stampParts.bottom,
                              style: AppTypography.labelMedium(
                                color: isDark ? AppColors.sealGoldLight : AppColors.primary,
                              ).copyWith(height: 1.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Text(
                            title,
                            style: AppTypography.titleSmall(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
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
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: AppTypography.labelSmall(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),
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

  /// Section counts for the subject hub.  Only the sections that the
  /// selected exam and paper really contain are offered.
  Map<String, int> get _sectionCountsForGrid {
    final map = <String, int>{};
    for (final entry in _sectionCounts.entries) {
      map[entry.key.toLowerCase()] = entry.value;
    }
    return map;
  }

  Color _colorForSection(String code) {
    switch (code.toLowerCase()) {
      case 'cdp':
        return AppColors.cdp;
      case 'hindi':
      case 'hindi_2':
      case 'lang1_hindi':
        return AppColors.hindi;
      case 'english':
      case 'english_1':
      case 'lang2_english':
        return AppColors.english;
      case 'math':
        return AppColors.math;
      case 'evs':
        return AppColors.evs;
      case 'math_science':
      case 'science':
        return AppColors.science;
      case 'social_studies':
      case 'social':
      case 'sst':
        return AppColors.social;
      default:
        return AppColors.primary;
    }
  }

  /// A small badge that names the active paper-2 stream.
  Widget _buildStreamBadge(bool isDark) {
    final social = ExamService.instance.isSocialStream;
    final color = social ? AppColors.violetBright : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        social
            ? AppStrings.streamShortSocialStudies
            : AppStrings.streamShortMathScience,
        style: AppTypography.labelSmall(
          color: social
              ? (isDark ? AppColors.violetLight : AppColors.violet)
              : (isDark ? AppColors.accentBright : AppColors.accentDark),
        ),
      ),
    );
  }

  /// Paper 2 runs in two streams and the candidate attempts only one of
  /// them, so the *other* stream must not be offered at all.  Every other
  /// section (CDP, the languages) stays.
  bool _isInactiveStreamSection(String code) {
    final key = code.toLowerCase();
    final isSocial = key == 'social_studies' || key == 'social' || key == 'sst';
    final isMath = key == 'math_science' || key == 'science';
    if (!isSocial && !isMath) return false;
    return ExamService.instance.isSocialStream ? isMath : isSocial;
  }

  Widget _buildSubjectGrid(bool isDark) {
    final isPaper2 = ExamService.instance.isPaper2;
    final isHi = LanguageService.instance.isHindi;
    // The grid is built from the sections the vault really contains for the
    // selected exam and paper.  A hard coded list used codes that the vault
    // does not have (lang1_hindi, math_science, ...) and showed empty
    // subjects with "0 questions".
    final available = _sectionCountsForGrid;
    final subjects = <Map<String, dynamic>>[];
    var index = 0;
    for (final code in SectionCatalog.forPaper(isPaper2 ? 2 : 1)) {
      // Paper 2 has two streams, but the candidate attempts only one of
      // them, so the other stream must not show up in the grid.
      if (isPaper2 && _isInactiveStreamSection(code)) continue;
      final count = available[code] ?? 0;
      if (count <= 0) continue;
      index++;
      subjects.add({
        'sec': code,
        'name': AppStrings.sectionName(code),
        'color': _colorForSection(code),
        'label': isHi ? 'खण्ड $index' : 'Section $index',
        'count': count,
      });
    }
    if (subjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.xl,
        ),
        child: Text(
          isHi
              ? 'इस बैंक में अभी कोई विषय उपलब्ध नहीं है।'
              : 'No subjects are available in this bank yet.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
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
                borderRadius: _HomeCard.radius,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  decoration: _HomeCard.card(isDark, borderWidth: 1.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: AppTypography.labelSmall(
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
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        name,
                        style: AppTypography.labelMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.subjectCardSetsInfo,
                        style: AppTypography.labelSmall(
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
    return HistoryCard(
      entry: h,
      isDark: isDark,
      onOpen: () => _openHistorySession(h),
      onPracticeAgain: () => _practiceHistoryAgain(
        h,
        (h['total'] as num?)?.toInt() ?? BankFacts.questionsPerPaper,
      ),
    );
  }

  /// Starts a new test of the same kind as the one of the history row.
  Future<void> _practiceHistoryAgain(Map<String, dynamic> h, int total) async {
    final modeName = h['mode'] as String? ?? 'predicted';
    final mode = MockMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => MockMode.predicted,
    );
    final sectionFilter = h['section_filter'] as String?;
    final questions = total > 0 ? total : BankFacts.questionsPerPaper;

    setState(() => _isLoading = true);
    try {
      final mockData = await _engine.generateMock(
        MockConfig(
          mode: mode,
          exam: ExamService.instance.examCode,
          sectionFilter: sectionFilter,
          totalQuestions: questions,
          timeLimitMinutes: questions,
          seed: DateTime.now().millisecondsSinceEpoch,
        ),
      );
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
        config: MockConfig(
          mode: mode,
          exam: ExamService.instance.examCode,
          sectionFilter: sectionFilter,
          totalQuestions: questions,
          timeLimitMinutes: questions,
          seed: DateTime.now().millisecondsSinceEpoch,
        ),
        questions: mockData.questions,
        passages: mockData.passages,
        paperTitle: _historyPaperTitle(h),
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
}


/// The card of one finished test in the history tab.
///
/// Every part of the row has a proper constraint, so the name of the paper,
/// the score, the chips and the actions always fit on a narrow phone.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.entry,
    required this.isDark,
    required this.onOpen,
    required this.onPracticeAgain,
  });

  /// The row of the test history.
  final Map<String, dynamic> entry;

  final bool isDark;

  /// Opens the stored result of the test.
  final VoidCallback onOpen;

  /// Starts the same kind of test once more.
  final VoidCallback onPracticeAgain;

  @override
  Widget build(BuildContext context) {
    final score = (entry['score'] as num?)?.toInt() ?? 0;
    final total = (entry['total'] as num?)?.toInt() ?? BankFacts.questionsPerPaper;
    final mode = entry['mode'] as String? ?? 'predicted';
    final isPass = ExamRules.isGeneralPass(score, total);
    final isHi = AppStrings.isHindi;
    final title = _historyPaperTitle(entry);
    final minutes = ((entry['time_spent_seconds'] as num?)?.toInt() ?? 0) ~/ 60;
    final timeLabel = isHi ? '$minutes मिनट' : '$minutes min';
    final scoreColor = isPass ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _HomeCard.radius,
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: _HomeCard.card(isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. The name of the paper and the score
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: scoreColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ).copyWith(height: 1.3),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: AppRadius.roundedFull,
                        border: Border.all(
                          color: scoreColor.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$score / $total',
                        style: AppTypography.labelMedium(color: scoreColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // 2. The chips of the test
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _historyChip(
                      isDark: isDark,
                      icon: Icons.assessment_rounded,
                      iconColor: AppColors.sealGold,
                      label: AppStrings.historyMockType(mode),
                    ),
                    _historyChip(
                      isDark: isDark,
                      icon: isPass
                          ? Icons.verified_rounded
                          : Icons.trending_up_rounded,
                      iconColor: scoreColor,
                      label: isPass
                          ? AppStrings.historyQualified
                          : AppStrings.historyPracticeNeeded,
                    ),
                    _historyChip(
                      isDark: isDark,
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.accent,
                      label: timeLabel,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. The actions of the test
                Row(
                  children: [
                    Expanded(
                      child: _historyActionButton(
                        isDark: isDark,
                        icon: Icons.bar_chart_rounded,
                        label: isHi ? 'परिणाम देखें' : 'View result',
                        onPressed: onOpen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _historyActionButton(
                        isDark: isDark,
                        icon: Icons.replay_rounded,
                        label: isHi ? 'फिर से अभ्यास' : 'Practice again',
                        onPressed: onPracticeAgain,
                        isMuted: true,
                      ),
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

  /// One action button of a history card.
  Widget _historyActionButton({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isMuted = false,
  }) {
    final color = isMuted
        ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
        : (isDark ? AppColors.sealGoldLight : AppColors.primary);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: isMuted
              ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
              : color.withValues(alpha: 0.7),
          width: 1.2,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        minimumSize: const Size(0, 42),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.roundedSm,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.labelMedium(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// One chip of a history card.
Widget _historyChip({
  required bool isDark,
  required IconData icon,
  required Color iconColor,
  required String label,
}) {
  return Container(
    constraints: const BoxConstraints(maxWidth: 230),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkCardElevated : AppColors.primarySubtle,
      borderRadius: AppRadius.roundedFull,
      border: Border.all(
        color: iconColor.withValues(alpha: 0.35),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The name of the paper of a history row.
///
/// The name is stored inside the session of the test, so it is read from
/// there.  An old row without a session falls back to the type of the test.
String _historyPaperTitle(Map<String, dynamic> h) {
  final raw = h['session_json']?.toString() ?? '';
  if (raw.isNotEmpty && raw != '{}') {
    // The session holds every question of the test, so only the name is
    // picked out of it - decoding the whole session would be far too slow.
    final match = RegExp(
      r'"paperTitle"\s*:\s*"((?:[^"\\]|\\.)*)"',
    ).firstMatch(raw);
    if (match != null) {
      final title = match.group(1)!
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\')
          .replaceAll(r'\n', ' ')
          .replaceAll(r'\t', ' ')
          .trim();
      if (title.isNotEmpty) return title;
    }
  }
  return AppStrings.historyMockType(h['mode'] as String? ?? 'predicted');
}
