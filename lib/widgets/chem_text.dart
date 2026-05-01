import 'package:flutter/material.dart';

/// Converts plain chemical notation to Unicode sub/superscripts and
/// renders it as a [RichText] with styled equation lines.
///
/// Examples:
///   "H2O"        → H₂O
///   "H2SO4"      → H₂SO₄
///   "Ca(OH)2"    → Ca(OH)₂
///   "Fe3+"       → Fe³⁺
///   "2H2 + O2 → 2H2O"  → 2H₂ + O₂ → 2H₂O
class ChemText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const ChemText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  // ── Unicode lookup tables ─────────────────────────────────────────────────
  static const _sub = {
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
  };
  static const _sup = {
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '+': '⁺',
    '-': '⁻',
  };

  // ── Core converter ─────────────────────────────────────────────────────────
  static String convert(String raw) {
    var s = raw;

    // 1. Ion charges: number+sign after element or closing paren, e.g. Fe3+, SO42-
    //    Must run BEFORE subscript pass so digits are still plain.
    s = s.replaceAllMapped(RegExp(r'([A-Za-z\)])(\d*)([+\-])'), (m) {
      final digits = m.group(2)!;
      final sign = m.group(3)!;
      // If digits present: they become superscript too (e.g. Fe3+)
      final supDigits = digits.split('').map((c) => _sup[c] ?? c).join();
      final supSign = _sup[sign] ?? sign;
      return '${m.group(1)}$supDigits$supSign';
    });

    // 2. Subscripts: digits immediately following an element symbol or ')'
    //    Pattern: (element or ')') followed by one or more digits
    s = s.replaceAllMapped(RegExp(r'([A-Z][a-z]?|\))(\d+)'), (m) {
      final sub = m.group(2)!.split('').map((c) => _sub[c] ?? c).join();
      return '${m.group(1)}$sub';
    });

    // 3. Replace plain ASCII arrow "->" and "→" with prettier arrow
    s = s.replaceAll('->', ' → ');
    // normalise double-space that might appear
    s = s.replaceAll('  ', ' ');

    return s;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;

    // Split into lines so each equation line can be styled differently
    final lines = convert(text).split('\n');

    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Detect equation lines (contain → or =)
      final isEquation = line.contains('→') || RegExp(r'\s=\s').hasMatch(line);
      if (isEquation) {
        spans.add(
          TextSpan(
            text: line,
            style: base.copyWith(
              fontFamily: 'monospace',
              color: const Color(0xFF1B5E20),
              fontWeight: FontWeight.w700,
              fontSize: (base.fontSize ?? 14) + 1,
              backgroundColor: const Color(0xFFE8F5E9),
              letterSpacing: 0.3,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: line, style: base));
      }
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(text: TextSpan(children: spans), textAlign: textAlign);
  }
}
