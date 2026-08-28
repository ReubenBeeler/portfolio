import 'dart:async';
import 'dart:math';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

import 'util/boot_trace.dart';
import 'util/miscellaneous.dart';
import 'util/state_machine.dart';

/// True once the boot screen has handed over.
///
/// Anything below the fold waits for this. Downloading and decoding an image
/// nobody can see yet costs main-thread and raster time during the hand-over,
/// which is the one second of the whole boot where a person is actually
/// watching something move.
final ValueNotifier<bool> appBooted = ValueNotifier(false);

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

  /// True when index.html is running the loading animation. Then Dart's own
  /// FLY_IN/WAITING/FLY_OUT never run: nothing Dart draws can appear until the
  /// engine and app binary have downloaded, which is seconds into a cold load,
  /// so the animation was invisible to the visitors it exists for. Dart still
  /// owns the fade from black to the page.
  bool _htmlSplash = false;
  bool _splashSignalled = false;
  bool _splashGone = false;

  static const Duration _kFlyInDuration = Duration(milliseconds: 1300);
  static const Duration _kFlyOutDuration = Duration(milliseconds: 1300);
  static const Duration _kFadeDuration = Duration(seconds: 1);

  /// How far through FLY_OUT the home page starts fading up, so the two
  /// animations overlap instead of running back to back. The assets are ready
  /// long before this point, so the back-to-back version was ~700ms of pure
  /// waiting. Raise it to keep the letters clear of the page for longer, lower
  /// it to hand over sooner.
  static const double _kFadeOverlap = 0.5;

  /// Long enough that a slow phone on a slow link finishes normally, short
  /// enough that nobody watches a stuck loading screen. See [_forceBoot].
  static const Duration _kBootWatchdog = Duration(seconds: 20);
  Timer? _watchdog;

  late final _stateMachine =
      StateMachine(BootState.SPLASH, {
          // Deliberately not gated on fonts: the splash draws in SplashRoboto,
          // which the engine has already loaded by the time the first frame
          // runs, so waiting on google_fonts here only bought a black screen.
          BootState.SPLASH: () => _htmlSplash
              ? (_splashGone ? BootState.FADE_IN_CHILD : null)
              : (_firstFrameDone ? BootState.FLY_IN : null),
          BootState.FLY_IN: () => _flyInDone ? BootState.WAITING : null,
          // BootState.WAITING: () {
          //   // timerDone represents minimum time here
          //   if (_waitedMinimum && cacheReady) {
          //     if (!_mouseReady) return BootState.WAITING_FOR_MOUSE;
          //     return BootState.FLY_OUT;
          //   }
          // },
          // _fontsReady moved here from SPLASH: the page behind the splash must
          // not reflow after handover, but the splash itself need not wait.
          BootState.WAITING: () => _childReady && _childLaidOut && _fontsReady ? BootState.FLY_OUT : null,
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
      case BootState.BOOTED:
        appBooted.value = true;
      case BootState.FADE_IN_CHILD:
        // Normally already running: the overlap starts it partway through
        // FLY_OUT. This only fires it if the overlap somehow did not.
        _beginFadeIn();
        if (_fadeInChild) _stateMachine.update();
      case _:
    }
  }

  /// Sets a boot gate and reports it, so `?profile` shows which gate a stalled
  /// boot is waiting on instead of leaving it to guesswork.
  void _setFlag(String name, VoidCallback set) {
    set();
    reportBootPhase('flag:$name');
    _maybeMountChild();
    _maybeSignalSplash();
    _stateMachine.update();
  }

  /// Everything the page needs before it is worth revealing.
  bool get _pageReady => _firstFrameDone && _fontsReady && _childReady && _childLaidOut;

  /// Hands the page-side splash its cue. It flies the letters out over an
  /// opaque black backdrop and calls back when they are gone.
  void _maybeSignalSplash() {
    if (!_htmlSplash || _splashSignalled || !_pageReady) return;
    _splashSignalled = true;
    reportBootPhase('flag:splashCue');
    bootSplashFlyOut();
  }

  /// A loading screen that never ends is worse than a page with a missing
  /// image. If anything we gate on never arrives, force the boot forward.
  void _forceBoot() {
    _watchdog = null;
    if (!mounted || state == BootState.BOOTED) return;
    reportBootPhase('WATCHDOG:${state.name}');
    _firstFrameDone = true;
    _fontsReady = true;
    _childReady = true;
    if (_htmlSplash) {
      bootSplashFlyOut(); // get the letters off the screen even if it never called back
      _splashGone = true;
    }
    if (!_mountChild) setState(() => _mountChild = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _childLaidOut = true;
      _stateMachine.update();
    });
    _stateMachine.update();
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
    // With the page-side splash there is no WAITING state to spend the layout
    // in, so spend it in SPLASH instead. Either way it happens behind an opaque
    // backdrop, before anything animates.
    if (_mountChild || !_childReady) return;
    if (state != (_htmlSplash ? BootState.SPLASH : BootState.WAITING)) return;
    setState(() => _mountChild = true);
    reportBootPhase('flag:mountChild');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setFlag('childLaidOut', () => _childLaidOut = true);
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
    _watchdog = Timer(_kBootWatchdog, _forceBoot);
    runOnDispose(() => _watchdog?.cancel());

    _htmlSplash = bootSplashPresent();
    if (_htmlSplash) {
      onBootSplashDone(() {
        if (!mounted) return;
        _setFlag('splashGone', () => _splashGone = true);
      });
    }

    // onError matters: a bare .then() here meant any font failure left
    // _fontsReady false forever, and the splash never advanced. A missing font
    // should degrade to a fallback face, not hang the boot.
    GoogleFonts.pendingFonts([
      GoogleFonts.roboto(),
    ]).then(
      (_) => _setFlag('fontsReady', () => _fontsReady = true),
      onError: (Object _) => _setFlag('fontsReady(failed)', () => _fontsReady = true),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setFlag('firstFrameDone', () => _firstFrameDone = true);
      widget.precache?.call(context).whenComplete(() {
        _setFlag('childReady', () => _childReady = true);
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
    // Opacity(0) makes RenderOpacity skip painting the child altogether, so the
    // page's first paint (shaders, image textures, text rasterisation) landed
    // on the first frame of the fade. With the animation now owned by the page,
    // Dart has nothing else to draw during the splash, so paint it there
    // instead: it sits under an opaque backdrop and nobody sees it.
    final bool childPainted = childVisible || (_htmlSplash && _mountChild);
    final Widget? childLayer = _mountChild
        ? TickerMode(
            enabled: childVisible,
            child: Opacity(
              opacity: childPainted ? 1.0 : 0.0,
              child: IgnorePointer(ignoring: !childVisible, child: _child),
            ),
          )
        : null;
    final Widget backdrop = SizedBox.expand(child: ColoredBox(color: widget.backgroundColor));
    // A translucent rectangle, not an opacity layer. FadeTransition pushed a
    // full-screen OpacityLayer every frame, which means rendering the page into
    // an offscreen texture and blending it back; across a 3774x2041 viewport
    // that is a lot of fill rate for what is ultimately one alpha blend. The
    // long frames during this phase reported ~0ms of main-thread blocking,
    // which is what a GPU-bound fade looks like.
    // ColoredBox is opaque to hit testing, so not ignoring it absorbs pointers
    // the way the old AbsorbPointer did.
    final Widget fadingBackdrop = AnimatedBuilder(
      animation: _fadeInChildController,
      builder: (_, _) => IgnorePointer(
        ignoring: _fadeInChildController.value >= 0.2,
        child: SizedBox.expand(
          child: ColoredBox(
            color: widget.backgroundColor.withValues(alpha: 1.0 - _fadeInChildController.value),
          ),
        ),
      ),
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

    // Bundled and declared in pubspec, so it is ready before the first frame.
    // GoogleFonts.roboto() here meant the splash could not draw until a runtime
    // font fetch resolved, which cost seconds of black screen on a cold load.
    final style = TextStyle(
      fontFamily: 'Roboto',
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
