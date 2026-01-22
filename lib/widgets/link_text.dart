import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LinkText extends StatelessWidget {
  final List line;
  final TextStyle? style;
  final TextStyle hyperlinkStyle;
  const LinkText({
    super.key,
    required this.line,
    this.style,
    this.hyperlinkStyle = const TextStyle(
      inherit: true,
      color: Colors.blue,
      decoration: TextDecoration.underline,
      decorationColor: Colors.blue,
    ),
  });

  @override
  Widget build(BuildContext context) {
    for (var e in line) {
      assert(e is String || e is VoidCallback, 'linkText `List line` argument should only contain `String`s or `VoidCallback`s');
    }
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          for (int j = 0; j < line.length; ++j)
            () {
              var current = line[j];
              assert(current is String, 'linkText `List line` elements must be String (with each String optionally followed by a VoidCallback)');
              String string = line[j];
              dynamic next = (j + 1 < line.length) ? line[j + 1] : null;
              TextSpan ret = TextSpan(
                text: string,
                recognizer: next is VoidCallback ? (TapGestureRecognizer()..onTap = next) : null,
                style: next is VoidCallback ? hyperlinkStyle : null,
              );
              if (next is VoidCallback) ++j;
              return ret;
            }(),
        ],
      ),
    );
  }
}

extension SizeOrNull on RenderBox {
  Size? get sizeOrNull {
    if (!hasSize) return null;
    try {
      return size;
    } catch (_) {
      return null;
    }
  }
}
