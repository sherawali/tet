import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_shadows.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_strings.dart';
import '../services/language_service.dart';
import 'question_figure_catalog.dart';

/// Interactive Zoomable Diagram Viewer for Math & Science Questions
/// Supports Markdown images `![alt](url)`, network/asset images, and native geometry vector diagrams.
class MathDiagramWidget extends StatelessWidget {
  final String questionId;
  final String? rawText;
  final bool isDark;

  const MathDiagramWidget({
    super.key,
    required this.questionId,
    this.rawText,
    required this.isDark,
  });

  static final RegExp _markdownImageRegex = RegExp(
    r'!\[(.*?)\]\((.*?)\)',
    dotAll: true,
  );

  /// Check if a question contains or requires a diagram
  static bool hasDiagram(String qId, String text) {
    if (_markdownImageRegex.hasMatch(text)) return true;
    if (QuestionFigureCatalog.hasQuestionFigure(qId)) return true;
    if (qId.contains('utet-p1-2022-mathematics-q115')) return true;
    if (qId.contains('ctet-p1-2018-m-mathematics-q049')) return true;
    if (qId.contains('utet-p1-2020-mathematics-q117')) return true;
    if (qId.contains('utet-p1-2022-mathematics-q098')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Markdown image match
    if (rawText != null) {
      final imgMatch = _markdownImageRegex.firstMatch(rawText!);
      if (imgMatch != null) {
        final alt = imgMatch.group(1) ?? 'Diagram';
        final url = imgMatch.group(2) ?? '';
        return _buildImageCard(context, alt, url);
      }
    }

    // 2. Reconstructed figure for a question whose source image is missing.
    if (QuestionFigureCatalog.hasQuestionFigure(questionId)) {
      return QuestionFigureCatalog.buildQuestion(
        questionId: questionId,
        isDark: isDark,
      );
    }

    // 3. Geometry figure for UTET 2022 Math Q115
    if (questionId.contains('utet-p1-2022-mathematics-q115')) {
      return _buildGeometryDiagramCard(context);
    }

    // 3. Number Line for CTET 2018 Math Q049
    if (questionId.contains('ctet-p1-2018-m-mathematics-q049')) {
      return _buildCustomDiagramCard(
        context,
        badgeText: '📊 ${AppStrings.numberLineLabel}',
        title: LanguageService.instance.isHindi ? 'संख्या रेखा पर बिंदु A और B' : 'Points A and B on Number Line',
        painter: _CtetNumberLinePainter(isDark: isDark),
        width: 320,
        height: 120,
      );
    }

    // 4. Triangular Prism for UTET 2020 Math Q117
    if (questionId.contains('utet-p1-2020-mathematics-q117')) {
      return _buildCustomDiagramCard(
        context,
        badgeText: '📐 ${AppStrings.prismLabel}',
        title: AppStrings.prismLabel,
        painter: _TriangularPrismPainter(isDark: isDark),
        width: 280,
        height: 190,
      );
    }

    // 5. Shaded Fraction for UTET 2022 Math Q098
    if (questionId.contains('utet-p1-2022-mathematics-q098')) {
      return _buildCustomDiagramCard(
        context,
        badgeText: '🔲 ${AppStrings.shadedRegionLabel}',
        title: LanguageService.instance.isHindi ? 'आयत में छायांकित भाग' : 'Shaded Region in Rectangle',
        painter: _ShadedFractionPainter(isDark: isDark),
        width: 280,
        height: 150,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildImageCard(BuildContext context, String alt, String url) {
    final borderColor = isDark ? AppColors.lightTextSecondary : AppColors.lightBorder;
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');

    return GestureDetector(
      onTap: () => _openZoomDialog(
        context,
        title: alt.isNotEmpty ? alt : AppStrings.diagramLabel,
        child: isNetwork
            ? Image.network(url, fit: BoxFit.contain)
            : Image.asset(url, fit: BoxFit.contain),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? AppColors.primary : AppColors.darkTextPrimary,
          borderRadius: AppRadius.roundedBase,
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: AppRadius.roundedSm,
              child: isNetwork
                  ? Image.network(
                      url,
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.base),
                          child: Icon(Icons.broken_image_rounded, size: 36, color: AppColors.lightTextMuted),
                        ),
                      ),
                    )
                  : Image.asset(
                      url,
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.base),
                          child: Icon(Icons.broken_image_rounded, size: 36, color: AppColors.lightTextMuted),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.zoom_in_rounded, size: 16, color: isDark ? AppColors.darkIconMuted : AppColors.lightIconMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  AppStrings.tapToZoom,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeometryDiagramCard(BuildContext context) {
    final borderColor = isDark ? AppColors.lightTextSecondary : AppColors.lightBorder;

    return GestureDetector(
      onTap: () => _openZoomDialog(
        context,
        title: AppStrings.isHindi ? 'दिये गये चित्र में: OP || RS' : 'In the given figure: OP || RS',
        child: SizedBox(
          width: 320,
          height: 220,
          child: CustomPaint(
            painter: _UtetGeometryPainter(isDark: isDark),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.primary : AppColors.lightCard,
          borderRadius: AppRadius.roundedBase,
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryLight : AppColors.infoSurface,
                    borderRadius: AppRadius.roundedSm,
                  ),
                  child: Text(
                    AppStrings.isHindi
                        ? '📐 रेखागणित चित्र'
                        : '📐 Geometry figure',
                    style: AppTypography.labelSmall(
                      color: AppColors.violet,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.zoom_in_rounded, size: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      AppStrings.zoomLabel,
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: SizedBox(
                width: 300,
                height: 190,
                child: CustomPaint(
                  painter: _UtetGeometryPainter(isDark: isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openZoomDialog(BuildContext context, {required String title, required Widget child}) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedBase),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.titleSmall(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.roundedSm,
                  child: Container(
                    color: isDark ? AppColors.primaryDark : AppColors.darkTextPrimary,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(child: child),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.pinchToZoomHint,
                  style: AppTypography.labelSmall(
                    color: AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom vector painter for UTET 2022 Mathematics Q115
/// Problem: OP || RS, ∠OPQ = 100°, ∠QRS = 140°, ∠PQR = ?
class _UtetGeometryPainter extends CustomPainter {
  final bool isDark;

  const _UtetGeometryPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark ? AppColors.accentBright : AppColors.accent
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final auxPaint = Paint()
      ..color = isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final arcPaint = Paint()
      ..color = isDark ? AppColors.goldBright : AppColors.sealGoldLight
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final textStyle = AppTypography.labelMedium(
      color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
    );

    final angleTextStyle = AppTypography.labelSmall(
      color: isDark ? AppColors.goldBright : AppColors.sealGold,
    );

    // Coordinates:
    // P at (120, 45) -> O extends left to (30, 45)
    // Q at (180, 115)
    // R at (110, 155) -> S extends right to (270, 155)
    const pO = Offset(35, 40);
    const pP = Offset(135, 40);
    const pQ = Offset(195, 105);
    const pR = Offset(125, 155);
    const pS = Offset(265, 155);

    // 1. Draw Ray OP (with left arrow)
    canvas.drawLine(pO, pP, linePaint);
    _drawArrowHead(canvas, pP, pO, linePaint);

    // 2. Draw Segment PQ
    canvas.drawLine(pP, pQ, linePaint);

    // 3. Draw Segment QR
    canvas.drawLine(pQ, pR, linePaint);

    // 4. Draw Ray RS (with right arrow)
    canvas.drawLine(pR, pS, linePaint);
    _drawArrowHead(canvas, pR, pS, linePaint);

    // 5. Draw auxiliary dashed line through Q (QM || OP || RS)
    _drawDashedLine(canvas, const Offset(60, 105), const Offset(260, 105), auxPaint);

    // 6. Draw angle arcs
    // Arc at P for ∠OPQ = 100°
    canvas.drawArc(
      Rect.fromCircle(center: pP, radius: 20),
      math.pi,
      0.55 * math.pi,
      false,
      arcPaint,
    );
    _drawText(canvas, '100°', const Offset(95, 52), angleTextStyle);

    // Arc at R for ∠QRS = 140°
    canvas.drawArc(
      Rect.fromCircle(center: pR, radius: 22),
      -0.45 * math.pi,
      0.75 * math.pi,
      false,
      arcPaint,
    );
    _drawText(canvas, '140°', const Offset(142, 135), angleTextStyle);

    // Angle at Q (marked with ?)
    canvas.drawArc(
      Rect.fromCircle(center: pQ, radius: 18),
      0.85 * math.pi,
      0.7 * math.pi,
      false,
      arcPaint,
    );
    // The '?' mark is the emphasis of the diagram, so it keeps the heavier
    // weight of the drawing (the scale size is the titleSmall one).
    _drawText(
      canvas,
      '?',
      const Offset(168, 98),
      AppTypography.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: angleTextStyle.color,
      ),
    );
    // 7. Labels for points O, P, Q, R, S
    _drawText(canvas, 'O', const Offset(20, 32), textStyle);
    _drawText(canvas, 'P', const Offset(142, 24), textStyle);
    _drawText(canvas, 'Q', const Offset(204, 102), textStyle);
    _drawText(canvas, 'R', const Offset(105, 155), textStyle);
    _drawText(canvas, 'S', const Offset(272, 146), textStyle);
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dX = to.dx - from.dx;
    final dY = to.dy - from.dy;
    final angle = math.atan2(dY, dX);
    const arrowLen = 10.0;
    const arrowAngle = 25 * math.pi / 180;

    final p1 = Offset(
      to.dx - arrowLen * math.cos(angle - arrowAngle),
      to.dy - arrowLen * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      to.dx - arrowLen * math.cos(angle + arrowAngle),
      to.dy - arrowLen * math.sin(angle + arrowAngle),
    );

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final distance = (p2 - p1).distance;
    final unitVector = (p2 - p1) / distance;

    double currentDist = 0;
    while (currentDist < distance) {
      final start = p1 + unitVector * currentDist;
      final end = p1 + unitVector * math.min(currentDist + dashWidth, distance);
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _UtetGeometryPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Helper to render custom diagram cards with zooming
extension _MathDiagramCustomHelper on MathDiagramWidget {
  Widget _buildCustomDiagramCard(
    BuildContext context, {
    required String badgeText,
    required String title,
    required CustomPainter painter,
    required double width,
    required double height,
  }) {
    final borderColor = isDark ? AppColors.lightTextSecondary : AppColors.lightBorder;

    return GestureDetector(
      onTap: () => _openZoomDialog(
        context,
        title: title,
        child: SizedBox(
          width: width * 1.3,
          height: height * 1.3,
          child: CustomPaint(painter: painter),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.primary : AppColors.lightCard,
          borderRadius: AppRadius.roundedBase,
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryLight : AppColors.infoSurface,
                    borderRadius: AppRadius.roundedSm,
                  ),
                  child: Text(
                    badgeText,
                    style: AppTypography.labelSmall(
                      color: AppColors.violet,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.zoom_in_rounded,
                      size: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      AppStrings.zoomLabel,
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: SizedBox(
                width: width,
                height: height,
                child: CustomPaint(painter: painter),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1. Number Line Painter for CTET 2018 Math Q049
class _CtetNumberLinePainter extends CustomPainter {
  final bool isDark;
  _CtetNumberLinePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark ? AppColors.lightBorder : AppColors.primaryLight
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final tickPaint = Paint()
      ..color = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final accentPaint = Paint()
      ..color = AppColors.danger
      ..style = PaintingStyle.fill;

    final centerY = size.height * 0.52;
    const startX = 24.0;
    final endX = size.width - 24.0;

    // Draw main axis line
    canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), linePaint);

    // Left and Right arrows
    _drawArrow(canvas, Offset(startX + 12, centerY), Offset(startX, centerY), linePaint);
    _drawArrow(canvas, Offset(endX - 12, centerY), Offset(endX, centerY), linePaint);

    // 12 equidistant ticks from index 0 to 11
    const totalTicks = 12;
    final tickSpacing = (endX - startX - 32) / (totalTicks - 1);
    final firstTickX = startX + 16;

    final labelStyle = AppTypography.labelSmall(
      color: isDark ? AppColors.borderStrong : AppColors.primary,
    );

    // The point markers are the loudest thing on the number line.
    final pointLabelStyle = AppTypography.outfit(
      fontSize: 16,
      fontWeight: FontWeight.w900,
      color: AppColors.danger,
    );

    for (int i = 0; i < totalTicks; i++) {
      final x = firstTickX + i * tickSpacing;
      // Draw tick
      canvas.drawLine(Offset(x, centerY - 8), Offset(x, centerY + 8), tickPaint);

      if (i == 0) {
        // 25000
        _drawTextCentered(canvas, '25000', Offset(x, centerY + 18), labelStyle);
      } else if (i == 3) {
        // Point A
        canvas.drawCircle(Offset(x, centerY), 4.5, accentPaint);
        _drawTextCentered(canvas, 'A', Offset(x, centerY - 24), pointLabelStyle);
      } else if (i == 7) {
        // 39000
        _drawTextCentered(canvas, '39000', Offset(x, centerY + 18), labelStyle);
      } else if (i == 11) {
        // Point B
        canvas.drawCircle(Offset(x, centerY), 4.5, accentPaint);
        _drawTextCentered(canvas, 'B', Offset(x, centerY - 24), pointLabelStyle);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const arrowLen = 8.0;
    const arrowAngle = 25 * math.pi / 180;

    final p1 = Offset(
      to.dx - arrowLen * math.cos(angle - arrowAngle),
      to.dy - arrowLen * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      to.dx - arrowLen * math.cos(angle + arrowAngle),
      to.dy - arrowLen * math.sin(angle + arrowAngle),
    );

    canvas.drawLine(to, p1, paint);
    canvas.drawLine(to, p2, paint);
  }

  void _drawTextCentered(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CtetNumberLinePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// 2. 3D Triangular Prism Painter for UTET 2020 Math Q117
class _TriangularPrismPainter extends CustomPainter {
  final bool isDark;
  _TriangularPrismPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark ? AppColors.accentBright : AppColors.accent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final dashedPaint = Paint()
      ..color = isDark ? AppColors.lightTextMuted : AppColors.darkTextSecondary
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final faceFill = Paint()
      ..color = (isDark ? AppColors.accent : AppColors.accentBright)
          .withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Front triangle: A (top), B (bottom-left), C (bottom-right)
    final a = Offset(size.width * 0.32, size.height * 0.22);
    final b = Offset(size.width * 0.15, size.height * 0.78);
    final c = Offset(size.width * 0.52, size.height * 0.82);

    // Back triangle (shifted right and up): D, E, F
    final d = Offset(size.width * 0.75, size.height * 0.18);
    final e = Offset(size.width * 0.58, size.height * 0.74);
    final f = Offset(size.width * 0.92, size.height * 0.76);

    // Fill front and top faces
    final frontPath = Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy)..close();
    canvas.drawPath(frontPath, faceFill);

    final topPath = Path()..moveTo(a.dx, a.dy)..lineTo(d.dx, d.dy)..lineTo(f.dx, f.dy)..lineTo(c.dx, c.dy)..close();
    canvas.drawPath(topPath, faceFill);

    // Front triangle solid edges
    canvas.drawLine(a, b, linePaint);
    canvas.drawLine(b, c, linePaint);
    canvas.drawLine(c, a, linePaint);

    // Visible connecting edges
    canvas.drawLine(a, d, linePaint); // top spine
    canvas.drawLine(c, f, linePaint); // right bottom spine

    // Back triangle visible edges
    canvas.drawLine(d, f, linePaint);

    // Hidden edges (dashed): B -> E, E -> D, E -> F
    _drawDashed(canvas, b, e, dashedPaint);
    _drawDashed(canvas, e, d, dashedPaint);
    _drawDashed(canvas, e, f, dashedPaint);

    // Vertices dots
    final dotPaint = Paint()..color = AppColors.violet..style = PaintingStyle.fill;
    for (final pt in [a, b, c, d, e, f]) {
      canvas.drawCircle(pt, 3.5, dotPaint);
    }
  }

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final distance = (p2 - p1).distance;
    final unitVector = (p2 - p1) / distance;
    double currentDist = 0;
    while (currentDist < distance) {
      final start = p1 + unitVector * currentDist;
      final end = p1 + unitVector * math.min(currentDist + dashWidth, distance);
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TriangularPrismPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// 3. Shaded Fraction Painter for UTET 2022 Math Q098
class _ShadedFractionPainter extends CustomPainter {
  final bool isDark;
  _ShadedFractionPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = isDark ? AppColors.borderStrong : AppColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = isDark ? AppColors.lightTextMuted : AppColors.darkTextSecondary
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final shadedPaint = Paint()
      ..color = AppColors.violet.withValues(alpha: isDark ? 0.6 : 0.45)
      ..style = PaintingStyle.fill;

    const marginX = 20.0;
    const marginY = 16.0;
    final rectW = size.width - marginX * 2;
    final rectH = size.height - marginY * 2;
    final midY = marginY + rectH / 2;

    // Outer Rectangle
    final outerRect = Rect.fromLTWH(marginX, marginY, rectW, rectH);
    canvas.drawRect(outerRect, borderPaint);

    // Horizontal divider
    canvas.drawLine(Offset(marginX, midY), Offset(marginX + rectW, midY), borderPaint);

    // Top half: divided into 3 vertical columns (2 shaded)
    final colW3 = rectW / 3;
    // Shade first 2 columns
    canvas.drawRect(Rect.fromLTWH(marginX, marginY, colW3 * 2, rectH / 2), shadedPaint);
    // Draw grid lines
    canvas.drawLine(Offset(marginX + colW3, marginY), Offset(marginX + colW3, midY), gridPaint);
    canvas.drawLine(Offset(marginX + colW3 * 2, marginY), Offset(marginX + colW3 * 2, midY), gridPaint);

    // Bottom half: divided into 4 vertical columns (2 shaded)
    final colW4 = rectW / 4;
    // Shade first 2 columns
    canvas.drawRect(Rect.fromLTWH(marginX, midY, colW4 * 2, rectH / 2), shadedPaint);
    // Draw grid lines
    canvas.drawLine(Offset(marginX + colW4, midY), Offset(marginX + colW4, marginY + rectH), gridPaint);
    canvas.drawLine(Offset(marginX + colW4 * 2, midY), Offset(marginX + colW4 * 2, marginY + rectH), gridPaint);
    canvas.drawLine(Offset(marginX + colW4 * 3, midY), Offset(marginX + colW4 * 3, marginY + rectH), gridPaint);
  }

  @override
  bool shouldRepaint(covariant _ShadedFractionPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

