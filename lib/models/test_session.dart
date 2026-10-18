import 'question.dart';
import 'passage.dart';
import 'mock_config.dart';

enum QuestionStatus {
  notVisited,
  notAnswered,
  answered,
  markedForReview,
  answeredAndMarked,
}

class TestSession {
  final String id;
  final MockConfig config;
  final List<Question> questions;
  final Map<String, Passage> passages;
  final Map<int, int> selectedAnswers; // questionIndex -> optionIndex (0..3)
  final Set<int> markedForReview;
  final Set<int> visitedIndices;
  int elapsedSeconds;
  bool isCompleted;
  final DateTime startTime;
  DateTime? endTime;
  final String? paperTitle;
  final String? setCode;

  TestSession({
    required this.id,
    required this.config,
    required this.questions,
    required this.passages,
    Map<int, int>? selectedAnswers,
    Set<int>? markedForReview,
    Set<int>? visitedIndices,
    this.elapsedSeconds = 0,
    this.isCompleted = false,
    DateTime? startTime,
    this.endTime,
    this.paperTitle,
    this.setCode,
  })  : selectedAnswers = selectedAnswers ?? {},
        markedForReview = markedForReview ?? {},
        visitedIndices = visitedIndices ?? {},
        startTime = startTime ?? DateTime.now();

  QuestionStatus getQuestionStatus(int index) {
    final hasAnswer = selectedAnswers.containsKey(index);
    final isMarked = markedForReview.contains(index);

    if (hasAnswer && isMarked) return QuestionStatus.answeredAndMarked;
    if (isMarked) return QuestionStatus.markedForReview;
    if (hasAnswer) return QuestionStatus.answered;
    if (visitedIndices.contains(index)) return QuestionStatus.notAnswered;
    return QuestionStatus.notVisited;
  }

  int get answeredCount => selectedAnswers.length;
  int get markedCount => markedForReview.length;
  int get notAnsweredCount =>
      visitedIndices.length - selectedAnswers.keys.where(visitedIndices.contains).length;
  int get notVisitedCount => questions.length - visitedIndices.length;

  int calculateScore() {
    int score = 0;
    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i].answer) {
        score++;
      }
    }
    return score;
  }
}
