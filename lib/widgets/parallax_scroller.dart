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
  ScrollPosition? _position;
  late Axis _scrollAxis;
  final ValueNotifier<double> _pixels = ValueNotifier(0);

  void scrollListener() => _pixels.value = _position!.pixels;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    assert(scrollable != null, "ParallaxScroller must be a child of a ScrollView!");
    if (scrollable!.position != _position) {
      _position?.removeListener(scrollListener);
      _position = scrollable.position..addListener(scrollListener);
    }
    _scrollAxis = _position!.axis;
    _pixels.value = _position!.pixels;
  }

  @override
  void dispose() {
    _position?.removeListener(scrollListener);
    _pixels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    return _ParallaxLayout(
      axis: _scrollAxis,
      parallaxRatio: widget.parallaxRatio,
      position: _position!,
      // Only used before the viewport has ever reported its own extent, i.e. on
      // the very first layout. Sizing the backdrop a frame late is what used to
      // make it jump.
      fallbackViewportLength: _scrollAxis == Axis.horizontal ? screenSize.width : screenSize.height,
      children: [
        widget.child,
        ValueListenableBuilder<double>(
          valueListenable: _pixels,
          builder: (context, pixels, background) {
            final double offset = pixels * (1 - widget.parallaxRatio);
            return Transform.translate(
              offset: _scrollAxis == Axis.horizontal ? Offset(offset, 0) : Offset(0, offset),
              child: background,
            );
          },
          child: widget.background,
        ),
      ],
    );
  }
}

/// Lays the backdrop out from the content's measured size in the *same* layout
/// pass. Children are `[content, background]`.
class _ParallaxLayout extends MultiChildRenderObjectWidget {
  final Axis axis;
  final double parallaxRatio;
  final ScrollPosition position;
  final double fallbackViewportLength;

  const _ParallaxLayout({
    required this.axis,
    required this.parallaxRatio,
    required this.position,
    required this.fallbackViewportLength,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderParallaxLayout(
    axis: axis,
    parallaxRatio: parallaxRatio,
    position: position,
    fallbackViewportLength: fallbackViewportLength,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderParallaxLayout renderObject) {
    renderObject
      ..axis = axis
      ..parallaxRatio = parallaxRatio
      ..position = position
      ..fallbackViewportLength = fallbackViewportLength;
  }
}

class _ParallaxParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderParallaxLayout extends RenderBox with ContainerRenderObjectMixin<RenderBox, _ParallaxParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _ParallaxParentData> {
  _RenderParallaxLayout({
    required Axis axis,
    required double parallaxRatio,
    required ScrollPosition position,
    required double fallbackViewportLength,
  }) : _axis = axis,
       _parallaxRatio = parallaxRatio,
       _position = position,
       _fallbackViewportLength = fallbackViewportLength;

  Axis _axis;
  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsLayout();
  }

  double _parallaxRatio;
  set parallaxRatio(double value) {
    if (_parallaxRatio == value) return;
    _parallaxRatio = value;
    markNeedsLayout();
  }

  ScrollPosition _position;
  set position(ScrollPosition value) {
    if (_position == value) return;
    _position = value;
    markNeedsLayout();
  }

  double _fallbackViewportLength;
  set fallbackViewportLength(double value) {
    if (_fallbackViewportLength == value) return;
    _fallbackViewportLength = value;
    markNeedsLayout();
  }

  double _usedViewportLength = double.nan;
  bool _recheckScheduled = false;
  final LayerHandle<ClipRectLayer> _clipHandle = LayerHandle<ClipRectLayer>();

  RenderBox get _content => firstChild!;
  RenderBox get _background => lastChild!;

  double get _viewportLength => _position.hasViewportDimension ? _position.viewportDimension : _fallbackViewportLength;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ParallaxParentData) child.parentData = _ParallaxParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _content.getMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicWidth(double height) => _content.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) => _content.getMinIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicHeight(double width) => _content.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(_content.getDryLayout(constraints));

  @override
  void performLayout() {
    _content.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(_content.size);

    final double viewportLength = _usedViewportLength = _viewportLength;
    final double contentLength = _axis == Axis.horizontal ? size.width : size.height;
    // Long enough that the backdrop still covers the viewport at full scroll,
    // given that it only travels `parallaxRatio` as far as the content does.
    final double backgroundLength = max(viewportLength, viewportLength + _parallaxRatio * (contentLength - viewportLength));
    _background.layout(
      BoxConstraints.tight(_axis == Axis.horizontal ? Size(backgroundLength, size.height) : Size(size.width, backgroundLength)),
    );

    _scheduleViewportRecheck();
  }

  /// The viewport publishes its extent *after* we lay out, so the first layout
  /// of a scroll view runs on the fallback. Re-run only if it was actually
  /// wrong, which also covers a window resize.
  void _scheduleViewportRecheck() {
    if (_recheckScheduled) return;
    _recheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recheckScheduled = false;
      if (!attached) return;
      if (_position.hasViewportDimension && _position.viewportDimension != _usedViewportLength) markNeedsLayout();
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _clipHandle.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (PaintingContext context, Offset offset) => context.paintChild(_background, offset),
      oldLayer: _clipHandle.layer,
    );
    context.paintChild(_content, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => _content.hitTest(result, position: position);

  @override
  void dispose() {
    _clipHandle.layer = null;
    super.dispose();
  }
}
