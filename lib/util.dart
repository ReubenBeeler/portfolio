import 'dart:math';

import 'package:flutter/foundation.dart';
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

extension CommonControls on AnimationController {
  void autoDispose(AnimatedState owner) {
    owner._controllers.add(this);
  }

  /// Overwrites this.duration with duration if non-null and then runs the animation from the beginning.
  TickerFuture start([Duration? duration]) {
    if (duration != null) this.duration = duration;
    reset();
    return forward();
  }
}

abstract class AnimatedState<T extends StatefulWidget> extends State<T> {
  final List<AnimationController> _controllers = [];

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
