import 'dart:math';
import '../database/db_helper.dart';
import '../models/question.dart';
import '../models/passage.dart';
import '../models/mock_config.dart';
import '../data/official_pyq_repository.dart';
import 'exam_service.dart';

class MockEngine {
  final DbHelper db = DbHelper.instance;

  // 3-Year Audited Blueprint (30 questions per section)
  static const Map<String, Map<String, int>> blueprint = {
    'cdp': {
      'समावेशी शिक्षा': 4,
      'मूल्यांकन': 3,
      'अधिगम सिद्धांत': 3,
      'शिक्षण विधियाँ': 3,
      'बुद्धि': 2,
      'व्यक्तित्व': 2,
      'स्मृति/सृजनात्मकता': 2,
      'संज्ञानात्मक विकास': 2,
      'अधिगम की प्रकृति': 2,
      'अभिप्रेरणा': 2,
      'नीति एवं अधिनियम': 1,
      'प्रसिद्ध कथन': 1,
      'भाषा विकास': 1,
      'वैयक्तिक भिन्नता': 1,
      'लिंग एवं समानता': 1,
    },
    'hindi': {
      'अपठित गद्यांश': 5,
      'अपठित पद्यांश': 5,
      'व्याकरण': 3,
      'शब्द-भंडार': 3,
      'वर्ण-विचार': 3,
      'भाषा शिक्षण': 3,
      'हिन्दी साहित्य': 3,
      'छंद/अलंकार/रस': 2,
      'कारक/वाक्य': 2,
      'मुहावरा/लोकोक्ति': 1,
    },
    'english': {
      'Comprehension — Passage': 5,
      'Comprehension — Poem': 5,
      'Grammar': 6,
      'Synonym/Antonym': 3,
      'ELT Methods': 3,
      'Idioms': 2,
      'Figures of Speech': 2,
      'Language Skills': 2,
      'Spelling': 1,
      'Phonology': 1,
    },
    'math': {
      'गणित शिक्षाशास्त्र': 7,
      'संख्या पद्धति': 5,
      'ज्यामिति': 4,
      'प्रतिशत/लाभ-हानि': 3,
      'औसत': 2,
      'गति-दूरी-समय': 2,
      'समय एवं कार्य': 2,
      'आँकड़ा निर्वचन': 2,
      'क्षेत्रमिति': 1,
      'ब्याज': 1,
      'पैटर्न/शृंखला': 1,
    },
    'evs': {
      'EVS शिक्षाशास्त्र': 6,
      'जैव-विविधता': 6,
      'प्रदूषण': 3,
      'पारिस्थितिकी': 3,
      'कृषि एवं मृदा': 2,
      'उत्तराखण्ड विशेष': 2,
      'कानून/संविधान/SDG': 2,
      'ऊर्जा एवं जलवायु': 2,
      'वन एवं संसाधन': 2,
      'भूगोल एवं नदियाँ': 1,
      'जीव अनुकूलन': 1,
    },
  };

  static const List<String> paper1Sections = ['cdp', 'hindi', 'english', 'math', 'evs'];
  static const List<String> paper2Sections = ['cdp', 'hindi', 'english', 'math', 'science', 'social'];
  static const List<String> sectionOrder = paper1Sections;

  static final RegExp _sanskritKeywords = RegExp(
    r'(?:\b(?:किम्|कथम्|अस्ति|सन्ति|भवति|भवन्ति|आसीत्|स्यात्|पठित्वा|दृष्ट्वा|लिखित्वा|अधोलिखितं?|प्रश्नानां?|इत्यस्य|अस्मिन्\s+पदे|का\s+विभक्ति[ः:]?|कः\s+प्रत्यय[ः:]?|विभक्ति[ः:]|प्रत्यय[ः:]|संधिविच्छेद[ः:]?|श्लोके|श्लोकं|गद्यांशे|पद्यांशे|पाठस्य|कवि[ः:]|काव्यस्य|समास[ः:]|विग्रह[ः:]|लकार[ः:]|धातुरूपं?|शब्दरूपं?|पर्यायपदं?|विलोमपदं?)\b|[\u0900-\u097F]+स्य\b|[\u0900-\u097F]+ेषु\b|[\u0900-\u097F]+योः\b|[\u0900-\u097F]+भ्याम्\b)',
    caseSensitive: false,
  );

