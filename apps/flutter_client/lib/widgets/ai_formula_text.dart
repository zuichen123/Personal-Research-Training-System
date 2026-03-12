import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class AIFormulaText extends StatelessWidget {
  const AIFormulaText(
    this.text, {
    super.key,
    this.style,
    this.selectable = false,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle? style;
  final bool selectable;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  static final RegExp _formulaPattern = RegExp(
    r'(\\\[(.*?)\\\]|\\\((.*?)\\\)|(?<!\\)\$\$(.*?)(?<!\\)\$\$|(?<!\\)\$(.+?)(?<!\\)\$)',
    dotAll: true,
  );

  @override
  Widget build(BuildContext context) {
    final normalized = text.trimRight();
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!_mayContainFormula(normalized)) {
      final plainText = _unescapePlain(normalized);
      if (selectable) {
        return SelectableText(
          plainText,
          style: effectiveStyle,
          textAlign: textAlign,
          maxLines: maxLines,
        );
      }
      return Text(
        plainText,
        style: effectiveStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = _buildSpans(normalized, effectiveStyle, context);
    final richText = RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: true,
      text: TextSpan(style: effectiveStyle, children: spans),
    );

    if (!selectable) {
      return richText;
    }
    return SelectionArea(child: richText);
  }

  bool _mayContainFormula(String input) {
    return input.contains(r'$') ||
        input.contains(r'\(') ||
        input.contains(r'\[');
  }

  List<InlineSpan> _buildSpans(
    String input,
    TextStyle baseStyle,
    BuildContext context,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _formulaPattern.allMatches(input)) {
      if (match.start > cursor) {
        final plain = _unescapePlain(input.substring(cursor, match.start));
        if (plain.isNotEmpty) {
          spans.add(TextSpan(text: plain));
        }
      }

      final token = match.group(0) ?? '';
      final parsed = _parseFormulaToken(token);
      if (parsed == null || parsed.expression.trim().isEmpty) {
        spans.add(TextSpan(text: _unescapePlain(token)));
      } else {
        final math = Math.tex(
          parsed.expression.trim(),
          mathStyle: parsed.display ? MathStyle.display : MathStyle.text,
          textStyle: baseStyle,
          onErrorFallback: (error) => Text(
            _unescapePlain(token),
            style: baseStyle.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        );
        if (parsed.display) {
          spans.add(const TextSpan(text: '\n'));
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Center(child: math),
              ),
            ),
          );
          spans.add(const TextSpan(text: '\n'));
        } else {
          spans.add(
            WidgetSpan(alignment: PlaceholderAlignment.middle, child: math),
          );
        }
      }

      cursor = match.end;
    }

    if (cursor < input.length) {
      final plain = _unescapePlain(input.substring(cursor));
      if (plain.isNotEmpty) {
        spans.add(TextSpan(text: plain));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: _unescapePlain(input)));
    }
    return spans;
  }

  String _unescapePlain(String raw) {
    return raw
        .replaceAll(r'\$', r'$')
        .replaceAll(r'\\(', r'\(')
        .replaceAll(r'\\)', r'\)')
        .replaceAll(r'\\[', r'\[')
        .replaceAll(r'\\]', r'\]');
  }

  _FormulaToken? _parseFormulaToken(String token) {
    if (token.startsWith(r'$$') && token.endsWith(r'$$') && token.length >= 4) {
      return _FormulaToken(
        expression: token.substring(2, token.length - 2),
        display: true,
      );
    }
    if (token.startsWith(r'\[') && token.endsWith(r'\]') && token.length >= 4) {
      return _FormulaToken(
        expression: token.substring(2, token.length - 2),
        display: true,
      );
    }
    if (token.startsWith(r'\(') && token.endsWith(r'\)') && token.length >= 4) {
      return _FormulaToken(
        expression: token.substring(2, token.length - 2),
        display: false,
      );
    }
    if (token.startsWith(r'$') && token.endsWith(r'$') && token.length >= 2) {
      return _FormulaToken(
        expression: token.substring(1, token.length - 1),
        display: false,
      );
    }
    return null;
  }
}

class _FormulaToken {
  const _FormulaToken({required this.expression, required this.display});

  final String expression;
  final bool display;
}
