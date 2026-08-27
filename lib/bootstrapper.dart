import 'dart:async';
import 'dart:math';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

import 'util/boot_trace.dart';
import 'util/miscellaneous.dart';
import 'util/state_machine.dart';

late ValueNotifier<Offset> mouseGlobalPosition;
bool _setMouseGlobalPosition = false;

enum BootState {
  // FADE_IN_SPLASH,
  SPLASH,
  FLY_IN(FlyingWhere.IN),
  WAITING(FlyingWhere.CENTER),
  WAITING_FOR_MOUSE(FlyingWhere.CENTER),
  FLY_OUT((FlyingWhere.OUT)),
  FADE_IN_CHILD,
  BOOTED;

  final FlyingWhere? flyingWhere;

  const BootState([this.flyingWhere]);
}

class Bootstrapper extends StatefulWidget {
  final Future Function(BuildContext)? precache;
  final Widget? Function()? child;
  final Color foregroundColor;
  final Color backgroundColor;

  const Bootstrapper({super.key, this.precache, this.child, this.foregroundColor = Colors.white, this.backgroundColor = Colors.black});

  @override
  State<Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends AnimatedState<Bootstrapper> with TickerProviderStateMixin {
  late final AnimationController _flyInController = AnimationController(vsync: this)..autoDispose(this);
  late final AnimationController _waitingController = AnimationController(vsync: this)..autoDispose(this);
  late final AnimationController _flyOutController = AnimationController(vsync: this)..autoDispose(this);
  late final AnimationController _fadeInChildController = AnimationController(vsync: this)..autoDispose(this);
  late final AnimationController _clickTextFadeController = AnimationController(vsync: this)..autoDispose(this);

  // RepaintBoundary: without it, the fade-in overlay repaints the entire home page every frame.
  late final Widget? _child = switch (widget.child?.call()) {
    null => null,
    final child => RepaintBoundary(child: child),
  }; // only call once

  bool _firstFrameDone = false;
  bool _mountChild = false; // child is built (offscreen) before any animation starts
  bool _childLaidOut = false;
  bool _fontsReady = false;
  bool _flyInDone = false;
  // bool _waitedMinimum = false;
  bool _childReady = false;
  bool _mouseReady = false;
  bool _flyOutDone = false;
  bool _fadeInChild = false;
  bool _fadeStarted = false;

  static const Duration _kFlyInDuration = Duration(milliseconds: 1300);
  static const Duration _kFlyOutDuration = Duration(milliseconds: 1300);
  static const Duration _kFadeDuration = Duration(seconds: 1);

  /// How far through FLY_OUT the home page starts fading up, so the two
  /// animations overlap instead of running back to back. The assets are ready
  /// long before this point, so the back-to-back version was ~700ms of pure
  /// waiting. Raise it to keep the letters clear of the page for longer, lower
  /// it to hand over sooner.
  static const double _kFadeOverlap = 0.5;

  late final _stateMachine =
      StateMachine(BootState.SPLASH, {
          BootState.SPLASH: () => _firstFrameDone && _fontsReady ? BootState.FLY_IN : null,
          BootState.FLY_IN: () => _flyInDone ? BootState.WAITING : null,
          // BootState.WAITING: () {
          //   // timerDone represents minimum time here
          //   if (_waitedMinimum && cacheReady) {
          //     if (!_mouseReady) return BootState.WAITING_FOR_MOUSE;
          //     return BootState.FLY_OUT;
          //   }
          // },
          BootState.WAITING: () => _childReady && _childLaidOut ? BootState.FLY_OUT : null,
          // BootState.WAITING_FOR_MOUSE: () => _mouseReady ? BootState.FLY_OUT : null,
          BootState.FLY_OUT: () => _flyOutDone ? BootState.FADE_IN_CHILD : null,
          BootState.FADE_IN_CHILD: () => _fadeInChild ? BootState.BOOTED : null,
        })
        ..addListener(() => reportBootPhase(state.name))
        ..addListener(_stateMachineListener)
        ..addListener(() => setState(() {}));

  BootState get state => _stateMachine.value;

  void _stateMachineListener() {
    void controllerRestart(AnimationController controller, Duration duration, VoidCallback callback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // wait to start the animation after 1st frame to prevent from UI jank
        controller.restart(duration).whenComplete(() {
          callback();
          _stateMachine.update();
        });
      });
    }

