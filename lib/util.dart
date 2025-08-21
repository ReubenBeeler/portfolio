import 'package:flutter/material.dart';

Offset getGlobalOffset(GlobalKey key) {
  return (key.currentContext!.findRenderObject() as RenderBox).localToGlobal(Offset.zero);
}

T trim<T extends num>(T x, T lower, T upper) {
  if (x < lower) return lower;
  if (upper < x) return upper;
  return x;
}

Offset linterpolateOffset(Offset o0, Offset o1, num fraction) {
  return o0 + (o1 - o0) * fraction.toDouble();
}

double linterpolate(num x0, num x1, num fraction) {
  return (x0 + (x1 - x0) * fraction).toDouble();
}

// returns `a` for `fraction < 0`, linear interpolation between `a` and `b` for `0 <= fraction <= 1`, and `b` for `fraction < t`
Color linterpolateColor(Color c0, Color c1, num fraction) {
  fraction = trim(fraction, 0, 1);
  double a = linterpolate(c0.a, c1.a, fraction);
  double r = linterpolate(c0.r, c1.r, fraction);
  double g = linterpolate(c0.g, c1.g, fraction);
  double b = linterpolate(c0.b, c1.b, fraction);
  return Color.from(alpha: a, red: r, green: g, blue: b);
}
