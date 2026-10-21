import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector replacements for questions whose source images were never present in
/// the extracted bank.  The same catalogue feeds Flutter (CustomPainter) and
/// the HTML booklet (inline SVG), so both engines show the same diagram.
enum FigureKind {
  triangleRatio,
  starSixAngles,
  circleRelation,
  magneticField,
  triangleValue,
  parallelograms,
  solidCube,
  cubeNet,
  solidShapes,
}

class FigureSpec {
  final FigureKind kind;
  final int option;

  const FigureSpec(this.kind, {this.option = -1});

  @override
  bool operator ==(Object other) =>
      other is FigureSpec && other.kind == kind && other.option == option;

  @override
  int get hashCode => Object.hash(kind, option);
}

class QuestionFigureCatalog {
  const QuestionFigureCatalog._();

  static const Map<String, FigureSpec> _questionFigures = {
    '42585dbbc302b422': FigureSpec(FigureKind.triangleRatio),
    'd08e892ddb89e48a': FigureSpec(FigureKind.starSixAngles),
    'b7dec56ed779575b': FigureSpec(FigureKind.circleRelation),
    'd0400850b8328f8b': FigureSpec(FigureKind.magneticField),
    '8635839d93b24272': FigureSpec(FigureKind.triangleValue),
    '240502e5a4f70e25': FigureSpec(FigureKind.parallelograms),
    'ctet-p1-2018-pyq_q056': FigureSpec(FigureKind.solidCube),
    'ctet-p1-2018-pyq_q058': FigureSpec(FigureKind.solidCube),
  };

  static const Set<String> _optionFigureIds = {
    'ctet-p1-2018-pyq_q056',
    'ctet-p1-2018-pyq_q058',
  };

  static bool hasQuestionFigure(String questionId) =>
      _questionFigures.containsKey(questionId);

  static bool hasOptionFigures(String questionId) =>
      _optionFigureIds.contains(questionId);

  static Widget buildQuestion({
    required String questionId,
    required bool isDark,
    double height = 190,
  }) {
    final spec = _questionFigures[questionId];
    if (spec == null) return const SizedBox.shrink();
    return _FigureCanvas(spec: spec, isDark: isDark, height: height);
  }

  static Widget buildOption({
    required String questionId,
    required int optionIndex,
    required bool isDark,
  }) {
    final kind = questionId == 'ctet-p1-2018-pyq_q056'
        ? FigureKind.cubeNet
        : FigureKind.solidShapes;
    return _FigureCanvas(
      spec: FigureSpec(kind, option: optionIndex),
      isDark: isDark,
      height: 108,
    );
  }

  static String? questionSvg(String questionId) {
    final spec = _questionFigures[questionId];
    return spec == null ? null : _svg(spec);
  }

  static String? optionSvg(String questionId, int optionIndex) {
    if (!_optionFigureIds.contains(questionId)) return null;
    final kind = questionId == 'ctet-p1-2018-pyq_q056'
        ? FigureKind.cubeNet
        : FigureKind.solidShapes;
    return _svg(FigureSpec(kind, option: optionIndex));
  }

