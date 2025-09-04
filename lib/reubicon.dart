import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:portfolio/bootstrapper.dart';
import 'package:portfolio/util.dart';

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
  RESTORING, // restores size to that of default state
}

class ReubIcon extends StatefulWidget {
  final Widget child;
  final Color backgroundColor;

  const ReubIcon({super.key, required this.child, required this.backgroundColor});

  @override
  State<ReubIcon> createState() => _ReubIconState();
}

// class _ReubIconState extends State<ReubIcon> with TickerProviderStateMixin {
class _ReubIconState extends AnimatedState<ReubIcon> with TickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();

  // consolidate into _iconController and _circleController?
  late final AnimationController _openingController = AnimationController(vsync: this)..autoDispose(this);
  late final AnimationController _bouncingController = AnimationController(vsync: this)..autoDispose(this);
  late final AnimationController _restoringController = AnimationController(vsync: this)..autoDispose(this);

  CircleState _circleState = CircleState.DEFAULT;
  late double _beginRestoreIconFraction;
  late double _beginRestoreCircleFraction;
  late double _beginOpeningCircleFraction;

  IconState _iconState = IconState.DEFAULT;
  late Offset _beginDraggingOffset;
  late Offset _beginBouncingOffset;

  late Offset _parentGlobalPosition;
  //   late Offset _begin_parent_global_position;

  Offset? _centerGlobalPosition;
  late double _distFraction;
  final ValueNotifier<double> _circleFraction = ValueNotifier(1);
  final ValueNotifier<double> _iconFraction = ValueNotifier(1);
  final ValueNotifier<Offset> _iconOffset = ValueNotifier(Offset.zero);

  double _smoothenFraction(double fraction) {
    return pow(sin((fraction) * pi / 2), 2).toDouble(); // a little smoothing at the ends
  }

  void _updateCircleFraction() {
    switch (_circleState) {
      case CircleState.DEFAULT:
        _circleFraction.value = _distFraction;
      case CircleState.OPENING:
        _circleFraction.value = lerp(_beginOpeningCircleFraction, 0, _openingController.value);
      case CircleState.OPENED:
        _circleFraction.value = 0;
      case CircleState.RESTORING:
        _circleFraction.value = lerp(_beginRestoreCircleFraction, _distFraction, _restoringController.value);
    }
  }

  void _updateDistFraction() {
    if (_centerGlobalPosition == null) return;
    double dist = (mouseGlobalPosition.value - _centerGlobalPosition!).distance;
    _distFraction = clampDouble(dist / 300, 0, 1);
    _updateIconFraction();
    _updateCircleFraction();
  }

  void _updateIconFraction() {
    switch (_iconState) {
      case IconState.DEFAULT:
        _iconFraction.value = _distFraction;
      case IconState.RESTORING:
        _iconFraction.value = lerp(_beginRestoreIconFraction, _distFraction, _restoringController.value);
      default: // no change
    }
  }

  void _updateIconOffset() {
    switch (_iconState) {
      case IconState.DEFAULT:
        _iconOffset.value = Offset.zero;
      case IconState.DRAGGING:
        _iconOffset.value = mouseGlobalPosition.value - _beginDraggingOffset; // - (_parent_global_position - _begin_parent_global_position);
      case IconState.BOUNCING:
        _iconOffset.value = lerpOffset(_beginBouncingOffset, Offset.zero, const ConOscCurve(5, a: 3).transformInternal(_bouncingController.value));
      case IconState.RESTORING:
        _iconOffset.value = Offset.zero;
    }
  }

  Map<void Function(), List<Listenable>> listenMap = {};

  void addListener(void Function() listener, List<Listenable> listenables) {
    for (var listenable in listenables) {
      listenable.addListener(listener);
    }
    listenMap[listener] = listenables; // no copy
  }

  void removeListeners() {
    for (var entry in listenMap.entries) {
      for (var listenable in entry.value) {
        listenable.removeListener(entry.key);
      }
    }
    listenMap.clear();
  }

  @override
  void initState() {
    super.initState();

    addListener(_updateDistFraction, [mouseGlobalPosition]);
    addListener(_updateIconFraction, [_restoringController]);
    addListener(_updateCircleFraction, [_openingController, _restoringController]);
    addListener(_updateIconOffset, [_bouncingController]);
  }

  @override
  void dispose() {
    super.dispose();

    removeListeners();
  }

  void _onPanStart(DragStartDetails details) {
    _iconState = IconState.DRAGGING;
    _beginDraggingOffset = details.globalPosition;
    // _begin_parent_global_position = _parent_global_position = getGlobalOffset(_parentKey);

    _bouncingController.stop();
    _restoringController.stop(); // might already be stopped

    _circleState = CircleState.OPENING;
    _beginOpeningCircleFraction = _circleFraction.value;
    _openingController.start(const Duration(milliseconds: 500)).whenComplete(() => setState(() => _circleState = CircleState.OPENED));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _updateIconOffset(); // mouse position is in mouseGlobalPosition
  }

  void _onPanEnd(DragEndDetails details) {
    _beginBouncingOffset = _iconOffset.value;
    _iconState = IconState.BOUNCING;
    _bouncingController.start(const Duration(milliseconds: 1500)).whenComplete(() {
      _openingController.stop(); // should already be stopped because it's shorter than bounce animation
      _restoringController.reset();
      setState(() {
        _beginRestoreCircleFraction = _circleFraction.value;
        _beginRestoreIconFraction = _iconFraction.value;
        _circleState = CircleState.RESTORING;
        _iconState = IconState.RESTORING;
      });
      _restoringController.start(const Duration(milliseconds: 1000)).whenComplete(() {
        setState(() {
          _circleState == CircleState.DEFAULT;
          _iconState = IconState.DEFAULT;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // return NotificationListener<ScrollNotification>(
    //   onNotification: (scroll) {
    //     setState(() => _parent_global_position = getGlobalOffset(_parentKey));
    //     return false;
    //   },
    //   child: layout builder below
    // );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = size.center(Offset.zero);
        _centerGlobalPosition = (context.findRenderObject() as RenderBox).localToGlobal(center);
        _updateDistFraction();

        return Center(
          child: ValueListenableBuilder(
            valueListenable: _circleFraction,
            builder: (_, circFrac, icon) {
              num circFrac2 = _smoothenFraction(circFrac);

              double circScale = lerp(2.4, 1, circFrac2);
              Color circColor = widget.backgroundColor.withAlpha(lerp(0, 255, 1 - sqrt(1 - pow(circFrac2, 2))).round());

              double radius = 110 * circScale;

              bool doClip = [CircleState.DEFAULT, CircleState.RESTORING].contains(_circleState);
              return doClip
                  ? ClipOval(
                      clipper: CircleHoleClipper(center, radius),
                      child: Container(
                        color: circColor,
                        alignment: Alignment.center,
                        child: icon,
                      ),
                    )
                  : Stack(
                      alignment: AlignmentDirectional.center,
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: circColor,
                          radius: radius,
                        ),
                        icon!,
                      ],
                    );
            },
            child: ValueListenableBuilder(
              valueListenable: _iconOffset,
              // `Transform.translate` works instead of `Positioned` because we don't clip when we translate
              builder: (_, offset, child) => Transform.translate(
                key: _key,
                offset: offset,
                child: child,
              ),
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: _iconFraction,
                  builder: (_, iconFrac, child) => Transform.scale(
                    scale: lerp(1.3, 1, _smoothenFraction(iconFrac)),
                    child: child,
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
