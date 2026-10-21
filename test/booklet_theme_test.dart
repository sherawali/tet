import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/models/mock_config.dart';
import 'package:tet_app/models/question.dart';
import 'package:tet_app/models/test_session.dart';
import 'package:tet_app/services/html_booklet_builder.dart';

/// The dark palette of the booklet has to cover every special renderer.
/// A missed class means black text on a black card, i.e. the question becomes
/// invisible for the candidate.
void main() {
  TestSession session() => TestSession(
        id: 'dark-test',
        config: MockConfig(
          mode: MockMode.pyq,
          exam: 'ctet1',
          totalQuestions: 1,
          timeLimitMinutes: 150,
          seed: 1,
        ),
        questions: [
          Question(
            id: 'q1',
            exams: '["ctet1"]',
            section: 'math',
            topicIndex: 0,
            topicName: 'math',
            difficulty: 2,
            qHindi: 'निम्नलिखित कथनों पर विचार कीजिए : (A) पहला (B) दूसरा',
            optionsHindi: const ['एक', 'दो', 'तीन', 'चार'],
            qEnglish: 'Consider the statements: (A) first (B) second',
            optionsEnglish: const ['One', 'Two', 'Three', 'Four'],
            answer: 0,
            pScore: 1,
          ),
        ],
        passages: const {},
        elapsedSeconds: 0,
        startTime: DateTime(2026, 10, 21),
        paperTitle: 'Dark',
        setCode: 'A',
      );

  test('booklet carries the theme of the app', () {
    final light = HtmlBookletBuilder.buildHtml(session(), isDark: false);
    final dark = HtmlBookletBuilder.buildHtml(session(), isDark: true);
    final system = HtmlBookletBuilder.buildHtml(session());

    String htmlTag(String doc) =>
        RegExp(r'<html[^>]*>').firstMatch(doc)?.group(0) ?? '';

    expect(htmlTag(light), contains('data-theme="light"'));
    expect(htmlTag(dark), contains('data-theme="dark"'));
    expect(htmlTag(system), isNot(contains('data-theme')));
  });

  test('dark palette covers every special renderer', () {
    final html = HtmlBookletBuilder.buildHtml(session(), isDark: true);

    // Every class that the complex renderers paint must have a dark rule,
    // otherwise its hard coded light text lands on a dark background.
    const critical = [
      '.stmt-intro',
      '.stmt-text',
      '.stmt-marker',
      '.stmt-conclusion',
      '.stmt-list',
      '.match-intro',
      '.match-conclusion',
      '.match-table td',
      '.match-table th',
      '.kathan-intro',
      '.kathan-body',
      '.kathan-conclusion',
      '.kathan-box',
      '.q-table td',
      '.q-table th',
      '.opt-primary',
      '.opt-secondary',
      '.option-row',
      '.opt-badge',
      '.q-stem-translation',
      '.lang-tag',
      '.stem-p',
      '.q-stem',
      '.q-num',
      '.prose-p',
      '.poem-line',
      '.stimulus-content',
      '.stimulus-header',
      '.cover-exam-title',
      '.cover-authority',
      '.set-badge-box',
      '.roll-digit-box',
      '.palette-grid a',
      '.result-mark.ok',
      '.result-mark.wrong',
      '.result-mark.skipped',
      '.confirm-card h3',
      '.confirm-card p',
      '.c-stat-box span',
      '.rep-radio-label',
      '.q-peek-btn',
      '.q-rev-btn',
      '.q-topic-tag',
      '.q-marks',
    ];

    for (final selector in critical) {
      expect(
        html.contains('html[data-theme="dark"] $selector'),
        isTrue,
        reason: 'dark mode has no rule for $selector',
      );
    }
  });

  test('dark palette never leaves a light background behind dark text', () {
    final html = HtmlBookletBuilder.buildHtml(session(), isDark: true);
    // The dark rules must set a background wherever the light theme paints one.
    expect(
      html.contains('html[data-theme="dark"] .kathan-box { background:'),
      isTrue,
    );
    expect(
      html.contains('html[data-theme="dark"] .stmt-list { background:'),
      isTrue,
    );
    expect(
      html.contains('html[data-theme="dark"] .q-stem-translation { background:'),
      isTrue,
    );
  });

  group('compact screens (S23 and smaller)', () {
    final css = HtmlBookletBuilder.buildHtml(session(), isDark: false);

    test('options keep a 48dp touch target on phones', () {
      expect(css.contains('@media (max-width: 768px)'), isTrue);
      expect(
        css.contains('min-height: 48px'),
        isTrue,
        reason: 'option rows must stay at least 48dp high on a phone',
      );
    });

    test('the language switcher wraps instead of overflowing', () {
      expect(css.contains('flex-wrap: wrap'), isTrue);
      expect(css.contains('.cbt-lang-switcher'), isTrue);
    });

    test('complex question types get compact styling on phones', () {
      expect(css.contains('.stmt-row { gap: 8px; }'), isTrue);
      expect(css.contains('.kathan-body { font-size: 14px; }'), isTrue);
      expect(css.contains('.match-table { font-size: 13px; }'), isTrue);
    });
  });
}