  /// Validates questions to guarantee zero cross-subject leakage (e.g. math/sanskrit leaking into hindi)
  static bool _isValidForSection(Question q, String sec) {
    if (q.section.toLowerCase() != sec.toLowerCase()) return false;
    final text = '${q.qHindi} ${q.optionsHindi.join(' ')} ${q.qEnglish ?? ''}';

    if (sec == 'hindi') {
      // 1. Math leak prevention
      if (text.contains('त्रिभुज का क्षेत्रफल') ||
          text.contains('ल.स. और म.स.') ||
          (text.contains('समीकरण') && !text.contains('भाषा')) ||
          text.contains('कोण का मान') ||
          text.contains('परिमाप ज्ञात') ||
          text.contains('गुणनखंड')) {
        return false;
      }
      // 2. Sanskrit leak prevention
      if (_sanskritKeywords.hasMatch(text)) {
        return false;
      }
    }

    if (sec == 'english') {
      // Must not be empty or purely devanagari without English
      if (!q.hasEnglish && q.qHindi.trim().isNotEmpty && !RegExp(r'[a-zA-Z]').hasMatch(q.qHindi)) {
        return false;
      }
    }

    return true;
  }

  /// Generate full mock test or single-section test
  Future<({List<Question> questions, Map<String, Passage> passages})> generateMock(
    MockConfig config,
  ) async {
    final rand = Random(config.seed);
    final database = await db.database;
    final List<Question> output = [];
    final Map<String, Passage> passageMap = {};

    final isPaper2 = config.exam.toLowerCase().endsWith('2');
    final isCtet = config.exam.toLowerCase().startsWith('ctet');

    // Vault section codes are not uniform:
    //   CTET      → lang1_hindi / lang2_english
    //   UTET 1/2  → hindi / english (some CTET-2/UTET-2 sets use hindi_2/english_1)
    // Using the raw language name here silently produced empty language
    // sections for CTET and for several UTET-2 sets.
    final l1 = isCtet
        ? 'lang1_hindi'
        : ExamService.instance.currentLang1.value.toLowerCase();
    final l2 = isCtet
        ? 'lang2_english'
        : ExamService.instance.currentLang2.value.toLowerCase();

    List<String> defaultSections;
    if (isPaper2) {
      final streamSec = ExamService.instance.isSocialStream ? 'social_studies' : 'math_science';
      defaultSections = ['cdp', l1, l2, streamSec];
    } else {
      defaultSections = ['cdp', l1, l2, 'math', 'evs'];
    }

    final sectionsToGenerate = config.sectionFilter != null
        ? [config.sectionFilter!]
        : defaultSections;

    final examCondition = db.examWhere(config.exam);

    for (final sec in sectionsToGenerate) {
      final topicRules = blueprint[sec] ?? {};

      // Get actual topic distribution existing in database for this section and exam
      Map<String, int> activeRules = Map.from(topicRules);
      final secTopics = await db.getTopicCountsForSection(sec, config.exam);
      if (secTopics.isNotEmpty && (topicRules.isEmpty || config.exam.toLowerCase().contains('ctet') || isPaper2)) {
        activeRules = {};
        final totalSecQ = secTopics.values.fold(0, (a, b) => a + b);
        int assigned = 0;
        for (final tEntry in secTopics.entries) {
          final share = ((tEntry.value / totalSecQ) * 30).round().clamp(1, 8);
          activeRules[tEntry.key] = share;
          assigned += share;
          if (assigned >= 26) break;
        }
      }

      // Check whether this section has reading comprehension passages (e.g. Hindi, English)
      final List<Question> sectionPassageQuestions = [];
      final pQuery = 'section = ? AND passage_id IS NOT NULL AND passage_id != "" AND ($examCondition)';
      final pArgs = [sec];

      final pRows = await database.query('questions', where: pQuery, whereArgs: pArgs);
      final pQuestions = pRows
          .map((r) => Question.fromDbMap(r))
          .where((q) => _isValidForSection(q, sec))
          .toList();

      // Group candidate passage questions by passageId
      final Map<String, List<Question>> passageGroups = {};
      for (final q in pQuestions) {
        if (q.passageId != null) {
          passageGroups.putIfAbsent(q.passageId!, () => []).add(q);
        }
      }

      // Pick intact reading comprehension passages for language sections (Hindi, English, Sanskrit)
      // Official Exam Standard: 1 Prose (गद्यांश) + 1 Poem (पद्यांश/काव्यांश)
      if (passageGroups.isNotEmpty && (sec.contains('hindi') || sec.contains('english') || sec.contains('sanskrit'))) {
        final List<String> prosePids = [];
        final List<String> poemPids = [];

        for (final pk in passageGroups.keys) {
          final p = await db.getPassage(pk) ?? OfficialPyqRepository.getPassage(pk);
          if (p == null || p.body.trim().isEmpty) continue;
          if (p.isPoem || pk.toLowerCase().contains('poem')) {
            poemPids.add(pk);
          } else {
            prosePids.add(pk);
          }
        }
        prosePids.shuffle(rand);
        poemPids.shuffle(rand);

        final List<String> selectedPids = [];
        if (prosePids.isNotEmpty) selectedPids.add(prosePids.first);
        if (poemPids.isNotEmpty) {
          selectedPids.add(poemPids.first);
        } else if (prosePids.length > 1) {
          selectedPids.add(prosePids[1]);
        }

        for (final pk in selectedPids) {
          final group = List<Question>.from(passageGroups[pk]!);
          final passage = (await db.getPassage(pk)) ?? OfficialPyqRepository.getPassage(pk)!;
          // Strictly sort questions in natural sequence inside passage (e.g. 1, 2, 3, 4, 5)
          group.sort((a, b) => (a.seqInPassage ?? 0).compareTo(b.seqInPassage ?? 0));
          // Add entire passage group together as an unbroken, contiguous unit
          sectionPassageQuestions.addAll(group);
          passageMap[pk] = passage;
        }
      }

      final Set<String> usedIdsInSec = sectionPassageQuestions.map((q) => q.id).toSet();
      final List<Question> sectionStandaloneQuestions = [];
      final int secQuota = (sec == 'math_science' || sec == 'social_studies') ? 60 : 30;
      final int targetStandalone = (secQuota - sectionPassageQuestions.length).clamp(0, secQuota);

      for (final entry in activeRules.entries) {
        if (sectionStandaloneQuestions.length >= targetStandalone) break;
        final topicName = entry.key;
        final need = entry.value;

        String whereClause = 'section = ? AND passage_id IS NULL AND (topic_name = ? OR topic_name LIKE ?) AND ($examCondition)';
        List<dynamic> whereArgs = [sec, topicName, '%$topicName%'];

        if (config.mode == MockMode.repeat) {
          whereClause += " AND years LIKE '%,%'";
        } else if (config.mode == MockMode.pyq) {
          whereClause += " AND years IS NOT NULL AND years != ''";
        } else if (config.mode == MockMode.fresh) {
          whereClause += " AND (years IS NULL OR years = '')";
        }

        List<Map<String, dynamic>> rows = await database.query(
          'questions',
          where: whereClause,
          whereArgs: whereArgs,
        );

        if (rows.length < need) {
          final fallbackWhere = 'section = ? AND passage_id IS NULL AND (topic_name = ? OR topic_name LIKE ?) AND ($examCondition)';
          final fallbackArgs = [sec, topicName, '%$topicName%'];
          final fallbackRows = await database.query(
            'questions',
            where: fallbackWhere,
            whereArgs: fallbackArgs,
          );
          final existingIds = rows.map((r) => r['id']).toSet();
          final additional = fallbackRows.where((r) => !existingIds.contains(r['id'])).toList();
          rows = [...rows, ...additional];
        }

        final List<Question> candidates = rows
            .map((r) => Question.fromDbMap(r))
            .where((q) => !usedIdsInSec.contains(q.id) && _isValidForSection(q, sec))
            .toList();

        candidates.shuffle(rand);
        candidates.sort((a, b) {
          final repeatBonusA = (a.years != null && a.years!.contains(',')) ? 1.5 : 1.0;
          final repeatBonusB = (b.years != null && b.years!.contains(',')) ? 1.5 : 1.0;
          final baseA = config.mode == MockMode.fresh ? (1.0 - a.pScore) : (a.pScore * repeatBonusA);
          final baseB = config.mode == MockMode.fresh ? (1.0 - b.pScore) : (b.pScore * repeatBonusB);
          final pA = pow(baseA.clamp(0.05, 2.0), config.mode.power) * (0.5 + rand.nextDouble());
          final pB = pow(baseB.clamp(0.05, 2.0), config.mode.power) * (0.5 + rand.nextDouble());
          return pB.compareTo(pA);
        });

        final pickCount = min(need, targetStandalone - sectionStandaloneQuestions.length);
        final picked = candidates.take(pickCount).toList();
        for (final q in picked) {
          usedIdsInSec.add(q.id);
          sectionStandaloneQuestions.add(q);
        }
      }

      // If standalone + passage still < 30, fill with high-quality standalone questions
      if (sectionStandaloneQuestions.length < targetStandalone) {
        final short = targetStandalone - sectionStandaloneQuestions.length;
        final fillWhere = 'section = ? AND passage_id IS NULL AND ($examCondition)';
        final fillArgs = [sec];

        final fillRows = await database.query('questions', where: fillWhere, whereArgs: fillArgs);
        final fillCandidates = fillRows
            .map((r) => Question.fromDbMap(r))
            .where((q) => !usedIdsInSec.contains(q.id) && _isValidForSection(q, sec))
            .toList();

        fillCandidates.shuffle(rand);
        fillCandidates.sort((a, b) {
          final repeatBonusA = (a.years != null && a.years!.contains(',')) ? 1.5 : 1.0;
          final repeatBonusB = (b.years != null && b.years!.contains(',')) ? 1.5 : 1.0;
          final pA = pow(a.pScore * repeatBonusA, config.mode.power) * (0.6 + rand.nextDouble() * 0.8);
          final pB = pow(b.pScore * repeatBonusB, config.mode.power) * (0.6 + rand.nextDouble() * 0.8);
          return pB.compareTo(pA);
        });

        for (final q in fillCandidates.take(short)) {
          usedIdsInSec.add(q.id);
          sectionStandaloneQuestions.add(q);
        }
      }

      // Strict Clamp: Standalone questions clamped so total is EXACTLY 30 questions
      // Passage questions are NEVER dropped or cut
      if (sectionStandaloneQuestions.length > targetStandalone) {
        sectionStandaloneQuestions.removeRange(
          targetStandalone,
          sectionStandaloneQuestions.length,
        );
      }

      // Add intact passage questions first, then standalone questions to ensure 100% contiguous passages
      output.addAll(sectionPassageQuestions);
      output.addAll(sectionStandaloneQuestions);
    }

    // Collect all passages required by selected questions
    final passageIds = output
        .where((q) => q.passageId != null && q.passageId!.isNotEmpty)
        .map((q) => q.passageId!)
        .toSet();

    for (final pid in passageIds) {
      if (!passageMap.containsKey(pid)) {
        final p = await db.getPassage(pid) ?? OfficialPyqRepository.getPassage(pid);
        if (p != null) {
          passageMap[pid] = p;
        }
      }
    }

    return (questions: output, passages: passageMap);
  }

