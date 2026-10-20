import '../models/mock_config.dart';
import '../models/test_session.dart';

/// Single source of truth for exam duration, qualifying marks and formatting.
///
/// The old code mixed three different systems:
///   * HTML booklet: fixed 9,000 seconds and absolute 90 / 82 marks.
///   * CBT: config minutes but no wall-clock deadline.
///   * Result/history: 60% general and a rounded 55% reserved cut-off.
///
/// All screens now use the same relative rules.  For a 150-mark paper this
/// still produces the official 90 (general) and 82 (reserved) marks.
class ExamRules {
  const ExamRules._();

  static const double generalPassRatio = 0.60;
  static const double reservedPassRatio = 0.55;

  static int generalPassMark(int total) =>
      total <= 0 ? 0 : (total * generalPassRatio).floor();

  static int reservedPassMark(int total) =>
      total <= 0 ? 0 : (total * reservedPassRatio).floor();

  static bool isGeneralPass(int score, int total) =>
      score >= generalPassMark(total);

  static bool isReservedPass(int score, int total) =>
      score >= reservedPassMark(total);

  static double percentage(int score, int total) =>
      total <= 0 ? 0 : (score / total) * 100;

  static double accuracy(int correct, int attempted) =>
      attempted <= 0 ? 0 : (correct / attempted) * 100;

  static int timeLimitSeconds(TestSession session) =>
      session.config.timeLimitMinutes * 60;

  static int timeLimitSecondsFor(MockConfig config) =>
      config.timeLimitMinutes * 60;

  static String formatClock(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  static String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m मिनट';
    if (m == 0) return '$h घण्टे';
    return '$h घण्टे $m मिनट';
  }
}