    // TODO after all that, go back to trying just a fade-in...

    switch (state) {
      case BootState.FLY_IN:
        controllerRestart(_flyInController, _kFlyInDuration, () => _flyInDone = true);
      case BootState.WAITING:
        // Building + laying out the whole home page costs one very long frame.
        // Spend it here: the letters are parked in the centre, the child is
        // hidden, and every precached image is already decoded so the layout
        // settles in one pass instead of thrashing as images trickle in.
        _maybeMountChild();
        if (_childReady) _stateMachine.update(); // just in case cache was already loaded
      //   controllerRestart(const Duration(milliseconds: 500), () => _waitedMinimum = true);
      // case BootState.WAITING_FOR_MOUSE:
      //   _clickTextFadeController.restart(const Duration(seconds: 1));
      //   Future.delayed(const Duration(milliseconds: 125)).whenComplete(() {
      //     if (state == BootState.WAITING_FOR_MOUSE) {
      //       web.document.body?.style.cursor = 'pointer'; // MouseRegion doesn't automatically update this if the mouse hasn't interacted with the app yet
      //       _waitingMouseClickCursor.value = SystemMouseCursors.click; // forces MouseRegion to re-render with updated mouse
      //     }
      //   });
      case BootState.FLY_OUT:
        controllerRestart(_flyOutController, _kFlyOutDuration, () => _flyOutDone = true);
        _armFadeOverlap();
      case BootState.FADE_IN_CHILD:
        // Normally already running: the overlap starts it partway through
        // FLY_OUT. This only fires it if the overlap somehow did not.
        _beginFadeIn();
        if (_fadeInChild) _stateMachine.update();
      case _:
    }
  }

  /// Starts the fade once FLY_OUT is [_kFadeOverlap] of the way through, so the
  /// home page is already coming up behind the departing letters.
  void _armFadeOverlap() {
    void listener() {
      if (_flyOutController.value >= _kFadeOverlap) {
        _flyOutController.removeListener(listener);
        _beginFadeIn();
      }
    }

    _flyOutController.addListener(listener);
  }

  void _beginFadeIn() {
    if (_fadeStarted) return;
    setState(() => _fadeStarted = true);
    _fadeInChildController.restart(_kFadeDuration).whenComplete(() {
      _fadeInChild = true;
      _stateMachine.update();
    });
  }

  /// Mounts the (still invisible) child once we are parked in WAITING with every
  /// asset already precached, then lets WAITING -> FLY_OUT wait one frame for it
  /// to lay out. Mounting earlier would drag that layout into the fly-in.
  void _maybeMountChild() {
    if (_mountChild || !_childReady || state != BootState.WAITING) return;
    setState(() => _mountChild = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _childLaidOut = true;
      _stateMachine.update();
    });
  }

  final ValueNotifier<MouseCursor> _waitingMouseClickCursor = ValueNotifier(SystemMouseCursors.basic);

  void updateMouseGlobalPosition(PointerEvent event) {
    if (!_setMouseGlobalPosition) {
      mouseGlobalPosition = ValueNotifier(event.position);
      _setMouseGlobalPosition = true;
    } else {
      mouseGlobalPosition.value = event.position;
    }
  }

  void updateMouseReady(PointerEvent event) {
    updateMouseGlobalPosition(event);
    _mouseReady = true;
    _stateMachine.update();
  }

  @override
  void initState() {
    super.initState();

    GoogleFonts.pendingFonts([
      GoogleFonts.roboto(),
    ]).then((_) {
      _fontsReady = true;
      _stateMachine.update();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstFrameDone = true;
      _stateMachine.update();
      widget.precache?.call(context).whenComplete(() {
        _childReady = true;
        _maybeMountChild();
        _stateMachine.update();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: updateMouseGlobalPosition,
      onPointerHover: updateMouseGlobalPosition,
      onPointerDown: !_mouseReady ? updateMouseReady : updateMouseGlobalPosition,
      onPointerCancel: updateMouseGlobalPosition,
      onPointerUp: updateMouseGlobalPosition,
      onPointerPanZoomUpdate: updateMouseGlobalPosition,
      onPointerPanZoomEnd: updateMouseGlobalPosition,
      onPointerPanZoomStart: !_mouseReady ? updateMouseReady : updateMouseGlobalPosition,
      onPointerSignal: updateMouseGlobalPosition,
      behavior: HitTestBehavior.translucent,
      child: SizedBox.expand(
        child: getContent(),
      ),
    );
  }

  Widget? getContent() {
    Widget flyingText(FlyingWhere where, AnimationController controller) {
      return Center(
        child: FlyingText(
          "Loading...",
          color: widget.foregroundColor,
          flyingWhere: where,
          controller: controller,
        ),
      );
    }

    // Widget? flyingText = state.flyingWhere == null
    //     ? null
    //     : Center(
    //         child: FlyingText(
    //           "Loading...",
    //           color: widget.foregroundColor,
    //           flyingWhere: state.flyingWhere!,
    //           controller: _controller,
    //         ),
    //       );
    Widget clickText = ValueListenableBuilder(
      valueListenable: _waitingMouseClickCursor,
      builder: (_, cursor, child) => MouseRegion(
        cursor: cursor,
        child: child,
      ),
      child: Center(
        child: LayoutBuilder(
          builder: (context, _) {
            Size screenSize = MediaQuery.of(context).size;
            return Transform.translate(
              offset: Offset(0, -0.55 * min(screenSize.width * 0.15, screenSize.height * 0.4)), // scales with same rate as click and flying text
              child: AnimatedBuilder(
                animation: _clickTextFadeController,
                builder: (_, _) => Text(
                  "Click to",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: widget.foregroundColor.withValues(alpha: _clickTextFadeController.value),
                    fontSize: 0.2 * min(screenSize.width * 0.15, screenSize.height * 0.4), // min(...) is "EXPLORE" fontSize
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    // The child sits at the bottom of every stack once mounted, hidden behind an
    // opaque backdrop. It is laid out and painted once during SPLASH, then the
    // RepaintBoundary lets later frames re-composite it for free.
    // The wrapper chain is identical in every state so the element (and its
    // state and layout) is never rebuilt when the boot state changes.
    // Driven by the fade actually having started, not by the state name: the
    // overlap begins the fade partway through FLY_OUT. Until then the child
    // stays at Opacity(0) and is not painted at all.
    final bool childVisible = _fadeStarted || state == BootState.BOOTED;
    // Opacity 0 lays the child out but makes RenderOpacity skip painting it
    // entirely, so mounting it early buys the layout without paying paint cost
    // on every frame of the loading animation.
    final Widget? childLayer = _mountChild
        ? TickerMode(
            enabled: childVisible,
            child: Opacity(
              opacity: childVisible ? 1.0 : 0.0,
              child: IgnorePointer(ignoring: !childVisible, child: _child),
            ),
          )
        : null;
    final Widget backdrop = SizedBox.expand(child: ColoredBox(color: widget.backgroundColor));
    // Opaque until _beginFadeIn runs the controller, then an opacity layer.
    // FadeTransition drives compositing instead of rebuilding a ColoredBox with
    // a new colour every frame.
    final Widget fadingBackdrop = AnimatedBuilder(
      animation: _fadeInChildController,
      child: FadeTransition(
        opacity: ReverseAnimation(_fadeInChildController),
        child: backdrop,
      ),
      builder: (_, child) => _fadeInChildController.value < 0.2 ? AbsorbPointer(child: child) : IgnorePointer(child: child),
    );

    List<Widget> stack;
    switch (state) {
      case BootState.SPLASH:
        stack = [
          ?childLayer,
          backdrop,
        ];
      case BootState.FLY_IN:
        stack = [
          ?childLayer,
          backdrop,
          flyingText(FlyingWhere.IN, _flyInController),
        ];
      case BootState.WAITING:
        stack = [
          ?childLayer,
          backdrop,
          flyingText(FlyingWhere.CENTER, _waitingController),
        ];
      case BootState.WAITING_FOR_MOUSE:
        stack = [
          ?childLayer,
          backdrop,
          flyingText(FlyingWhere.CENTER, _waitingController),
          clickText, // top of stack so MouseRegion keeps right cursor
        ];
      case BootState.FLY_OUT:
        stack = [
          ?childLayer,
          fadingBackdrop, // opaque at first, then reveals the page under the departing letters
          flyingText(FlyingWhere.OUT, _flyOutController),
        ];
      case BootState.FADE_IN_CHILD:
        // The tail of the fade, after the letters have finished leaving.
        stack = [
          ?childLayer,
          fadingBackdrop,
        ];
      case BootState.BOOTED:
        stack = [?childLayer];
    }
    // scaffold for providing text theme data.
    // Always a Stack, even for a single layer, so the tree shape (and therefore
    // the child's element and layout) survives every boot state transition.
    return Scaffold(
      body: Stack(children: stack),
    );
  }
}

enum FlyingWhere {
  IN,
  CENTER,
  OUT,
}

class FlyingText extends StatefulWidget {
  final String text;
  final AnimationController controller;
  final FlyingWhere flyingWhere;
  final Color color;
  const FlyingText(this.text, {super.key, required this.flyingWhere, required this.controller, required this.color});

  @override
  State<FlyingText> createState() => _FlyingTextState();
}

class _FlyingTextState extends State<FlyingText> {
  static const Curve _FLY_CURVE = DoubleConOscCurve(); // ConOscCurve(2, a: 1);

  List<CurvedAnimation> _curves = const [];
  List<Animation<double>> _animations = const [];
  List<Widget> _letters = const [];
  double _travel = 0;

  Size? _builtForSize;
  Color? _builtForColor;
  FlyingWhere? _builtForWhere;
  AnimationController? _builtForController;
  String? _builtForText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildIfStale();
  }

  @override
  void didUpdateWidget(covariant FlyingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildIfStale();
  }

  @override
  void dispose() {
    _disposeCurves();
    super.dispose();
  }

  void _disposeCurves() {
    for (final curve in _curves) {
      curve.dispose();
    }
    _curves = const [];
  }

  /// Everything except the per-frame translation is constant for a given
  /// (size, color, text, direction, controller), so build it once instead of
  /// once per letter per frame.
  void _rebuildIfStale() {
    final screenSize = MediaQuery.sizeOf(context);
    if (screenSize == _builtForSize &&
        widget.color == _builtForColor &&
        widget.flyingWhere == _builtForWhere &&
        widget.text == _builtForText &&
        identical(widget.controller, _builtForController)) {
      return;
    }
    _builtForSize = screenSize;
    _builtForColor = widget.color;
    _builtForWhere = widget.flyingWhere;
    _builtForText = widget.text;
    _builtForController = widget.controller;

    _disposeCurves();

    final style = GoogleFonts.roboto(
      color: widget.color,
      fontSize: min(screenSize.width * 0.15, screenSize.height * 0.4),
    );
    // one measurement per layout, not one per letter per frame
    final textHeight = measureTextSize(data: widget.text, style: style, textDirection: TextDirection.ltr).height;
    _travel = screenSize.height + textHeight; // hide the text above and below screen as well

    final Tween<double> tween;
    switch (widget.flyingWhere) {
      case FlyingWhere.IN:
        tween = Tween(begin: 0.5, end: 0.0); // animate from half of screen below center to center
      case FlyingWhere.CENTER:
        tween = Tween(begin: 0.0, end: 0.0); // stay in center
      case FlyingWhere.OUT:
        tween = Tween(begin: 0.0, end: -0.5); // animate from center to half of screen above center
    }

    final n = widget.text.length;
    final curves = <CurvedAnimation>[];
    final animations = <Animation<double>>[];
    final letters = <Widget>[];
    for (int index = 0; index < n; ++index) {
      final double start, end;
      if (n == 1) {
        start = 0;
        end = 1;
      } else {
        const delay = 1; // fraction of first letter's animation when last letter starts
        const letterLength = 1 / (1 + delay); // fraction of total length
        start = index * (1 - letterLength) / (n - 1);
        end = start + letterLength;
      }
      final curve = CurvedAnimation(
        parent: widget.controller,
        curve: Interval(start, end, curve: _FLY_CURVE),
      );
      curves.add(curve);
      animations.add(tween.animate(curve));
      // stable Text identity => RenderParagraph never re-shapes;
      // RepaintBoundary => moving a letter re-composites instead of repainting the screen
      letters.add(
        RepaintBoundary(
          child: Text(
            widget.text[index],
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: style,
          ),
        ),
      );
    }
    _curves = curves;
    _animations = animations;
    _letters = letters;
  }

  @override
  Widget build(BuildContext context) {
    // TODO make this "Loading..." animation run even when the tab is in the background.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _letters.length; ++i)
          AnimatedBuilder(
            animation: _animations[i],
            child: _letters[i],
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _travel * _animations[i].value),
              child: child,
            ),
          ),
      ],
    );
  }
}