  /// Load pre-built authentic paper form directly
  Future<({List<Question> questions, Map<String, Passage> passages})> loadPrebuiltPaper({
    required String paperFormId,
    String? stream,
  }) async {
    final result = await db.loadPaperFormExam(
      paperFormId: paperFormId,
      stream: stream ?? ExamService.instance.activeStream.name,
    );

    // Every question of this paper must be able to show its own passage in
    // the CBT screen *and* in the solution review.  Passages that are only
    // available in the hard-coded official repository are resolved here.
    final missing = <String>{};
    for (final question in result.questions) {
      final pid = question.passageId;
      if (pid != null && pid.isNotEmpty && !result.passages.containsKey(pid)) {
        missing.add(pid);
      }
    }
    for (final pid in missing) {
      final passage = OfficialPyqRepository.getPassage(pid);
      if (passage != null) {
        result.passages[pid] = passage;
      }
    }

    return result;
  }

  /// Generate authentic full PYQ paper for a specific year
  Future<({List<Question> questions, Map<String, Passage> passages})> generateYearlyPyqPaper(
    String year, [
    String? exam,
  ]) async {
    final currentExam = (exam ?? 'utet1').toLowerCase();
    final isPaper2 = currentExam.contains('2') || ExamService.instance.selectedPaper == 2;

    // 1. Try to load directly from paper_forms table
    try {
      final forms = await db.getAvailablePaperForms(
        exam: currentExam.startsWith('c') ? 'ctet' : 'utet',
        paper: isPaper2 ? 2 : 1,
        isPyqOnly: true,
      );
      Map<String, dynamic>? targetForm;
      for (final f in forms) {
        final fid = (f['id'] ?? '').toString().toLowerCase();
        final ftitle = (f['title'] ?? '').toString().toLowerCase();
        final fdate = (f['exam_date'] ?? '').toString().toLowerCase();
        final yClean = year.replaceAll(RegExp(r'\D'), '');
        if (fid.contains(yClean) || ftitle.contains(yClean) || fdate.contains(yClean)) {
          targetForm = f;
          break;
        }
      }
      targetForm ??= forms.isNotEmpty ? forms.first : null;
      if (targetForm != null) {
        final res = await db.loadPaperFormExam(
          paperFormId: targetForm['id'] as String,
          stream: ExamService.instance.activeStream.name,
        );
        if (res.questions.isNotEmpty) {
          return res;
        }
      }
    } catch (_) {}

    // 2. Fallback to questions table
    final questions = await db.getPyqQuestionsByYear(year, exam);
    final Map<String, Passage> passageMap = {};

    final passageIds = questions
        .where((q) => q.passageId != null && q.passageId!.isNotEmpty)
        .map((q) => q.passageId!)
        .toSet();

    for (final pid in passageIds) {
      final p = await db.getPassage(pid);
      if (p != null) {
        passageMap[pid] = p;
      }
    }

    return (questions: questions, passages: passageMap);
  }

