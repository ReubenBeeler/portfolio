import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';

Offset getGlobalOffset(GlobalKey key) {
  return (key.currentContext!.findRenderObject() as RenderBox).localToGlobal(Offset.zero);
}

double lerp(num x0, num x1, num fraction) {
  return (x0 + (x1 - x0) * fraction).toDouble();
}

Offset lerpOffset(Offset o0, Offset o1, num fraction) {
  return o0 + (o1 - o0) * fraction.toDouble();
}

/// Measures text size of `text`, using `String? data, TextStyle? style, TextDirection? textDirection` from `text.
/// The other arguments to this function override the corresponding values in `text`.
Size measureTextSize({Text? text, String? data, TextStyle? style, TextDirection? textDirection}) {
  data ??= text?.data;
  style ??= text?.style;
  textDirection ??= text?.textDirection;
  if ([data, style, textDirection].contains(null)) {
    throw Exception("can only measure text if data, style, and textDirection are all non-null");
  }
  final tp = TextPainter(
    text: TextSpan(text: data, style: style),
    textDirection: textDirection, // required
  )..layout(); // performs the measurement

  return tp.size; // includes width & height
}

/// Creates a curve for convergent oscillation toward the final destination. See https://www.desmos.com/calculator/hkwqeoh6gp.
class ConOscCurve extends Curve {
  final num a;
  final num n;

  double f(double t) => 1 - exp(-2 * a * t) * cos((pi / 2) * (2 * n - 1) * t);
  double s(double t) => t;
  double C(double t) => f(_tMap(t)) * (1 - s(t)) + s(t); // curve function

  final double Function(double t)? tMap;
  double _tMap(double t) => tMap?.call(t) ?? t;

  /// `n` must be integer for it to stop smoothly (derivative --> 0) at destination. Damping coefficient `a` is recommended to be `0 <= a <= 1`
  ///
  /// Note: `n > 0.5`. `floor(n)` is the number of times it reaches/passes the destination before it stops. For example, `n=1` will go to the destination once and stop smoothly. `n=3` will go past the destination once, come back and pass again, and then come back a 3rd time and stop smoothly. `n=2.5` will go past the destination once, come back and pass again, then come back a 3rd time for a hard stop.
  const ConOscCurve(this.n, {this.a = 0, this.tMap});

  @override
  double transformInternal(double t) => C(t);
}

/// aka `L*`, see https://stackoverflow.com/questions/596216/formula-to-determine-perceived-brightness-of-rgb-color
extension PerceivedLightness on Color {
  double computePerceivedLightness() {
    final double Y = computeLuminance();
    return Y <= (216 / 24389) ? Y * (24389 / 27) : pow(Y, (1 / 3)) * 116 - 16;
  }
}

extension AddValueListener<T> on ValueListenable<T> {
  void Function() addValueListener(void Function(T t) valueListener) {
    void listener() => valueListener(value);
    addListener(listener);
    return listener; // for removing in case that's desired
  }
}

extension AutoDisposeChangeNotifier on ChangeNotifier {
  void autoDispose(AnimatedState owner) {
    owner.runOnDispose(dispose);
  }
}

extension CommonControls on AnimationController {
  void autoDispose(AnimatedState owner) {
    owner.runOnDispose(dispose);
  }

  /// Overwrites this.duration with duration if non-null and then runs the animation from the beginning.
  TickerFuture restart([Duration? duration]) {
    if (duration != null) this.duration = duration;
    reset();
    return forward();
  }
}

abstract class AnimatedState<T extends StatefulWidget> extends State<T> implements TickerProvider {
  bool _initialized = false;
  bool _disposed = false;
  final List<void Function()> _onInitStateCallbacks = [];
  final List<void Function()> _onDisposeCallbacks = [];

  void runWhenInitialized(void Function() callback) {
    if (!_initialized) {
      _onInitStateCallbacks.add(callback);
    } else if (!_disposed) {
      callback();
    }
  }

  void runOnDispose(void Function() callback) {
    if (!_disposed) {
      _onDisposeCallbacks.add(callback);
    }
  }

  @override
  void initState() {
    super.initState();
    for (void Function() callback in _onInitStateCallbacks) {
      callback();
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _disposed = true;
    for (void Function() callback in _onDisposeCallbacks) {
      callback();
    }
    super.dispose();
  }
}

Widget getDraggable(Widget icon) {
  assert(icon.key is GlobalKey, "icon.key must be a Globalkey");
  return Draggable(
    feedback: MouseRegion(
      cursor: SystemMouseCursors.grabbing, // TODO so fucking stupid... find a way to make this work
      child: Builder(
        builder: (_) => SizedBox.fromSize(
          size: ((icon.key as GlobalKey).currentContext!.findRenderObject() as RenderBox).size,
          child: icon,
        ),
      ),
    ),
    childWhenDragging: const SizedBox.shrink(),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: icon,
    ),
  );
}

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

double? getTopFromRenderBox(GlobalKey key) {
  RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
  return box != null && box.hasSize ? box.localToGlobal(Offset.zero).dy : null;
}

double? getBottomFromRenderBox(GlobalKey key) {
  RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
  return box != null && box.hasSize ? box.localToGlobal(Offset(0, box.size.height)).dy : null;
}
