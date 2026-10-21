import 'dart:convert';

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

  int get attemptedCount => selectedAnswers.length;

  int get timeLimitSeconds => config.timeLimitMinutes * 60;

  /// Remaining time based on the wall clock, not a decrementing counter.
  ///
  /// This keeps the timer correct while the app is backgrounded, killed or
  /// the device is under load.
  int remainingSecondsAt(DateTime now) {
    if (isCompleted) return 0;
    final deadline = startTime.add(Duration(seconds: timeLimitSeconds));
    final remaining = deadline.difference(now).inSeconds;
    return remaining.clamp(0, timeLimitSeconds);
  }

  /// Complete, portable snapshot for `test_history.session_json`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'config': {
        'mode': config.mode.name,
        'exam': config.exam,
        'sectionFilter': config.sectionFilter,
        'totalQuestions': config.totalQuestions,
        'timeLimitMinutes': config.timeLimitMinutes,
        'seed': config.seed,
      },
      'questions': questions.map((question) => question.toJson()).toList(),
      'passages': passages.map(
        (key, passage) => MapEntry(key, passage.toMap()),
      ),
      'selectedAnswers': selectedAnswers.map(
        (index, answer) => MapEntry(index.toString(), answer),
      ),
      'markedForReview': markedForReview.toList(),
      'visitedIndices': visitedIndices.toList(),
      'elapsedSeconds': elapsedSeconds,
      'isCompleted': isCompleted,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'paperTitle': paperTitle,
      'setCode': setCode,
    };
  }

  String encode() => jsonEncode(toJson());

  factory TestSession.fromJson(Map<String, dynamic> json) {
    final rawConfig = (json['config'] as Map?) ?? const {};
    final rawQuestions = (json['questions'] as List?) ?? const [];
    final rawPassages = (json['passages'] as Map?) ?? const {};
    final rawAnswers = (json['selectedAnswers'] as Map?) ?? const {};

    MockMode mode = MockMode.mixed;
    final modeName = rawConfig['mode']?.toString();
    if (modeName != null) {
      for (final candidate in MockMode.values) {
        if (candidate.name == modeName) {
          mode = candidate;
          break;
        }
      }
    }

    final config = MockConfig(
      mode: mode,
      exam: rawConfig['exam']?.toString() ?? 'utet1',
      sectionFilter: rawConfig['sectionFilter']?.toString(),
      totalQuestions: (rawConfig['totalQuestions'] as num?)?.toInt() ??
          rawQuestions.length,
      timeLimitMinutes: (rawConfig['timeLimitMinutes'] as num?)?.toInt() ?? 150,
      seed: (rawConfig['seed'] as num?)?.toInt() ?? 0,
    );

    final questions = rawQuestions
        .whereType<Map>()
        .map((question) => Question.fromJson(Map<String, dynamic>.from(question)))
        .toList();

    final passages = <String, Passage>{};
    rawPassages.forEach((key, value) {
      if (value is Map) {
        passages[key.toString()] =
            Passage.fromMap(Map<String, dynamic>.from(value));
      }
    });

    final selectedAnswers = <int, int>{};
    rawAnswers.forEach((key, value) {
      final index = int.tryParse(key.toString());
      final answer = value is num ? value.toInt() : int.tryParse(value.toString());
      if (index != null && answer != null) selectedAnswers[index] = answer;
    });

    final marked = <int>{};
    for (final value in (json['markedForReview'] as List?) ?? const []) {
      final index = value is num ? value.toInt() : int.tryParse(value.toString());
      if (index != null) marked.add(index);
    }
    final visited = <int>{};
    for (final value in (json['visitedIndices'] as List?) ?? const []) {
      final index = value is num ? value.toInt() : int.tryParse(value.toString());
      if (index != null) visited.add(index);
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return TestSession(
      id: json['id']?.toString() ?? 'restored_${DateTime.now().millisecondsSinceEpoch}',
      config: config,
      questions: questions,
      passages: passages,
      selectedAnswers: selectedAnswers,
      markedForReview: marked,
      visitedIndices: visited,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      startTime: parseDate(json['startTime']),
      endTime: parseDate(json['endTime']),
      paperTitle: json['paperTitle']?.toString(),
      setCode: json['setCode']?.toString(),
    );
  }

  factory TestSession.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid test session JSON');
    }
    return TestSession.fromJson(Map<String, dynamic>.from(decoded));
  }
}
