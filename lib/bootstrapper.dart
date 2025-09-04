import 'dart:math';
import 'dart:ui';

import 'package:web/web.dart' as web;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

import 'package:portfolio/util.dart';

late ValueNotifier<Offset> mouseGlobalPosition;
bool _setMouseGlobalPosition = false;

enum BootState {
  SPLASH,
  FLY_IN(FlyingWhere.IN),
  WAITING(FlyingWhere.CENTER),
  WAITING_MOUSE_CLICK(FlyingWhere.CENTER),
  FLY_OUT((FlyingWhere.OUT)),
  FADE_IN,
  BOOTED;

  final FlyingWhere? flyingWhere;

  const BootState([this.flyingWhere]);
}

class Bootstrapper extends StatefulWidget {
  final List<ImageProvider> precache;
  final Widget? child;
  final Color foregroundColor;
  final Color backgroundColor;

  const Bootstrapper({super.key, this.precache = const [], this.child, this.foregroundColor = Colors.white, this.backgroundColor = Colors.black});

  @override
  State<Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends AnimatedState<Bootstrapper> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)..autoDispose(this);
  late final AnimationController _clickTextFadeController = AnimationController(vsync: this)..autoDispose(this);

  BootState _bootState = BootState.FLY_IN; // I don't like the SPLASH fade in so skip it...

  bool _mouseReady = false;
  bool _waitedMinimum = false;
  int _numPrecached = 0;
  bool get cacheReady => _numPrecached == widget.precache.length;

  bool get allReadyButMouse => _waitedMinimum && cacheReady && !_mouseReady;
  bool get bootReady => _waitedMinimum && cacheReady && _mouseReady;

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
    updateWaitingState();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var imageProvider in widget.precache) {
        precacheImage(imageProvider, context).whenComplete(() {
          ++_numPrecached;
          updateWaitingState();
        });
      }
    });

    WidgetsBinding.instance.endOfFrame.then((_) {
      // skip fade-in splash
      // _controller.start(const Duration(milliseconds: 0)).whenComplete(() {
      //   setState(() => _bootState = BootState.FLY_IN);
      _controller.start(const Duration(milliseconds: 1000)).whenComplete(() {
        setState(() => _bootState = BootState.WAITING);
        _controller.start(const Duration(milliseconds: 500)).whenComplete(() {
          _waitedMinimum = true;
          updateWaitingState();
        });
      });
      // });
    });
  }

  void updateWaitingState() {
    if (allReadyButMouse) {
      setState(() => _bootState = BootState.WAITING_MOUSE_CLICK);
      _clickTextFadeController.start(const Duration(seconds: 1));
      Future.delayed(const Duration(milliseconds: 125)).whenComplete(() {
        runOnPlatformThread(() {
          if (_bootState == BootState.WAITING_MOUSE_CLICK) {
            web.document.body?.style.cursor = 'pointer'; // MouseRegion doesn't automatically update this if the mouse hasn't interacted with the app yet
            _waitingMouseClickCursor.value = SystemMouseCursors.click; // forces MouseRegion to re-render with updated mouse
          }
        });
      });
    } else if (bootReady) {
      setState(() => _bootState = BootState.FLY_OUT);
      _controller.start(const Duration(milliseconds: 1000)).whenComplete(() {
        setState(() => _bootState = BootState.FADE_IN);
        _controller.start(const Duration(milliseconds: 1000)).whenComplete(() {
          setState(() => _bootState = BootState.BOOTED);
        });
      });
    }
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
    Widget? flyingText = _bootState.flyingWhere == null
        ? null
        : Center(
            child: FlyingText(
              "EXPLORE",
              color: widget.foregroundColor,
              flyingWhere: _bootState.flyingWhere!,
              controller: _controller,
            ),
          );
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
                    color: widget.foregroundColor.withAlpha((255 * _clickTextFadeController.value).round()),
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
    switch (_bootState) {
      case BootState.SPLASH:
        stack = [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => SizedBox.expand(child: ColoredBox(color: widget.backgroundColor.withAlpha(lerpDouble(0x00, 0xFF, _controller.value)!.round()))),
          ),
        ];
      case BootState.FLY_IN:
      case BootState.WAITING:
        stack = [
          SizedBox.expand(child: ColoredBox(color: widget.backgroundColor)),
          flyingText!,
        ];
      case BootState.WAITING_MOUSE_CLICK:
        stack = [
          SizedBox.expand(child: ColoredBox(color: widget.backgroundColor)),
          flyingText!,
          clickText, // top of stack so MouseRegion keeps right cursor
        ];
      case BootState.FLY_OUT:
        stack = [
          SizedBox.expand(child: ColoredBox(color: widget.backgroundColor)),
          flyingText!,
        ];
      case BootState.FADE_IN:
        stack = [
          ?widget.child, // TODO why is child icon not animating correctly when switching between fade-in and booted?
          AnimatedBuilder(
            animation: _controller,
            builder: (_, _) {
              final box = SizedBox.expand(child: ColoredBox(color: widget.backgroundColor.withAlpha(lerpDouble(0xFF, 0x00, _controller.value)!.round())));
              return _controller.value < 0.2 ? AbsorbPointer(child: box) : IgnorePointer(child: box);
            },
          ),
        ];
      case BootState.BOOTED:
        return widget.child;
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

class _FlyingTextState extends AnimatedState<FlyingText> with SingleTickerProviderStateMixin {
  static const Curve _FLY_CURVE = ConOscCurve(2, a: 1);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.text.length, (index) {
          final delay = 1; // fraction of first letter's animation when last letter starts
          final letterLength = 1 / (1 + delay); // fraction of total length
          final start = index * (1 - letterLength) / (7 - 1);
          final end = start + letterLength;

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
            style: GoogleFonts.rumRaisin(
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
