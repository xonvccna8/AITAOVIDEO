import 'package:flutter/material.dart';

// ignore_for_file: constant_identifier_names

// ─────────────────────────────────────────────────────────────────────────────
// MathText — renders mixed Vietnamese text + LaTeX math with NO external package.
//
// Delimiters:  $$...$$ → centred display-math block
//              $...$   → inline math embedded in text
//
// LaTeX subset (covers Hệ thức lượng trong tam giác – Toán 10):
//   \frac{a}{b}           → visual fraction
//   \sqrt{x}              → √x with overline
//   x^{n}  /  x^n         → superscript
//   x_{n}  /  x_n         → subscript
//   \sin \cos \tan \cot   → upright text
//   \pi \alpha \beta \gamma \Delta \theta  → Unicode
//   \cdot \times \infty \leq \geq \neq \approx \pm  → Unicode
// ─────────────────────────────────────────────────────────────────────────────
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const MathText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  static final _outerRe = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        DefaultTextStyle.of(context).style.copyWith(fontSize: 15, height: 1.75);

    final segs = _splitOuter(text);
    if (segs.every((s) => s.kind == _Kind.text)) {
      return Text(text, style: base, textAlign: textAlign);
    }

    final rows = <Widget>[];
    var buf = <_Seg>[];

    void flush() {
      if (buf.isEmpty) return;
      rows.add(
        _InlineRow(segs: List.of(buf), baseStyle: base, textAlign: textAlign),
      );
      buf = [];
    }

    for (final s in segs) {
      if (s.kind == _Kind.display) {
        flush();
        rows.add(_DisplayBlock(latex: s.content, baseStyle: base));
      } else {
        buf.add(s);
      }
    }
    flush();

    if (rows.length == 1) return rows.first;
    return Column(
      crossAxisAlignment:
          textAlign == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  static List<_Seg> _splitOuter(String s) {
    final out = <_Seg>[];
    int cursor = 0;
    for (final m in _outerRe.allMatches(s)) {
      if (m.start > cursor) {
        out.add(_Seg(_Kind.text, s.substring(cursor, m.start)));
      }
      if (m.group(1) != null) {
        out.add(_Seg(_Kind.display, m.group(1)!.trim()));
      } else {
        out.add(_Seg(_Kind.inline, m.group(2)!.trim()));
      }
      cursor = m.end;
    }
    if (cursor < s.length) out.add(_Seg(_Kind.text, s.substring(cursor)));
    return out;
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

enum _Kind { text, inline, display }

class _Seg {
  final _Kind kind;
  final String content;
  const _Seg(this.kind, this.content);
}

// ── Inline row ────────────────────────────────────────────────────────────────

class _InlineRow extends StatelessWidget {
  final List<_Seg> segs;
  final TextStyle baseStyle;
  final TextAlign textAlign;
  const _InlineRow({
    required this.segs,
    required this.baseStyle,
    required this.textAlign,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    for (final seg in segs) {
      if (seg.kind == _Kind.text) {
        spans.add(TextSpan(text: seg.content));
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: _LatexWidget(latex: seg.content, baseStyle: baseStyle),
            ),
          ),
        );
      }
    }
    return RichText(
      textAlign: textAlign,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

// ── Display block ─────────────────────────────────────────────────────────────

class _DisplayBlock extends StatelessWidget {
  final String latex;
  final TextStyle baseStyle;
  const _DisplayBlock({
    required this.latex,
    required this.baseStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fs = (baseStyle.fontSize ?? 15) + 2;
    final bigStyle = baseStyle.copyWith(fontSize: fs);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(child: _LatexWidget(latex: latex, baseStyle: bigStyle)),
      ),
    );
  }
}

// ── Top-level LaTeX widget ────────────────────────────────────────────────────

class _LatexWidget extends StatelessWidget {
  final String latex;
  final TextStyle baseStyle;
  const _LatexWidget({required this.latex, required this.baseStyle, super.key});

  @override
  Widget build(BuildContext context) {
    final nodes = _LatexParser(latex).parse();
    return _renderRow(nodes, baseStyle);
  }

  static Widget _renderRow(List<_LNode> ns, TextStyle style) {
    if (ns.isEmpty) return const SizedBox.shrink();
    final items = ns.map((n) => _renderNode(n, style)).toList();
    if (items.length == 1) return items.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: items,
    );
  }

  static Widget _renderNode(_LNode n, TextStyle style) {
    final fs = style.fontSize ?? 15;
    final color = style.color ?? Colors.black87;

    if (n is _LText) return Text(n.text, style: style.copyWith(height: 1.0));

    if (n is _LFrac) {
      final sm = style.copyWith(fontSize: fs * 0.82, height: 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _renderRow(n.num, sm),
              Container(
                height: 1.0,
                color: color,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
              ),
              _renderRow(n.den, sm),
            ],
          ),
        ),
      );
    }

    if (n is _LSqrt) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('√', style: style.copyWith(height: 1.0, fontSize: fs * 1.1)),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: color, width: 1.0)),
            ),
            padding: const EdgeInsets.only(left: 1, right: 2, top: 1),
            child: _renderRow(n.arg, style.copyWith(height: 1.0)),
          ),
        ],
      );
    }

    if (n is _LSup) {
      final expStyle = style.copyWith(fontSize: fs * 0.72, height: 1.0);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _renderRow(n.base, style.copyWith(height: 1.0)),
          Transform.translate(
            offset: Offset(0, -(fs * 0.18)),
            child: _renderRow(n.exp, expStyle),
          ),
        ],
      );
    }

    if (n is _LSub) {
      final subStyle = style.copyWith(fontSize: fs * 0.72, height: 1.0);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _renderRow(n.base, style.copyWith(height: 1.0)),
          Transform.translate(
            offset: Offset(0, fs * 0.18),
            child: _renderRow(n.sub, subStyle),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ── LaTeX AST nodes ───────────────────────────────────────────────────────────

abstract class _LNode {}

class _LText extends _LNode {
  final String text;
  _LText(this.text);
}

class _LFrac extends _LNode {
  final List<_LNode> num;
  final List<_LNode> den;
  _LFrac(this.num, this.den);
}

class _LSqrt extends _LNode {
  final List<_LNode> arg;
  _LSqrt(this.arg);
}

class _LSup extends _LNode {
  final List<_LNode> base;
  final List<_LNode> exp;
  _LSup(this.base, this.exp);
}

class _LSub extends _LNode {
  final List<_LNode> base;
  final List<_LNode> sub;
  _LSub(this.base, this.sub);
}

// ── LaTeX Parser ──────────────────────────────────────────────────────────────

class _LatexParser {
  final String src;
  int _pos = 0;

  _LatexParser(this.src);

  static const _symbols = <String, String>{
    r'\pi': 'π',
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\delta': 'δ',
    r'\Delta': 'Δ',
    r'\theta': 'θ',
    r'\phi': 'φ',
    r'\Phi': 'Φ',
    r'\psi': 'ψ',
    r'\omega': 'ω',
    r'\Omega': 'Ω',
    r'\lambda': 'λ',
    r'\mu': 'μ',
    r'\sigma': 'σ',
    r'\rho': 'ρ',
    r'\cdot': '·',
    r'\times': '×',
    r'\div': '÷',
    r'\infty': '∞',
    r'\leq': '≤',
    r'\geq': '≥',
    r'\neq': '≠',
    r'\approx': '≈',
    r'\ldots': '…',
    r'\dots': '…',
    r'\pm': '±',
    r'\mp': '∓',
    r'\quad': '\u2003',
    r'\,': '\u2009',
    r'\sin': 'sin ',
    r'\cos': 'cos ',
    r'\tan': 'tan ',
    r'\cot': 'cot ',
    r'\sec': 'sec ',
    r'\csc': 'csc ',
    r'\log': 'log ',
    r'\ln': 'ln ',
    r'\lim': 'lim',
    r'\max': 'max',
    r'\min': 'min',
  };

  List<_LNode> parse() => _parseSeq();

  List<_LNode> _parseSeq({bool stopAtBrace = false}) {
    final nodes = <_LNode>[];
    while (_pos < src.length) {
      final ch = src[_pos];
      if (stopAtBrace && ch == '}') break;

      if (ch == '{') {
        _pos++;
        final inner = _parseSeq(stopAtBrace: true);
        if (_pos < src.length && src[_pos] == '}') _pos++;
        nodes.addAll(inner);
      } else if (ch == '\\') {
        final node = _parseCommand();
        if (node != null) nodes.add(node);
      } else if (ch == '^') {
        _pos++;
        final expNodes = _parseSingleArg();
        final base =
            nodes.isNotEmpty ? [nodes.removeLast()] : <_LNode>[_LText('')];
        nodes.add(_LSup(base, expNodes));
      } else if (ch == '_') {
        _pos++;
        final subNodes = _parseSingleArg();
        final base =
            nodes.isNotEmpty ? [nodes.removeLast()] : <_LNode>[_LText('')];
        nodes.add(_LSub(base, subNodes));
      } else if (ch == ' ') {
        nodes.add(_LText(' '));
        _pos++;
      } else {
        nodes.add(_LText(ch));
        _pos++;
      }
    }
    return _merge(nodes);
  }

  _LNode? _parseCommand() {
    _pos++; // consume '\'
    if (_pos >= src.length) return _LText(r'\');

    final start = _pos;
    if (RegExp(r'[a-zA-Z]').hasMatch(src[_pos])) {
      while (_pos < src.length && RegExp(r'[a-zA-Z*]').hasMatch(src[_pos])) {
        _pos++;
      }
    } else {
      _pos++;
    }
    final cmd = '\\${src.substring(start, _pos)}';
    _skipSpaces();

    if (cmd == r'\frac') {
      final num = _parseBraceArg();
      final den = _parseBraceArg();
      return _LFrac(num, den);
    }
    if (cmd == r'\sqrt') {
      if (_pos < src.length && src[_pos] == '[') {
        while (_pos < src.length && src[_pos] != ']') _pos++;
        if (_pos < src.length) _pos++;
      }
      return _LSqrt(_parseBraceArg());
    }
    if (cmd == r'\left' || cmd == r'\right') {
      if (_pos < src.length) _pos++; // skip bracket char
      return null;
    }
    if (_symbols.containsKey(cmd)) return _LText(_symbols[cmd]!);
    return _LText(src.substring(start, _pos)); // unknown: show raw name
  }

  List<_LNode> _parseBraceArg() {
    _skipSpaces();
    if (_pos < src.length && src[_pos] == '{') {
      _pos++;
      final inner = _parseSeq(stopAtBrace: true);
      if (_pos < src.length && src[_pos] == '}') _pos++;
      return inner;
    }
    if (_pos < src.length) return [_LText(src[_pos++])];
    return [];
  }

  List<_LNode> _parseSingleArg() {
    _skipSpaces();
    if (_pos < src.length && src[_pos] == '{') return _parseBraceArg();
    if (_pos < src.length) {
      if (src[_pos] == '\\') {
        final node = _parseCommand();
        return node != null ? [node] : [];
      }
      return [_LText(src[_pos++])];
    }
    return [];
  }

  void _skipSpaces() {
    while (_pos < src.length && src[_pos] == ' ') _pos++;
  }

  List<_LNode> _merge(List<_LNode> nodes) {
    final out = <_LNode>[];
    final buf = StringBuffer();
    for (final n in nodes) {
      if (n is _LText) {
        buf.write(n.text);
      } else {
        if (buf.isNotEmpty) {
          out.add(_LText(buf.toString()));
          buf.clear();
        }
        out.add(n);
      }
    }
    if (buf.isNotEmpty) out.add(_LText(buf.toString()));
    return out;
  }
}
