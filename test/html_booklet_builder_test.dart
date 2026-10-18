import 'package:flutter_test/flutter_test.dart';
import 'package:tet_app/services/html_booklet_builder.dart';

void main() {
  group('HtmlBookletBuilder Universal Question Parser Tests', () {
    test('Sequential Match-the-Following renders as HTML table', () {
      const stem = '''कॉलम 'A' का मिलान कॉलम 'B' से कीजिए —
कॉलम 'A': (1) व्याकरण (2) शब्दार्थ विकास (3) बबलाना (4) ध्वन्यात्मक विकास
कॉलम 'B': (a) पहचानने योग्य भाषा बोलने की क्षमता (b) भाषा के नियमों का उपयोग (c) भाषा की ध्वनियों का उत्पादन (d) शब्दों का अर्थ समझना
नीचे दिए गए कूट में से सही उत्तर का चयन कीजिए:''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="match-table-wrapper"'), isTrue);
      expect(html.contains('<table class="match-table">'), isTrue);
      expect(html.contains('<b>(1)</b>'), isTrue);
      expect(html.contains('<b>(a)</b>'), isTrue);
      expect(html.contains('class="match-conclusion"'), isTrue);
    });

    test('Alternating Dot Notation Match question renders as HTML table', () {
      const stem = '''पठन के तरीकों का, पाठक को क्या करना चाहिए, ये मिलान कीजिए : 
पठन के तरीके पाठक को क्या करना चाहिए 
A. अनुमान i. लेखक कैसे लिखते हैं, इसके आधार पर यह सुनिश्चित करना चाहिए। 
B. निष्कर्ष निकालना ii. अपरिचित शब्दों को समझने के लिए पाठ्य-सामग्री के कुछ हिस्सों से मदद लेनी चाहिए। 
C. संदर्भ से जोड़कर अर्थ निकालना iii. शीर्ष कथन या प्रस्तावना पर ध्यान देते हुए यह देखना चाहिए।
कूट चुनिए:''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="match-table-wrapper"'), isTrue);
      expect(html.contains('<table class="match-table">'), isTrue);
      expect(html.contains('<b>A.</b>'), isTrue);
      expect(html.contains('<b>i.</b>'), isTrue);
    });

    test('Dashed pairs Match question renders as HTML table', () {
      const stem = '''निम्नलिखित को सुमेलित कीजिए:
1. नीलगिरी – (a) अनाईमुडी 
2. सतपुड़ा – (b) डोडाबेट्टा
कूट :''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="match-table-wrapper"'), isTrue);
      expect(html.contains('<table class="match-table">'), isTrue);
      expect(html.contains('1.'), isTrue);
      expect(html.contains('(a)'), isTrue);
    });

    test('Assertion-Reason renders as structured colored cards', () {
      const stem = '''अभिकथन (A): बच्चे भाषा को अनुकरण और अभ्यास के माध्यम से सीखते हैं।
कारण (R): भाषा विकास केवल जैविक परिपक्वता का परिणाम है।
दिए गए विकल्पों में से सही विकल्प चुनिए:''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="kathan-wrapper"'), isTrue);
      expect(html.contains('class="kathan-box assertion-box"'), isTrue);
      expect(html.contains('class="kathan-box reason-box"'), isTrue);
      expect(html.contains('class="kathan-tag tag-a"'), isTrue);
      expect(html.contains('class="kathan-tag tag-r"'), isTrue);
      expect(html.contains('class="kathan-conclusion"'), isTrue);
    });

    test('Two-Statement question renders as structured cards', () {
      const stem = '''नीचे दिए गए कथनों पर विचार कीजिए:
कथन (A) : स्लॉथ दिन के करीब 20 घंटे सोते है।
कथन (B) : लगभग जीवन के 20 वर्ष के अपने पूरे जीवन में वे मुश्किल से 5 पेड़ों तक ही घूम पाते है।
निम्नलिखित में से सही कूट चुनिए।''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="kathan-wrapper"'), isTrue);
      expect(html.contains('class="kathan-box assertion-box"'), isTrue);
      expect(html.contains('class="kathan-tag tag-a"'), isTrue);
    });

    test('Multi-Statement with Roman numerals renders as structured list', () {
      const stem = '''निम्नांकित कौन से कथन सर्जनात्मकता तथा बुद्धि के संदर्भ में सत्य हैं? 
(i) सर्जनात्मकता व बुद्धि के बीच सकारात्मक सम्बन्ध है। 
(ii) बुद्धिमान हो जाना यह निश्चित नहीं करता कि व्यक्ति सर्जनशील भी होगा। 
(iii) सर्जनात्मक परीक्षणों में अपसारी चिंतन का उपयोग होता है।
दिए गए विकल्पों में से सही उत्तर चुनिए:''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="multi-statement-wrapper"'), isTrue);
      expect(html.contains('class="stmt-list"'), isTrue);
      expect(html.contains('(i)'), isTrue);
      expect(html.contains('(ii)'), isTrue);
      expect(html.contains('(iii)'), isTrue);
      expect(html.contains('class="stmt-conclusion"'), isTrue);
    });

    test('Q63 from flutter_15.png preserves intro and creates clean statement cards without chopping intro', () {
      const stem = '''नीचे दिए गए कथनों (A) और (B) पर विचार कीजिए। कथन (A) : स्लॉथ दिन के करीब 20 घंटे सोते है। कथन (B) : लगभग जीवन के 20 वर्ष के अपने पूरे जीवन में वे मुश्किल से 5 पेड़ों तक ही घूम पाते है। निम्नलिखित में से सही कूट चुनिए।''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="kathan-wrapper"'), isTrue);
      expect(html.contains('नीचे दिए गए कथनों (A) और (B) पर विचार कीजिए।'), isTrue);
      expect(html.contains('स्लॉथ दिन के करीब 20 घंटे सोते है।'), isTrue);
      expect(html.contains('लगभग जीवन के 20 वर्ष के अपने पूरे जीवन में वे मुश्किल से 5 पेड़ों तक ही घूम पाते है।'), isTrue);
      expect(html.contains('निम्नलिखित में से सही कूट चुनिए।'), isTrue);
      // Ensure 'और' is NOT inside tag-a
      expect(html.contains('>और<'), isFalse);
    });

    test('Q64 from flutter_14.png renders 6-item match table and NEVER assertion-reason', () {
      const stem = '''सही सुमेलित युग्म/युग्मों का चयन कीजिए। भाषा जहाँ बोली जाती है (राज्य) (A) मलयालम (i) गोआ (B) कोंकणी (ii) केरल (C) मराठी (iii) झारखंड (D) गुजराती (iv) कर्नाटक (e) कन्नड़ (v) महाराष्ट्र (f) कुड़ुक (vi) गुजरात''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="match-table-wrapper"'), isTrue);
      expect(html.contains('<table class="match-table">'), isTrue);
      expect(html.contains('<b>(A)</b> मलयालम'), isTrue);
      expect(html.contains('<b>(i)</b> गोआ'), isTrue);
      expect(html.contains('<b>(e)</b> कन्नड़'), isTrue);
      expect(html.contains('<b>(f)</b> कुड़ुक'), isTrue);
      expect(html.contains('<b>(vi)</b> गुजरात'), isTrue);
      expect(html.contains('class="kathan-box"'), isFalse);
    });

    test('Q71 from flutter_16.png preserves full intro without duplicate chopped markers', () {
      const stem = '''निम्नलिखित कथन (A) तथा कथन (B) को ध्यान से पढ़ें तथा सही विकल्प का चुनाव करें। (A) लगभग 4700 वर्ष पूर्व सिंधु तथा इसकी सहायक नदियों के किनारे कुछ आरंभिक नगर फले-फूले। (B) गंगा तथा इसकी सहायक नदियों के किनारे नगरों का विकास लगभग 1500 वर्ष पूर्व हुआ।''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="multi-statement-wrapper"'), isTrue);
      expect(html.contains('निम्नलिखित कथन (A) तथा कथन (B) को ध्यान से पढ़ें तथा सही विकल्प का चुनाव करें।'), isTrue);
      expect(html.contains('लगभग 4700 वर्ष पूर्व सिंधु तथा इसकी सहायक नदियों के किनारे कुछ आरंभिक नगर फले-फूले।'), isTrue);
      expect(html.contains('गंगा तथा इसकी सहायक नदियों के किनारे नगरों का विकास लगभग 1500 वर्ष पूर्व हुआ।'), isTrue);
      // Ensure intro sentence is NOT chopped into statement bodies
      expect(html.contains('>तथा कथन<'), isFalse);
    });

    test('Q72 from flutter_16.png renders 4 inline items as clean statement list', () {
      const stem = '''निम्नलिखित में से कौन बाल-केन्द्रित रणनीतियों को सबसे अच्छा दर्शाता है? (A) चर्चा (B) प्रदर्शन (C) व्याख्यान (D) सर्वेक्षण''';

      final html = HtmlBookletBuilder.formatQuestionStemHtml(stem);
      expect(html.contains('class="multi-statement-wrapper"'), isTrue);
      expect(html.contains('class="stmt-list"'), isTrue);
      expect(html.contains('निम्नलिखित में से कौन बाल-केन्द्रित रणनीतियों को सबसे अच्छा दर्शाता है?'), isTrue);
      expect(html.contains('<b>(A)</b>') || html.contains('(A)'), isTrue);
      expect(html.contains('चर्चा'), isTrue);
      expect(html.contains('प्रदर्शन'), isTrue);
      expect(html.contains('व्याख्यान'), isTrue);
      expect(html.contains('सर्वेक्षण'), isTrue);
    });
  });
}