  /// Load an authentic pre-built 150Q Model Paper
  Future<({List<Question> questions, Map<String, Passage> passages})> generateModelPaper({
    required int paperNumber,
    String exam = 'utet1',
  }) async {
    final isPaper2 = exam.toLowerCase().contains('2') || ExamService.instance.selectedPaper == 2;
    try {
      final forms = await db.getAvailablePaperForms(paper: isPaper2 ? 2 : 1, isPyqOnly: false);
      if (forms.isNotEmpty) {
        final index = (paperNumber - 1).clamp(0, forms.length - 1);
        final targetForm = forms[index];
        final res = await db.loadPaperFormExam(
          paperFormId: targetForm['id'] as String,
          stream: ExamService.instance.activeStream.name,
        );
        if (res.questions.isNotEmpty) {
          return res;
        }
      }
    } catch (_) {}

    // Fallback if no pre-built form exists
    final config = MockConfig(
      mode: MockMode.predicted,
      exam: exam,
      seed: 2026100 + paperNumber * 777,
      totalQuestions: 150,
      timeLimitMinutes: 150,
    );
    return generateMock(config);
  }

  /// Generate a 30-question subject practice set using the probability engine
  Future<({List<Question> questions, Map<String, Passage> passages})> generateSubjectSet({
    required String section,
    required int setNumber,
    String exam = 'utet1',
  }) async {
    final config = MockConfig(
      mode: MockMode.mixed,
      exam: exam,
      sectionFilter: section,
      seed: 10000 + setNumber * 433,
      totalQuestions: 30,
      timeLimitMinutes: 30,
    );
    return generateMock(config);
  }

  /// Generate a targeted topic drill
  Future<({List<Question> questions, Map<String, Passage> passages})> generateTopicDrill({
    required String section,
    required String topicName,
    String? exam,
  }) async {
    final questions = await db.getQuestionsByTopic(section, topicName, exam);
    final Map<String, Passage> passageMap = {};

    final passageIds = questions
        .where((q) => q.passageId != null && q.passageId!.isNotEmpty)
        .map((q) => q.passageId!)
        .toSet();

    for (final pid in passageIds) {
      final p = await db.getPassage(pid) ?? OfficialPyqRepository.getPassage(pid);
      if (p != null) {
        passageMap[pid] = p;
      }
    }

    return (questions: questions, passages: passageMap);
  }
}