  static String _svg(FigureSpec spec) {
    const stroke = '#334155';
    const accent = '#2563eb';
    const muted = '#64748b';

    String text(int x, int y, String value,
            {int size = 13, String color = stroke, String weight = '600'}) =>
        '<text x="$x" y="$y" text-anchor="middle" font-family="Arial, sans-serif" '
        'font-size="$size" font-weight="$weight" fill="$color">$value</text>';

    String line(int x1, int y1, int x2, int y2,
            {String color = stroke, int width = 2, String dash = ''}) =>
        '<line x1="$x1" y1="$y1" x2="$x2" y2="$y2" stroke="$color" '
        'stroke-width="$width" ${dash.isEmpty ? '' : 'stroke-dasharray="$dash"'} />';

    String rect(int x, int y, int w, int h,
            {String color = stroke, int width = 2, String fill = 'none'}) =>
        '<rect x="$x" y="$y" width="$w" height="$h" rx="2" fill="$fill" '
        'stroke="$color" stroke-width="$width" />';

    String circle(int cx, int cy, int r,
            {String color = stroke, int width = 2, String fill = 'none'}) =>
        '<circle cx="$cx" cy="$cy" r="$r" fill="$fill" stroke="$color" '
        'stroke-width="$width" />';

    String path(String d, {String color = stroke, int width = 2, String fill = 'none'}) =>
        '<path d="$d" fill="$fill" stroke="$color" stroke-width="$width" '
        'stroke-linejoin="round" stroke-linecap="round" />';

    String wrap(String body, {int w = 340, int h = 190}) =>
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" '
        'role="img" style="width:100%;max-width:${w}px;height:auto">$body</svg>';

    switch (spec.kind) {
      case FigureKind.triangleRatio:
        return wrap(
          path('M170 34 L48 154 L292 154 Z') +
              text(170, 22, 'A') +
              text(36, 168, 'B') +
              text(304, 168, 'C') +
              text(170, 52, '50°', color: accent) +
              text(94, 130, '2x', color: accent) +
              text(244, 130, '3x', color: accent) +
              text(170, 184, 'B : C = 2 : 3', size: 12, color: muted),
        );
      case FigureKind.starSixAngles:
        final points = <String>[];
        for (var i = 0; i < 12; i++) {
          final angle = -math.pi / 2 + i * math.pi / 6;
          final radius = i.isEven ? 76.0 : 38.0;
          final x = 170 + radius * math.cos(angle);
          final y = 96 + radius * math.sin(angle);
          points.add('${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)}');
        }
        final labels = <String>['P', 'Q', 'R', 'S', 'T', 'U'];
        final body = StringBuffer('<polygon points="${points.join(' ')}" '
            'fill="#eff6ff" stroke="$stroke" stroke-width="2" />');
        for (var i = 0; i < 6; i++) {
          final angle = -math.pi / 2 + i * math.pi / 3;
          final x = (170 + 92 * math.cos(angle)).round();
          final y = (96 + 92 * math.sin(angle) + 5).round();
          body.write(text(x, y, labels[i], size: 13, color: accent));
        }
        return wrap(body.toString());
      case FigureKind.circleRelation:
        return wrap(
          circle(170, 98, 70) +
              line(170, 98, 104, 148) +
              line(170, 98, 236, 148) +
              line(170, 98, 170, 28) +
              line(170, 28, 104, 148) +
              line(170, 28, 236, 148) +
              circle(170, 98, 5, color: accent) +
              text(184, 92, 'O', color: accent) +
              text(90, 158, 'A') +
              text(250, 158, 'B') +
              text(170, 18, 'C') +
              text(170, 124, 'x', color: accent, size: 15) +
              text(202, 68, 'y', color: accent, size: 15) +
              text(170, 184, 'O केन्द्र है / O is the centre', size: 11, color: muted),
        );
      case FigureKind.magneticField:
        final body = StringBuffer(rect(36, 30, 268, 132, color: muted));
        for (var row = 0; row < 4; row++) {
          for (var col = 0; col < 8; col++) {
            final x = 62 + col * 32;
            final y = 52 + row * 28;
            body.write('<path d="M${x - 5} ${y - 5} L${x + 5} ${y + 5} '
                'M${x + 5} ${y - 5} L${x - 5} ${y + 5}" stroke="$muted" '
                'stroke-width="1.6" />');
          }
        }
        body
          ..write(line(54, 102, 142, 102, color: accent, width: 3))
          ..write(path('M142 102 L132 96 L132 108 Z', color: accent, fill: accent))
          ..write(text(90, 90, 'v', color: accent))
          ..write(text(76, 130, 'e⁻', color: accent))
          ..write(line(212, 72, 212, 138, color: '#dc2626', width: 3, dash: '5 4'))
          ..write(path('M212 140 L205 128 L219 128 Z', color: '#dc2626', fill: '#dc2626'))
          ..write(text(244, 128, 'F', color: '#dc2626'))
          ..write(text(244, 144, 'into paper', size: 10, color: '#dc2626'))
          ..write(text(62, 24, 'B (into page)', size: 11, color: muted));
        return wrap(body.toString());
      case FigureKind.triangleValue:
        return wrap(
          path('M160 32 L54 154 L270 154 Z') +
              line(270, 154, 326, 154, color: muted) +
              text(160, 20, 'A') +
              text(40, 168, 'B') +
              text(282, 168, 'C') +
              text(310, 148, 'D') +
              text(160, 70, 'x', color: accent, size: 16) +
              text(86, 144, '60°', color: accent) +
              text(286, 138, '110°', color: accent) +
              text(170, 184, 'x = ?', size: 12, color: muted),
        );
      case FigureKind.parallelograms:
        return wrap(
          path('M44 66 L164 66 L206 154 L86 154 Z', color: accent) +
              path('M144 40 L286 40 L250 138 L108 138 Z') +
              text(34, 58, 'A') +
              text(172, 58, 'B') +
              text(214, 168, 'C') +
              text(76, 168, 'D') +
              text(154, 32, 'P') +
              text(296, 32, 'Q') +
              text(258, 152, 'R') +
              text(100, 152, 'S') +
              text(186, 104, 'θ', color: '#dc2626', size: 18) +
              text(170, 184, 'ABCD and PQRS are parallelograms', size: 11, color: muted),
        );
      case FigureKind.solidCube:
        return wrap(
          '<path d="M120 58 L188 34 L246 64 L178 92 Z" fill="#dbeafe" stroke="$stroke" stroke-width="2" />'
              '<path d="M120 58 L178 92 L178 158 L120 124 Z" fill="#eff6ff" stroke="$stroke" stroke-width="2" />'
              '<path d="M178 92 L246 64 L246 130 L178 158 Z" fill="#bfdbfe" stroke="$stroke" stroke-width="2" />',
        );
      case FigureKind.cubeNet:
        final body = StringBuffer();
        const s = 30;
        const y1 = 46;
        const y2 = 76;
        final col = [42, 72, 102, 132];
        switch (spec.option) {
          case 0:
            // Five squares in one strip: folds into an open tube.
            for (var i = 0; i < 5; i++) {
              body.write(rect(18 + i * s, y1, s, s));
            }
            body.write(rect(48, y2, s, s));
            break;
          case 1:
            // Standard cross net: four in a row, one above and one below.
            for (var i = 0; i < 4; i++) {
              body.write(rect(col[i], y2, s, s, color: accent));
            }
            body.write(rect(72, y1 - s, s, s, color: accent));
            body.write(rect(72, y2 + s, s, s, color: accent));
            break;
          case 2:
            // 2x3 block is not one of the eleven cube nets.
            for (var row = 0; row < 2; row++) {
              for (var c = 0; c < 3; c++) {
                body.write(rect(74 + c * s, y1 + row * s, s, s));
              }
            }
            break;
          default:
            // Five-square cross plus a detached sixth square.
            body
              ..write(rect(118, y1, s, s))
              ..write(rect(88, y1 + s, s, s))
              ..write(rect(148, y1 + s, s, s))
              ..write(rect(118, y1 + s, s, s))
              ..write(rect(118, y1 + 2 * s, s, s))
              ..write(rect(18, y1 + 2 * s, s, s));
            break;
        }
        body.write(text(170, 178, 'Net ${String.fromCharCode(65 + spec.option)}',
            size: 10, color: muted));
        return wrap(body.toString(), h: 190);
      case FigureKind.solidShapes:
        final body = StringBuffer();
        switch (spec.option) {
          case 0:
            // Cube
            body
              ..write('<path d="M118 48 L178 30 L232 56 L172 76 Z" fill="#dbeafe" stroke="$stroke" stroke-width="2" />')
              ..write('<path d="M118 48 L172 76 L172 136 L118 108 Z" fill="#eff6ff" stroke="$stroke" stroke-width="2" />')
              ..write('<path d="M172 76 L232 56 L232 112 L172 136 Z" fill="#bfdbfe" stroke="$stroke" stroke-width="2" />');
            break;
          case 1:
            // Cylinder
            body
              ..write('<ellipse cx="170" cy="52" rx="48" ry="16" fill="#dbeafe" stroke="$stroke" stroke-width="2" />')
              ..write('<path d="M122 52 L122 132 M218 52 L218 132" stroke="$stroke" stroke-width="2" />')
              ..write('<ellipse cx="170" cy="132" rx="48" ry="16" fill="#eff6ff" stroke="$stroke" stroke-width="2" />');
            break;
          case 2:
            // Cone
            body
              ..write('<path d="M170 30 L118 136 L222 136 Z" fill="#eff6ff" stroke="$stroke" stroke-width="2" />')
              ..write('<ellipse cx="170" cy="136" rx="52" ry="16" fill="#dbeafe" stroke="$stroke" stroke-width="2" />');
            break;
          default:
            // Sphere
            body
              ..write(circle(170, 86, 52, color: stroke, width: 2, fill: '#dbeafe'))
              ..write('<path d="M128 66 Q170 40 212 66" fill="none" stroke="$muted" stroke-width="1.5" />');
            break;
        }
        body.write(text(170, 178, 'Shape ${String.fromCharCode(65 + spec.option)}',
            size: 10, color: muted));
        return wrap(body.toString(), h: 190);
    }
  }
}

