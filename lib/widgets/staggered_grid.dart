import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StaggeredGrid Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StaggeredGridDemo(),
    );
  }
}

class StaggeredGridDemo extends StatelessWidget {
  const StaggeredGridDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('StaggeredGrid Demo'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: StaggeredGrid(
          spacing: 12.0,
          children: [
            _buildCard('Item 1', Colors.red, 120, 80),
            _buildCard('Item 2', Colors.green, 100, 120),
            _buildCard('Item 3', Colors.blue, 80, 60),
            _buildCard('Item 4', Colors.orange, 140, 100),
            _buildCard('Item 5', Colors.purple, 90, 140),
            _buildCard('Item 6', Colors.teal, 110, 70),
            _buildCard('Item 7', Colors.pink, 130, 90),
            _buildCard('Item 8', Colors.amber, 85, 110),
            _buildCard('Item 9', Colors.indigo, 95, 85),
            _buildCard('Item 10', Colors.cyan, 125, 95),
            _buildCard('Item 11', Colors.lime, 75, 125),
            _buildCard('Item 12', Colors.deepOrange, 105, 75),
            _buildCard('Item 13', Colors.brown, 115, 105),
            _buildCard('Item 14', Colors.grey, 135, 115),
            _buildCard('Item 15', Colors.blueGrey, 70, 135),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String text, Color color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color, width: 2.0),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class StaggeredGrid extends MultiChildRenderObjectWidget {
  final double spacing;
  final double? maxWidth; // for letting children overflow (e.g. if nested into a horiz scroll view while still using finite constraints)

  const StaggeredGrid({
    super.key,
    super.children,
    this.spacing = 20.0,
    this.maxWidth,
  });

  @override
  RenderStaggeredGrid createRenderObject(BuildContext context) {
    return RenderStaggeredGrid(spacing: spacing, maxWidth: maxWidth);
  }

  @override
  void updateRenderObject(BuildContext context, RenderStaggeredGrid renderObject) {
    renderObject.spacing = spacing;
    renderObject.maxWidth = maxWidth;
  }
}

class StaggeredGridParentData extends ContainerBoxParentData<RenderBox> {
  Offset? position;
}

class RenderStaggeredGrid extends RenderBox with ContainerRenderObjectMixin<RenderBox, StaggeredGridParentData>, RenderBoxContainerDefaultsMixin<RenderBox, StaggeredGridParentData> {
  double _spacing;
  double? _maxWidth;

  RenderStaggeredGrid({required double spacing, double? maxWidth}) : _spacing = spacing, _maxWidth = maxWidth;

  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing != value) {
      _spacing = value;
      markNeedsLayout();
    }
  }

  double? get maxWidth => _maxWidth;
  set maxWidth(double? value) {
    if (_maxWidth != value) {
      _maxWidth = value;
      markNeedsLayout(); // only needs it if math.min(this.maxWidth ?? double.infinity, constraints.maxWidth) changes, but whatever
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! StaggeredGridParentData) {
      child.parentData = StaggeredGridParentData();
    }
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    final availableWidth = math.min(this.maxWidth ?? double.infinity, constraints.maxWidth);
    final List<RenderBox> children = getChildrenAsList();
    final List<Rect> placedRects = [];
    double maxHeight = 0;
    double maxWidth = 0;

    // Layout each child and determine its position
    for (final child in children) {
      // First, layout the child to get its size
      child.layout(BoxConstraints(), parentUsesSize: true);
      final childSize = child.size;

      // Find the best position for this child
      final position = _findBestPosition(
        childSize,
        availableWidth,
        placedRects,
      );

      // Store the position in parent data
      final parentData = child.parentData as StaggeredGridParentData;
      parentData.offset = position;

      // Add this child's rect to placed rects
      final childRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        childSize.width,
        childSize.height,
      );
      placedRects.add(childRect);

      // Update max height
      maxWidth = math.max(maxWidth, position.dx + childSize.width);
      maxHeight = math.max(maxHeight, position.dy + childSize.height);
    }

    // Set the size of this render object
    size = Size(
      math.min(math.max(availableWidth, maxWidth), constraints.maxWidth),
      maxHeight,
    );
  }

  Offset _findBestPosition(Size childSize, double availableWidth, List<Rect> placedRects) {
    // Find the highest possible Y position
    for (double y = 0; y <= _getMaxY(placedRects) + spacing; y += 1) {
      for (double x = 0; x <= availableWidth - childSize.width; x += 1) {
        final candidateRect = Rect.fromLTWH(x, y, childSize.width, childSize.height);

        if (_isValidPosition(candidateRect, placedRects)) {
          return Offset(x, y);
        }
      }
    }

    // If no valid position found, place at the bottom
    return Offset(0, _getMaxY(placedRects) + spacing);
  }

  double _getMaxY(List<Rect> rects) {
    if (rects.isEmpty) return 0;
    return rects.map((r) => r.bottom).reduce(math.max);
  }

  bool _isValidPosition(Rect candidateRect, List<Rect> placedRects) {
    for (final placedRect in placedRects) {
      if (_rectsOverlapWithSpacing(candidateRect, placedRect, spacing)) {
        return false;
      }
    }
    return true;
  }

  bool _rectsOverlapWithSpacing(Rect rect1, Rect rect2, double spacing) {
    // Expand both rects by spacing/2 to check for minimum spacing
    final expandedRect1 = Rect.fromLTRB(
      rect1.left - spacing / 2,
      rect1.top - spacing / 2,
      rect1.right + spacing / 2,
      rect1.bottom + spacing / 2,
    );
    final expandedRect2 = Rect.fromLTRB(
      rect2.left - spacing / 2,
      rect2.top - spacing / 2,
      rect2.right + spacing / 2,
      rect2.bottom + spacing / 2,
    );

    return expandedRect1.overlaps(expandedRect2);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
