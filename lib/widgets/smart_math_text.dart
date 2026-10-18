import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders text with seamless support for inline and block LaTeX mathematical equations.
/// If math is present (e.g. `$...$` or `$$...$$` or raw LaTeX like `\sqrt`, `\dfrac`, `\frac`),
/// it parses and renders math native typography using [flutter_math_fork].
/// For normal text, it renders standard Flutter typography with zero extra overhead.
class SmartMathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const SmartMathText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  static final RegExp _mathDelimiterRegex = RegExp(
    r'\$\$(.*?)\$\$|\$((?!\$)[^\n]+?)\$',
    dotAll: true,
  );

  static final RegExp _rawLatexRegex = RegExp(
    r'(\\(?:dfrac|frac|sqrt|left|right|times|div|pm|degree|alpha|beta|pi|ldots|theta|le|ge|neq|approx|sum|prod|int)\b[^\s,।;\n]*)',
  );

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;

    // Fast path: text does not have '$' or backslash LaTeX commands
    if (!text.contains(r'$') && !text.contains(r'\')) {
      return Text(
        text,
        style: effectiveStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = _buildSpans(text, effectiveStyle);

    return Text.rich(
      TextSpan(children: spans),
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<InlineSpan> _buildSpans(String input, TextStyle baseStyle) {
    final spans = <InlineSpan>[];

    // Check if delimited math exists ($...$ or $$...$$)
    if (_mathDelimiterRegex.hasMatch(input)) {
      int lastIndex = 0;
      for (final match in _mathDelimiterRegex.allMatches(input)) {
        if (match.start > lastIndex) {
          final plain = input.substring(lastIndex, match.start);
          spans.add(TextSpan(text: plain, style: baseStyle));
        }

        final isDisplay = match.group(1) != null;
        final rawMath = (isDisplay ? match.group(1) : match.group(2))?.trim() ?? '';

        if (rawMath.isNotEmpty) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Math.tex(
                  rawMath,
                  mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
                  textStyle: baseStyle,
                  onErrorFallback: (err) => Text(
                    rawMath,
                    style: baseStyle.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          );
        }

        lastIndex = match.end;
      }

      if (lastIndex < input.length) {
        final remaining = input.substring(lastIndex);
        spans.add(TextSpan(text: remaining, style: baseStyle));
      }

      return spans;
    }

    // Secondary check: raw LaTeX commands without dollar signs (e.g. `\dfrac{a}{b}`)
    if (_rawLatexRegex.hasMatch(input)) {
      int lastIndex = 0;
      for (final match in _rawLatexRegex.allMatches(input)) {
        if (match.start > lastIndex) {
          final plain = input.substring(lastIndex, match.start);
          spans.add(TextSpan(text: plain, style: baseStyle));
        }

        final rawMath = match.group(1)?.trim() ?? '';
        if (rawMath.isNotEmpty) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Math.tex(
                  rawMath,
                  mathStyle: MathStyle.text,
                  textStyle: baseStyle,
                  onErrorFallback: (err) => Text(rawMath, style: baseStyle),
                ),
              ),
            ),
          );
        }

        lastIndex = match.end;
      }

      if (lastIndex < input.length) {
        final remaining = input.substring(lastIndex);
        spans.add(TextSpan(text: remaining, style: baseStyle));
      }

      return spans;
    }

    // Default fallback
    spans.add(TextSpan(text: input, style: baseStyle));
    return spans;
  }
}
