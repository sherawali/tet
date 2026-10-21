import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/services/html_booklet_builder.dart';

/// Guards the specialised stem renderers.  Every question type that the
/// booklet treats specially must keep its own renderer instead of falling
/// back to plain text.
void main() {
  group('HtmlBookletBuilder stem renderers', () {
    String render(String stem) => HtmlBookletBuilder.formatQuestionStemHtml(stem);

    test('inline dot-notation statements become a statement list', () {
      final html = render(
        "गणित के प्राथमिक पाठ्यक्रम में 'प्रतिचित्रण' का परिचय देने का मुख्य उद्देश्य है– "
        'A. त्रिविम विचार–क्षमता को प्रोत्साहन देना। '
        'B. अनुपातिक विवेचन को प्रोत्साहन देना। '
        'C. विषय को सरल और रुचिकर बनाना।',
      );
      expect(html, contains('multi-statement-wrapper'));
      expect(html, contains('stmt-marker'));
    });

    test('two inline statements become a statement list', () {
      final html = render(
        'Read the following statements: A. Graphology has been practised for '
        'thousands of years. B. A person\'s handwriting reveals everything '
        'about him.',
      );
      expect(html, contains('multi-statement-wrapper'));
    });

    test('assertion-reason without a colon is still detected', () {
      final html = render(
        'दावा (A) विद्यालय में अधिगम बच्चों के सामाजिक संदर्भों से निर्लिप्त होना चाहिए। '
        'तर्क (B) विद्यालय में प्रवेश से पहले ही छात्रों के पास शब्द भंडार की समझ होती है।',
      );
      expect(html, contains('kathan-wrapper'));
      expect(html, contains('assertion-box'));
      expect(html, contains('reason-box'));
    });

    test('match-the-column stems keep their table renderer', () {
      final html = render(
        'स्तम्भ A और स्तम्भ B का मिलान कीजिए : स्तम्भ A स्तम्भ B '
        'A. जीरा I. कील की तरह दिखता है B. केसर II. दक्षिणी अमेरिका से उत्पत्ति',
      );
      expect(html, contains('match-table'));
    });

    test('a plain question stays plain', () {
      final html = render('निम्नलिखित में से कौन-सा कथन सही है?');
      expect(html, contains('class="stem-p"'));
      expect(html, isNot(contains('multi-statement-wrapper')));
      expect(html, isNot(contains('kathan-wrapper')));
    });

    test('prose that only mentions A. and B. is not split up', () {
      final html = render(
        'A. B. these letters appear in the sentence as a pair of options',
      );
      expect(html, contains('class="stem-p"'));
    });
  });
}
