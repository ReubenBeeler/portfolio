import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  runApp(ParallaxScrollerDemoApp());
}

class ParallaxScrollerDemoApp extends StatelessWidget {
  const ParallaxScrollerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parallax Scroller Demo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: ParallaxScrollerDemo(axis: Axis.horizontal),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ParallaxScrollerDemo extends StatefulWidget {
  final Axis axis;
  final int numPages;
  final double parallaxRatio;
  final bool darkenPages;
  const ParallaxScrollerDemo({super.key, this.axis = Axis.vertical, this.numPages = 8, this.parallaxRatio = 0.15, this.darkenPages = false});

  @override
  State<ParallaxScrollerDemo> createState() => _ParallaxScrollerDemoState();
}

class _ParallaxScrollerDemoState extends State<ParallaxScrollerDemo> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    final length = widget.axis == Axis.horizontal ? screenSize.width : screenSize.height;

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: widget.axis,
      child: ParallaxScroller(
        parallaxRatio: widget.parallaxRatio,
        background: Image.network(
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4',
          fit: BoxFit.cover, // BoxFit.fill, //
        ),
        child: Flex(
          direction: widget.axis,
          children: List.generate(widget.numPages, (i) {
            return Container(
              width: widget.axis == Axis.horizontal ? length : null,
              height: widget.axis == Axis.vertical ? length : null,
              color: widget.darkenPages ? Colors.black.withValues(alpha: i / (widget.numPages - 1)) : Colors.transparent,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Page ${i + 1}',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          _scrollController.animateTo(
                            ((i + 1) % widget.numPages) * length,
                            duration: Duration(milliseconds: (800 * sqrt((i - ((i + 1) % widget.numPages)).abs())).round()),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Scroll ${i + 1 == widget.numPages ? "To Top" : "Down"}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class ParallaxScroller extends StatefulWidget {
  final double parallaxRatio; // background moves at this fraction of the foreground
  final Widget background;
  final Widget child;

  const ParallaxScroller({
    super.key,
    required this.parallaxRatio,
    required this.background,
    required this.child,
  });

  @override
  ParallaxScrollerState createState() => ParallaxScrollerState();
}

class ParallaxScrollerState extends State<ParallaxScroller> {
  ScrollableState? _scrollableState;
  late Axis _scrollAxis;
  final ValueNotifier<double> _pixels = ValueNotifier(0);

  void scrollListener() => _pixels.value = _scrollableState!.position.pixels;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollableState?.position.removeListener(scrollListener);
    _scrollableState = Scrollable.maybeOf(context);
    assert(_scrollableState != null, "ParallaxScroller must be a child of a ScrollView!");
    _scrollableState!.position.addListener(scrollListener);
    _scrollAxis = _scrollableState!.position.axis;
  }

  @override
  void dispose() {
    _scrollableState?.position.removeListener(scrollListener);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {})); // God I fucking hate this
  }

  @override
  Widget build(BuildContext context) {
    double? scrollViewLength = _scrollableState!.position.hasViewportDimension ? _scrollableState!.position.viewportDimension : null;
    return Stack(
      children: [
        if (scrollViewLength != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scrollLength = _scrollAxis == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
                final parallaxLength = scrollViewLength + widget.parallaxRatio * (scrollLength - scrollViewLength);
                return ValueListenableBuilder(
                  valueListenable: _pixels,
                  builder: (BuildContext context, double pixels, Widget? background) {
                    double offset = pixels * (1 - widget.parallaxRatio);
                    return Transform.translate(
                      offset: Offset(
                        _scrollAxis == Axis.horizontal ? offset : 0,
                        _scrollAxis == Axis.horizontal ? 0 : offset,
                      ),
                      child: background,
                    );
                  },
                  child: Flex(
                    direction: _scrollAxis,
                    children: [
                      SizedBox.fromSize(
                        size: _scrollAxis == Axis.horizontal ? Size(parallaxLength, constraints.maxHeight) : Size(constraints.maxWidth, parallaxLength),
                        child: widget.background,
                      ),
                      Spacer(),
                    ],
                  ),
                );
              },
            ),
          ),
        MeasureSize(
          // axis: _scrollAxis, //
          onChange: (_) => WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {})), // cuz background is 1 frame delayed...
          child: widget.child,
        ),
      ],
    );
  }
}

class MeasureSize extends SingleChildRenderObjectWidget {
  final void Function(Size? size) onChange;
  final Axis? axis;

  const MeasureSize({super.key, required this.onChange, required Widget child, this.axis}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureSize(onChange, axis);
}

class _RenderMeasureSize extends RenderProxyBox {
  final void Function(Size? size) onChange;
  final Axis? axis;

  _RenderMeasureSize(this.onChange, this.axis);

  Size? oldSize;
  @override
  void performLayout() {
    super.performLayout();
    Size? newSize = child?.size;
    if ((axis == null && oldSize != newSize) || (axis == Axis.horizontal && oldSize?.width != newSize?.width) || (axis == Axis.vertical && oldSize?.height != newSize?.height)) {
      onChange(oldSize = newSize);
    }
  }
}
