import 'dart:async';
import 'dart:io' show sleep;
import 'dart:math';
import 'dart:ui';

import 'package:portfolio/main.dart' show accentColor;
import 'package:web/web.dart' as web;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

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

  late final Widget? _child = widget.child?.call(); // only call once

  bool _firstFrameDone = false;
  bool _fontsReady = false;
  bool _flyInDone = false;
  // bool _waitedMinimum = false;
  bool _childReady = false;
  bool _mouseReady = false;
  bool _flyOutDone = false;
  bool _fadeInChild = false;

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
          BootState.WAITING: () => _childReady ? BootState.FLY_OUT : null,
          // BootState.WAITING_FOR_MOUSE: () => _mouseReady ? BootState.FLY_OUT : null,
          BootState.FLY_OUT: () => _flyOutDone ? BootState.FADE_IN_CHILD : null,
          BootState.FADE_IN_CHILD: () => _fadeInChild ? BootState.BOOTED : null,
        })
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

    switch (state) {
      case BootState.FLY_IN:
        controllerRestart(_flyInController, const Duration(milliseconds: 1300), () => _flyInDone = true);
      case BootState.WAITING:
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
        controllerRestart(_flyOutController, const Duration(milliseconds: 1300), () => _flyOutDone = true);
      case BootState.FADE_IN_CHILD:
        controllerRestart(_fadeInChildController, const Duration(seconds: 1), () => _fadeInChild = true);
      case _:
    }
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
    List<Widget> stack;
    switch (state) {
      case BootState.SPLASH:
        stack = [
          SizedBox.expand(child: ColoredBox(color: widget.backgroundColor)),
        ];
      case BootState.FLY_IN:
        stack = [
          SizedBox.expand(child: ColoredBox(color: widget.backgroundColor)),
          flyingText(FlyingWhere.IN, _flyInController),
        ];
      case BootState.WAITING:
        stack = [
          SizedBox.expand(child: ColoredBox(color: widget.backgroundColor)),
          flyingText(FlyingWhere.CENTER, _waitingController),
        ];
      case BootState.WAITING_FOR_MOUSE:
        stack = [
          SizedBox.expand(child: ColoredBox(color: widget.backgroundColor)),
          flyingText(FlyingWhere.CENTER, _waitingController),
          clickText, // top of stack so MouseRegion keeps right cursor
        ];
      case BootState.FLY_OUT:
        stack = [
          SizedBox.expand(child: ColoredBox(color: widget.backgroundColor)),
          flyingText(FlyingWhere.OUT, _flyOutController),
        ];
      case BootState.FADE_IN_CHILD:
        stack = [
          ?_child, // TODO child icon not animating correctly when switching between fade-in and booted?
          AnimatedBuilder(
            animation: _fadeInChildController,
            builder: (_, _) {
              final box = SizedBox.expand(
                child: ColoredBox(color: widget.backgroundColor.withValues(alpha: 1.0 - _fadeInChildController.value)),
              );
              return _fadeInChildController.value < 0.2 ? AbsorbPointer(child: box) : IgnorePointer(child: box);
            },
          ),
        ];
      case BootState.BOOTED:
        return _child;
    }
    // scaffold for providing text theme data
    return Scaffold(
      body: stack.length <= 1 ? stack.firstOrNull : Stack(children: stack),
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

  @override
  Widget build(BuildContext context) {
    // TODO make this "Loading..." animation run even when the tab is in the background.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.text.length, (index) {
          final double start, end;
          if (widget.text.length == 1) {
            start = 0;
            end = 1;
          } else {
            final delay = 1; // fraction of first letter's animation when last letter starts
            final letterLength = 1 / (1 + delay); // fraction of total length
            // final int n = widget.text.length;
            // (n - index)/(n*(n+1)~/2);
            start = index * (1 - letterLength) / (widget.text.length - 1);
            end = start + letterLength;
          }

          Tween<double> tween;
          switch (widget.flyingWhere) {
            case FlyingWhere.IN:
              tween = Tween(begin: 0.5, end: 0.0); // animate from half of screen below center to center
            case FlyingWhere.CENTER:
              tween = Tween(begin: 0.0, end: 0.0); // stay in center
            case FlyingWhere.OUT:
              tween = Tween(begin: 0.0, end: -0.5); // animate from center to half of screen above center
          }
          final animation = tween.animate(
            CurvedAnimation(
              parent: widget.controller,
              curve: Interval(start, end, curve: _FLY_CURVE),
            ),
          );

          Size screenSize = MediaQuery.of(context).size;

          final text = Text(
            widget.text[index],
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: GoogleFonts.roboto(
              color: widget.color,
              fontSize: min(screenSize.width * 0.15, screenSize.height * 0.4),
            ),
          );
          double textHeight = measureTextSize(text: text).height;
          double effectiveScreenHeight = screenSize.height + textHeight; // hide the text above and below screen as well

          return AnimatedBuilder(
            animation: animation,
            builder: (_, _) => Transform.translate(
              offset: Offset(0, lerp(0, effectiveScreenHeight, animation.value)),
              child: text,
            ),
          );
        }),
      ),
    );
  }
}