class _FigureCanvas extends StatelessWidget {
  final FigureSpec spec;
  final bool isDark;
  final double height;

  const _FigureCanvas({
    required this.spec,
    required this.isDark,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: CustomPaint(
        painter: _FigurePainter(spec: spec, isDark: isDark),
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  final FigureSpec spec;
  final bool isDark;

  _FigurePainter({required this.spec, required this.isDark});

  Color get _ink => isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
  Color get _accent => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get _muted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  @override
  void paint(Canvas canvas, Size size) {
    const designWidth = 340.0;
    const designHeight = 190.0;
    final scale = math.min(size.width / designWidth, size.height / designHeight);
    canvas.save();
    canvas.translate(
      (size.width - designWidth * scale) / 2,
      (size.height - designHeight * scale) / 2,
    );
    canvas.scale(scale);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _accent;
    final fill = Paint()..color = _accent.withValues(alpha: 0.10);

    switch (spec.kind) {
      case FigureKind.triangleRatio:
        _triangle(canvas, stroke, fill);
        _text(canvas, 'A', 170, 18);
        _text(canvas, 'B', 34, 166);
        _text(canvas, 'C', 306, 166);
        _text(canvas, '50°', 170, 52, color: _accent);
        _text(canvas, '2x', 92, 128, color: _accent);
        _text(canvas, '3x', 248, 128, color: _accent);
        _text(canvas, 'B : C = 2 : 3', 170, 186, size: 11, color: _muted);
        break;
      case FigureKind.starSixAngles:
        final points = <Offset>[];
        for (var i = 0; i < 12; i++) {
          final angle = -math.pi / 2 + i * math.pi / 6;
          final radius = i.isEven ? 76.0 : 38.0;
          points.add(Offset(170 + radius * math.cos(angle), 96 + radius * math.sin(angle)));
        }
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        path.close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        final labels = ['P', 'Q', 'R', 'S', 'T', 'U'];
        for (var i = 0; i < 6; i++) {
          final angle = -math.pi / 2 + i * math.pi / 3;
          _text(canvas, labels[i], 170 + 94 * math.cos(angle),
              96 + 94 * math.sin(angle) + 5, color: _accent);
        }
        break;
      case FigureKind.circleRelation:
        canvas.drawCircle(const Offset(170, 98), 70, stroke);
        canvas.drawCircle(const Offset(170, 98), 4, Paint()..color = _accent);
        for (final target in const [Offset(104, 148), Offset(236, 148), Offset(170, 28)]) {
          canvas.drawLine(const Offset(170, 98), target, stroke);
        }
        canvas.drawLine(const Offset(170, 28), const Offset(104, 148), stroke);
        canvas.drawLine(const Offset(170, 28), const Offset(236, 148), stroke);
        _text(canvas, 'O', 185, 93, color: _accent);
        _text(canvas, 'A', 90, 160);
        _text(canvas, 'B', 250, 160);
        _text(canvas, 'C', 170, 16);
        _text(canvas, 'x', 170, 126, color: _accent, size: 15);
        _text(canvas, 'y', 204, 66, color: _accent, size: 15);
        _text(canvas, 'O केन्द्र है / O is the centre', 170, 186, size: 11, color: _muted);
        break;
      case FigureKind.magneticField:
        canvas.drawRect(const Rect.fromLTWH(36, 30, 268, 132), stroke);
        final cross = Paint()
          ..color = _muted
          ..strokeWidth = 1.5;
        for (var row = 0; row < 4; row++) {
          for (var col = 0; col < 8; col++) {
            final x = 62.0 + col * 32;
            final y = 52.0 + row * 28;
            canvas.drawLine(Offset(x - 5, y - 5), Offset(x + 5, y + 5), cross);
            canvas.drawLine(Offset(x + 5, y - 5), Offset(x - 5, y + 5), cross);
          }
        }
        _arrow(canvas, const Offset(54, 102), const Offset(142, 102), _accent);
        _text(canvas, 'v', 90, 90, color: _accent);
        _text(canvas, 'e⁻', 76, 132, color: _accent);
        _arrow(canvas, const Offset(212, 72), const Offset(212, 140),
            const Color(0xFFDC2626));
        _text(canvas, 'F', 246, 128, color: const Color(0xFFDC2626));
        _text(canvas, 'into paper', 246, 146, size: 10, color: const Color(0xFFDC2626));
        _text(canvas, 'B (into page)', 66, 24, size: 11, color: _muted);
        break;
      case FigureKind.triangleValue:
        final path = Path()
          ..moveTo(160, 32)
          ..lineTo(54, 154)
          ..lineTo(270, 154)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        canvas.drawLine(const Offset(270, 154), const Offset(326, 154), stroke);
        _text(canvas, 'A', 160, 18);
        _text(canvas, 'B', 40, 168);
        _text(canvas, 'C', 282, 168);
        _text(canvas, 'D', 312, 148);
        _text(canvas, 'x', 160, 70, color: _accent, size: 16);
        _text(canvas, '60°', 86, 144, color: _accent);
        _text(canvas, '110°', 288, 138, color: _accent);
        _text(canvas, 'x = ?', 170, 186, size: 11, color: _muted);
        break;
      case FigureKind.parallelograms:
        final first = Path()
          ..moveTo(44, 66)
          ..lineTo(164, 66)
          ..lineTo(206, 154)
          ..lineTo(86, 154)
          ..close();
        final second = Path()
          ..moveTo(144, 40)
          ..lineTo(286, 40)
          ..lineTo(250, 138)
          ..lineTo(108, 138)
          ..close();
        canvas.drawPath(first, stroke);
        canvas.drawPath(second, accent);
        _text(canvas, 'A', 34, 58);
        _text(canvas, 'B', 172, 58);
        _text(canvas, 'C', 214, 168);
        _text(canvas, 'D', 76, 168);
        _text(canvas, 'P', 154, 32);
        _text(canvas, 'Q', 296, 32);
        _text(canvas, 'R', 258, 152);
        _text(canvas, 'S', 100, 152);
        _text(canvas, 'θ', 186, 104, color: const Color(0xFFDC2626), size: 18);
        _text(canvas, 'ABCD and PQRS are parallelograms', 170, 186, size: 11, color: _muted);
        break;
      case FigureKind.solidCube:
        _drawCube(canvas, const Offset(120, 58), 68, 64);
        break;
      case FigureKind.cubeNet:
        _drawCubeNet(canvas, stroke, accent, spec.option);
        break;
      case FigureKind.solidShapes:
        _drawSolidShape(canvas, stroke, accent, spec.option);
        break;
    }
    canvas.restore();
  }

  void _triangle(Canvas canvas, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(170, 34)
      ..lineTo(48, 154)
      ..lineTo(292, 154)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawCube(Canvas canvas, Offset origin, double width, double height) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _ink;
    final top = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(origin.dx + width, origin.dy - 24)
      ..lineTo(origin.dx + width + 58, origin.dy + 6)
      ..lineTo(origin.dx + 58, origin.dy + 30)
      ..close();
    final left = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(origin.dx + 58, origin.dy + 30)
      ..lineTo(origin.dx + 58, origin.dy + 30 + height)
      ..lineTo(origin.dx, origin.dy + height)
      ..close();
    final right = Path()
      ..moveTo(origin.dx + 58, origin.dy + 30)
      ..lineTo(origin.dx + width + 58, origin.dy + 6)
      ..lineTo(origin.dx + width + 58, origin.dy + 6 + height)
      ..lineTo(origin.dx + 58, origin.dy + 30 + height)
      ..close();
    canvas.drawPath(top, Paint()..color = _accent.withValues(alpha: 0.18));
    canvas.drawPath(left, Paint()..color = _accent.withValues(alpha: 0.08));
    canvas.drawPath(right, Paint()..color = _accent.withValues(alpha: 0.13));
    canvas.drawPath(top, p);
    canvas.drawPath(left, p);
    canvas.drawPath(right, p);
  }

  void _drawCubeNet(Canvas canvas, Paint stroke, Paint accent, int option) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _ink;
    const s = 30.0;
    const y1 = 46.0;
    const y2 = 76.0;
    const cols = [42.0, 72.0, 102.0, 132.0];
    void square(double x, double y, {Paint? paint}) {
      final rect = Rect.fromLTWH(x, y, s, s);
      canvas.drawRect(rect, Paint()..color = _accent.withValues(alpha: 0.10));
      canvas.drawRect(rect, paint ?? ink);
    }

    switch (option) {
      case 0:
        for (var i = 0; i < 5; i++) {
          square(18 + i * s, y1);
        }
        square(48, y2);
        break;
      case 1:
        for (final col in cols) {
          square(col, y2, paint: accent);
        }
        square(72, y1 - s, paint: accent);
        square(72, y2 + s, paint: accent);
        break;
      case 2:
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 3; col++) {
            square(74 + col * s, y1 + row * s);
          }
        }
        break;
      default:
        square(118, y1);
        square(88, y1 + s);
        square(148, y1 + s);
        square(118, y1 + s);
        square(118, y1 + 2 * s);
        square(18, y1 + 2 * s);
        break;
    }
    _text(canvas, 'Net ${String.fromCharCode(65 + option)}', 170, 178,
        size: 10, color: _muted);
  }

