import 'dart:math';

import 'package:flutter/material.dart';
import 'package:portfolio/bootstrapper.dart';
import 'package:portfolio/simple_animation.dart';
import 'package:portfolio/util.dart';
import 'package:url_launcher/url_launcher.dart';

enum CircleState {
  DEFAULT, // default state (directly correlated with mouse position)
  OPENING, // after dragging icon
  OPENED, // waiting for icon to be released
  RESTORING, // after releasing icon (restore to DEFAULT state)
}

enum IconState {
  DEFAULT, // default state (directly correlated with mouse position)
  DRAGGING, // follows mouse while dragging
  BOUNCING, // bounces back to DEFAULT location
}

class ReubIcon extends StatefulWidget {
  final String asset_path;
  final double square_size;
  final Color default_color;

  const ReubIcon({super.key, required this.asset_path, required this.square_size, required this.default_color});

  @override
  State<ReubIcon> createState() => _ReubIconState();
}

// class _ReubIconState extends State<ReubIcon> with TickerProviderStateMixin {
class _ReubIconState extends AnimatedState<ReubIcon> {
  final GlobalKey _parentKey = GlobalKey();
  final GlobalKey _childKey = GlobalKey();

  late double _iconFrac; // frozen when dragging icon
  late double _circFrac; // animates when dragging icon

  late SimpleAnimationController _bounceController;
  late SimpleAnimationController _restore_circleController;
  late SimpleAnimationController _open_circleController;

  CircleState _circle_state = CircleState.DEFAULT;
  late double _open_circle_frac;
  late double _restore_circle_frac;
  late double _begin_restore_circle_frac;

  IconState _icon_state = IconState.DEFAULT;
  late double _bounce_frac;
  late double _begin_icon_bounce_frac;
  late Offset _drag;
  late Offset _begin_drag_dragging;
  late Offset _begin_drag_bouncing;

  late Offset _parent_global_position;
  late Offset _begin_parent_global_position;

  @override
  List<AnimationController> create_controllers() {
    void bounce_update(frac) => setState(() {
      _icon_state = IconState.BOUNCING;
      _bounce_frac = frac;
    });
    void open_circle_update(frac) => setState(() {
      _circle_state = CircleState.OPENING;
      _open_circle_frac = frac;
    });
    void restore_circle_update(frac) => setState(() {
      _circle_state = CircleState.RESTORING;
      _restore_circle_frac = frac;
    });
    _bounceController = SimpleAnimationController(vsync: this, update: bounce_update);
    _open_circleController = SimpleAnimationController(vsync: this, update: open_circle_update);
    _restore_circleController = SimpleAnimationController(vsync: this, update: restore_circle_update);

    return [_bounceController, _open_circleController, _restore_circleController];
  }

  void _onPanStart(DragStartDetails details) {
    _icon_state = IconState.DRAGGING;
    _begin_drag_dragging = details.globalPosition;
    _begin_parent_global_position = _parent_global_position = getGlobalOffset(_parentKey);

    _bounceController.stop();
    _restore_circleController.stop(); // might already be stopped

    _open_circleController.run(const Duration(milliseconds: 500)).whenComplete(() => setState(() => _circle_state = CircleState.OPENED));

    setState(() {}); // just to prevent weirdness from not updating...
  }

