import '../database/db_helper.dart';
import '../services/exam_service.dart';

/// Live numbers of the question bank.
///
/// Every user facing count has to come from the database, otherwise the UI
/// keeps claiming "9,720 questions" or "62 papers" long after the vault has
/// changed.  The values are refreshed when the home screen loads.
class BankFacts {
  const BankFacts._();

  static int questionCount = 0;
  static int paperCount = 0;
  static int pyqCount = 0;
  static int subjectCount = 0;
  static int questionsPerPaper = 150;

  /// Questions in one subject-wise mini booklet (topic drill).
  static const int subjectSetQuestions = 30;

  /// Paper forms of the bundled vault, per exam (counts computed by a build
  /// time check of assets/database/tet_mock_vault.db, the paywall shows them).
  static const int utetPaperFormCount = 29;
  static const int ctetPaperFormCount = 34;
  static const int utetMockCount = 21;
  static const int ctetMockCount = 26;
  static const int utetPyqCount = 8;
  static const int ctetPyqCount = 8;
  static const int utetQuestionCount = 4616;
  static const int ctetQuestionCount = 5100;
  /// Per direction (exam + paper), the single ₹399 pass shows them.
  static const int utetP1FormCount = 22;
  static const int utetP1QuestionCount = 3146;
  static const int utetP2FormCount = 7;
  static const int utetP2QuestionCount = 1470;
  static const int ctetP1FormCount = 18;
  static const int ctetP1QuestionCount = 2700;
  static const int ctetP2FormCount = 16;
  static const int ctetP2QuestionCount = 2400;
  /// Every question of the vault, both exams together.
  static const int vaultQuestionCount = 9720;

  /// A safe, never empty representation of a count for the UI.
  static String format(int value) {
    if (value <= 0) return '0';
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }

  static Future<void> refresh(DbHelper db) async {
    try {
      final exam = ExamService.instance.isUtet ? 'utet' : 'ctet';
      final paper = ExamService.instance.selectedPaper;
      final forms = await db.getAvailablePaperForms(exam: exam, paper: paper);
      final sections = await db.getSectionCountsForPaper(exam: exam, paper: paper);
      questionCount = await db.getQuestionCount();
      paperCount = forms.length;
      pyqCount = await db.getPyqCount();
      subjectCount = sections.length;
      if (forms.isNotEmpty) {
        final total = forms.first['total_questions'];
        if (total is int && total > 0) questionsPerPaper = total;
      }
    } catch (_) {
      // Keep the previous values, the UI must never fail because of this.
    }
  }
}