  void _drawSolidShape(Canvas canvas, Paint stroke, Paint accent, int option) {
    final fill = Paint()..color = _accent.withValues(alpha: 0.10);
    void box(Path path) {
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    switch (option) {
      case 0:
        final top = Path()
          ..moveTo(118, 48)
          ..lineTo(178, 30)
          ..lineTo(232, 56)
          ..lineTo(172, 76)
          ..close();
        final left = Path()
          ..moveTo(118, 48)
          ..lineTo(172, 76)
          ..lineTo(172, 136)
          ..lineTo(118, 108)
          ..close();
        final right = Path()
          ..moveTo(172, 76)
          ..lineTo(232, 56)
          ..lineTo(232, 112)
          ..lineTo(172, 136)
          ..close();
        box(top);
        box(left);
        box(right);
        break;
      case 1:
        canvas.drawOval(const Rect.fromLTWH(122, 36, 96, 32), fill);
        canvas.drawOval(const Rect.fromLTWH(122, 36, 96, 32), stroke);
        canvas.drawLine(const Offset(122, 52), const Offset(122, 132), stroke);
        canvas.drawLine(const Offset(218, 52), const Offset(218, 132), stroke);
        canvas.drawOval(const Rect.fromLTWH(122, 116, 96, 32), fill);
        canvas.drawOval(const Rect.fromLTWH(122, 116, 96, 32), stroke);
        break;
      case 2:
        final cone = Path()
          ..moveTo(170, 30)
          ..lineTo(118, 136)
          ..lineTo(222, 136)
          ..close();
        canvas.drawPath(cone, fill);
        canvas.drawPath(cone, stroke);
        canvas.drawOval(const Rect.fromLTWH(118, 120, 104, 32), fill);
        canvas.drawOval(const Rect.fromLTWH(118, 120, 104, 32), stroke);
        break;
      default:
        canvas.drawCircle(const Offset(170, 86), 52, fill);
        canvas.drawCircle(const Offset(170, 86), 52, stroke);
        final arc = Path()
          ..moveTo(128, 66)
          ..quadraticBezierTo(170, 42, 212, 66);
        canvas.drawPath(arc, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _muted);
        break;
    }
    _text(canvas, 'Shape ${String.fromCharCode(65 + option)}', 170, 178,
        size: 10, color: _muted);
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - 12 * math.cos(angle - 0.45),
          to.dy - 12 * math.sin(angle - 0.45))
      ..lineTo(to.dx - 12 * math.cos(angle + 0.45),
          to.dy - 12 * math.sin(angle + 0.45))
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  void _text(Canvas canvas, String value, double x, double y,
      {Color? color, double size = 13}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color ?? _ink,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x - painter.width / 2, y - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FigurePainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.isDark != isDark;
}