  void _onPanEnd(DragEndDetails details) {
    _begin_icon_bounce_frac = _iconFrac;
    _begin_drag_bouncing = _drag;
    _bounceController.run(const Duration(milliseconds: 1500)).whenComplete(() {
      _icon_state = IconState.DEFAULT;
      _open_circleController.stop(); // should already be stopped because it's shorter than bounce animation
      _begin_restore_circle_frac = _circFrac;
      _restore_circleController.run(const Duration(milliseconds: 1000)).whenComplete(() => setState(() => _circle_state == CircleState.DEFAULT));
    });

    setState(() {}); // just to prevent weirdness from not updating...
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        setState(() => _parent_global_position = getGlobalOffset(_parentKey));
        return false;
      },
      child: SingleChildScrollView(
        // for testing scroll effects when dragging
        child: SizedBox(
          key: _parentKey,
          height: MediaQuery.of(context).size.height * 4 / 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ValueListenableBuilder<Offset>(
                valueListenable: mouseGlobalPosition,
                builder: (_, mouseGlobalPosition, _) {
                  final size = constraints.biggest;
                  final center = size.center(Offset.zero);
                  Offset centerGlobal = (context.findRenderObject() as RenderBox).localToGlobal(center);
                  double dist = (mouseGlobalPosition - centerGlobal).distance;
                  double distFrac = trim(dist / 300, 0, 1);

                  switch (_circle_state) {
                    case CircleState.DEFAULT:
                      _circFrac = distFrac;
                    case CircleState.OPENING:
                      _circFrac = linterpolate(_circFrac, 0, _open_circle_frac);
                    case CircleState.OPENED:
                      _circFrac = 0;
                    case CircleState.RESTORING:
                      _circFrac = linterpolate(_begin_restore_circle_frac, distFrac, _restore_circle_frac);
                  }

                  switch (_icon_state) {
                    case IconState.DEFAULT:
                      _iconFrac = distFrac;
                      _drag = Offset.zero;
                    case IconState.DRAGGING:
                      _iconFrac = _iconFrac; // freeze _iconFrac while dragging
                      _drag = mouseGlobalPosition - _begin_drag_dragging - (_parent_global_position - _begin_parent_global_position);
                    case IconState.BOUNCING:
                      _iconFrac = linterpolate(_begin_icon_bounce_frac, distFrac, _bounce_frac);
                      _drag = linterpolateOffset(_begin_drag_bouncing, Offset.zero, ConOscCurve(5, a: 3).transformInternal(_bounce_frac));
                  }

                  num iconFrac = pow(sin((_iconFrac) * pi / 2), 2); // a little smoothing at the ends
                  num circFrac = pow(sin((_circFrac) * pi / 2), 2); // a little smoothing at the ends

                  double iconScale = linterpolate(1.3, 1, iconFrac);
                  double circScale = linterpolate(2.4, 1, circFrac);
                  Color circColor = widget.default_color.withAlpha(linterpolate(0, 255, 1 - sqrt(1 - pow(circFrac, 2))).round());

                  double radius = 110 * circScale;

                  bool do_clip = [CircleState.DEFAULT, CircleState.RESTORING].contains(_circle_state);
                  List<Widget> extraStackWidgets = do_clip
                      ? []
                      : <Widget>[
                          // throw opaque circle into the stack (behind) if not using to clip
                          Align(
                            child: CircleAvatar(
                              backgroundColor: circColor,
                              radius: radius,
                            ),
                          ),
                        ];

                  Widget unclipped_widget = LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: <Widget>[
                        ...extraStackWidgets,
                        Positioned(
                          key: _childKey,
                          left: constraints.maxWidth / 2 - widget.square_size / 2 + _drag.dx,
                          top: constraints.maxHeight / 2 - widget.square_size / 2 + _drag.dy,
                          child: Transform.scale(
                            scale: iconScale,
                            child: GestureDetector(
                              onPanStart: _onPanStart,
                              // onPanUpdate: already listens to mouseGlobalPosition
                              onPanEnd: _onPanEnd,
                              onTap: () => launchUrl(Uri.parse("https://linkedin.com/in/ReubenBeeler/")),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Image.asset(widget.asset_path, width: widget.square_size, height: widget.square_size, filterQuality: FilterQuality.high),
                                // child: LayoutBuilder(
                                //   builder: (context, constraints) {
                                //     return Image.asset(widget.asset_path, width: widget.square_size, height: widget.square_size, filterQuality: FilterQuality.high);
                                //   },
                                // ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  return !do_clip
                      ? unclipped_widget
                      : ClipOval(
                          clipper: CircleHoleClipper(center, radius),
                          child: Container(
                            color: circColor,
                            alignment: Alignment.center,
                            child: unclipped_widget,
                          ),
                        );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class CircleHoleClipper extends CustomClipper<Rect> {
  final Offset center;
  final double radius;

  CircleHoleClipper(this.center, this.radius);

  @override
  Rect getClip(Size size) {
    return Rect.fromCircle(center: center, radius: radius);
  }

  @override
  bool shouldReclip(covariant CircleHoleClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}

/// Creates a curve for convergent oscillation toward the final destination. See https://www.desmos.com/calculator/hkwqeoh6gp.
class ConOscCurve extends Curve {
  final num a;
  final num n;

  double f(double x) => 1 - exp(-2 * a * x) * cos((pi / 2) * (2 * n - 1) * x);
  double s(double x) => x;
  double C(double x) => f(x) * (1 - s(x)) + s(x); // curve function

  /// `n` must be integer for it to stop smoothly (derivative --> 0) at destination. Damping coefficient `a` is recommended to be `0 <= a <= 1`
  ///
  /// Note: `n > 0.5`. `floor(n)` is the number of times it reaches/passes the destination before it stops. For example, `n=1` will go to the destination once and stop smoothly. `n=3` will go past the destination once, come back and pass again, and then come back a 3rd time and stop smoothly. `n=2.5` will go past the destination once, come back and pass again, then come back a 3rd time for a hard stop.
  const ConOscCurve(this.n, {this.a = 0});

  @override
  double transformInternal(double t) => C(t);
}
