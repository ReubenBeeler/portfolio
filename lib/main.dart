import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:portfolio/bootstrapper.dart';
import 'package:portfolio/widgets/lazy_image.dart';
import 'package:portfolio/widgets/link_text.dart';
import 'package:portfolio/widgets/parallax_scroller.dart';
import 'package:portfolio/widgets/my_view.dart';
import 'package:portfolio/views/view_certifications.dart';
import 'package:portfolio/views/view_home.dart';
import 'package:portfolio/util/boot_trace.dart';
import 'package:portfolio/util/build_id.dart';
import 'package:portfolio/util/miscellaneous.dart';
import 'package:portfolio/views/view_projects.dart';
import 'package:url_launcher/url_launcher.dart';

// Home page:
//  Quick Links (on right)
//    LinkedIn, GitHub, Resume
//  Scroll Icons (on bottom)
//    BIO: Picture on the lift (different from pp) doing what I love + few 2-liners describing me
//    EXPERIENCE:
//    EDUCATION:
//    CERTIFICATIONS:
//    SKILLS:
//    PROJECTS: OPUS research, bike generator, ...
//    PUBLICATIONS:

List<MyView> views = [
  ViewHome(),
  ViewProjects(),
  // ViewPublications(),
  // ViewSkills(),
  ViewCertifications(),
];
final accentColor = Color(0xFF00E8F3); // Color.lerp(Color(0xFF00FFEE), Color(0xFF00B3FF), 0.3)!;
const String background_path = "assets/background.webp";

void main() {
  // Before anything else, so a report from a stale deploy is loud rather than
  // silently indistinguishable from a report on the change under test.
  reportBuild(buildId);
  assert(views.isNotEmpty);
  const String title = "Reuben's Portfolio";
  final loadKey = GlobalKey();

  // Only what the first screen actually shows. Everything else (the backdrop,
  // the thumbnails, the certificates) loads on its own behind a placeholder,
  // so the loading screen is never held up by an image nobody is looking at.
  final images = [
    NetworkImage('assets/github_logo_clean.webp'),
    NetworkImage('assets/linkedin_circle.webp'),
    NetworkImage('assets/profile_pic.webp'),
  ];
  runApp(
    MaterialApp(
      title: title,
      color: accentColor,
      // theme: ...
      home: Bootstrapper(
        precache: (context) async {
          // These used to be awaited one at a time, which serialised every
          // download: the loading screen waited for the sum of all of them
          // instead of the slowest one.
          // TODO merge these images into specific view precache
          await Future.wait([
            for (var view in views) ?view.precache?.call(),
            for (var imageProvider in images) precacheImage(imageProvider, context),
          ]);
        },
        child: () => Scaffold(
          key: loadKey, // to prevent re-initializing state immediately after fade-in by bootstrapper
          // Black until background.webp arrives.
          backgroundColor: Colors.black,
          // appBar: AppBar(
          //   backgroundColor: accentColor,
          // ),
          body: _ViewController(),
        ),
      ),
    ),
  );
}

class _ViewController extends StatefulWidget {
  @override
  State<_ViewController> createState() => _ViewControllerState();
}

Widget _backdrop() {
  // FilterQuality.low is bilinear, which runs in the texture unit and is the
  // floor for drawing an image. Cubic cost sixteen samples per pixel across the
  // whole viewport every frame; nearest measured indistinguishable from this.
  return RepaintBoundary(
    child: LazyImage(
      image: const NetworkImage(background_path),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.low,
      fadeDuration: const Duration(milliseconds: 600),
      placeholder: const ColoredBox(color: Colors.black),
    ),
  );
}

class _ViewControllerState extends AnimatedState<_ViewController> with SingleTickerProviderStateMixin {
  // late final SmoothScroller _smoothScroller = SmoothScroller(scrollDirection: Axis.vertical, vsync: this);
  late final ScrollController _controller = ScrollController()..addListener(_updateNavBarListener);
  final GlobalKey _navBarKey = GlobalKey(); // for keeping state across switch between inline and overlay
  final GlobalKey _inlineNavBarKey = GlobalKey();
  final GlobalKey _viewsParentKey = GlobalKey();
  final GlobalKey _firstScreenKey = GlobalKey();
  late double _inlineNavBarHeight;
  late double _overlayNavBarHeight;

  // Scroll-driven nav bar geometry.
  //
  // These were fields written from a post-frame setState on every scroll
  // notification, so every frame of every scroll rebuilt this widget -- the
  // whole page, nav bar and all -- and applied the result one frame late. As
  // listenables only the bar itself rebuilds, in the same frame as the scroll.
  final ValueNotifier<bool> _doNavBarOverlay = ValueNotifier(false);
  final ValueNotifier<double> _navBarTop = ValueNotifier(0);
  final ValueNotifier<double> _navBarHeight = ValueNotifier(0);
  final ValueNotifier<double> _navBarFrac = ValueNotifier(0);
  late final Listenable _navBarGeometry = Listenable.merge([_navBarTop, _navBarHeight]);

  void _updateNavBarListener() {
    double? homeBottom = getBottomFromRenderBox(views.first.globalKey);
    double? inlineNavBarTop = getTopFromRenderBox(_inlineNavBarKey);
    double? screenHeight = MediaQuery.maybeHeightOf(context);
    if (homeBottom == null || inlineNavBarTop == null || screenHeight == null) return;

    assert(_overlayNavBarHeight < _inlineNavBarHeight);
    // shrink once inline navbar hits ceiling
    final double x = inlineNavBarTop + _inlineNavBarHeight; // inlineNavBarBottom
    final double minHeight = _overlayNavBarHeight;
    final double maxHeight = _inlineNavBarHeight;

    _doNavBarOverlay.value = homeBottom < 0;
    _navBarTop.value = max(inlineNavBarTop, 0.0);
    _navBarHeight.value = clampDouble(x, minHeight, maxHeight);
    _navBarFrac.value = clampDouble((maxHeight - x) / (maxHeight - minHeight), 0, 1);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateNavBarListener);
    _doNavBarOverlay.dispose();
    _navBarTop.dispose();
    _navBarHeight.dispose();
    _navBarFrac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.sizeOf(context);
    _inlineNavBarHeight = 0.20 * screenSize.height;
    _overlayNavBarHeight = 0.10 * screenSize.height;

    final navBar = NavBar(
      key: _navBarKey,
      overlayRestHeight: _overlayNavBarHeight,
      isActive: _doNavBarOverlay,
      navbarFrac: _navBarFrac,
      controller: _controller,
      viewsParentKey: _viewsParentKey,
    );

    final footerHeight = 0.08 * screenSize.height;
    List<Widget> scrollContent = [];
    for (int i = 0; i < views.length; ++i) {
      if (i == 0) {
        scrollContent.add(
          SizedBox(
            key: _firstScreenKey,
            height: screenSize.height,
            child: Column(
              children: [
                Expanded(
                  child: views[i],
                ),
                SizedBox(
                  key: _inlineNavBarKey,
                  height: _inlineNavBarHeight,
                  // While it lives here it is inside the scroll view, so a
                  // wheel over it still scrolls the page. It only moves to the
                  // overlay once it has to stick, and that flip happens once,
                  // not on every scroll frame.
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _doNavBarOverlay,
                    builder: (context, overlay, child) => overlay ? const SizedBox.shrink() : child!,
                    child: navBar,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (i < views.length - 1) {
        scrollContent.add(views[i]);
        scrollContent.add(const SizedBox(height: 50)); // TODO add space to top of each view (instead of between views) for more space between navbar and view when auto-scrolling
      } else {
        scrollContent.add(
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenSize.height - _overlayNavBarHeight - footerHeight),
            child: views[i],
          ),
        );
      }
    }

    // double scale = min(0.9 * screenSize.width * 0.15, screenSize.height * 0.4) / 220.5; // match ViewHome
    // return Listener(
    //   // onPointerSignal: _smoothScroller.onPointerSignal,
    return Stack(
      children: [
        ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(accentColor),
            trackColor: WidgetStateProperty.all(Color(0xCF000000)),
          ),
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8.0,
            radius: const Radius.circular(4.0),
            interactive: true,
            child: SingleChildScrollView(
              controller: _controller, //_smoothScroller.controller,
              // physics: const ClampingScrollPhysics(), // BouncingScrollPhysics(), // _smoothScroller.physics,
              child: Column(
                children: [
                  ParallaxScroller(
                    parallaxRatio: 0.2,
                    // RepaintBoundary gives the backdrop its own layer so the
                    // boot fade-in re-composites it instead of pulling it into
                    // a full-screen repaint of the page.
                    // filterQuality is low, not high. High is cubic: sixteen
                    // texture samples per pixel across a 3774x2041 viewport,
                    // every frame, and it was the dominant cost in every
                    // measurement -- 53 frames over 50ms against 11 without it.
                    // Note that medium would buy nothing here: its mipmaps only
                    // help when minifying, and this backdrop is upscaled.
                    background: _backdrop(),
                    child: SizedBox(
                      width: screenSize.width,
                      child: Column(
                        key: _viewsParentKey,
                        children: scrollContent,
                      ),
                    ),
                  ),
                  Container(
                    height: footerHeight,
                    color: const Color(0xFF000000), // const Color(0xFF4E423F),
                    padding: EdgeInsets.only(left: 20.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LinkText(
                        style: TextStyle(color: Colors.white),
                        line: ['Photography by ', 'Dalton Beeler', () => launchUrl(Uri.parse('https://dbshots.myportfolio.com/'))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Positioned.fill rather than a Positioned whose top and height are
        // rebuilt: the geometry now changes inside the builder, so a scroll
        // repaints this one subtree instead of the whole page. Empty space
        // inside the fill hit-tests through, so only the bar itself takes
        // pointers, exactly as before.
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: _doNavBarOverlay,
            child: navBar,
            builder: (context, overlay, child) => !overlay
                ? const SizedBox.shrink()
                : AnimatedBuilder(
                    animation: _navBarGeometry,
                    child: child,
                    builder: (context, bar) => Align(
                      alignment: Alignment.topLeft,
                      child: Transform.translate(
                        offset: Offset(0, _navBarTop.value),
                        child: SizedBox(
                          width: screenSize.width,
                          height: _navBarHeight.value,
                          child: bar,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class NavBar extends StatefulWidget {
  final double overlayRestHeight;
  final ValueListenable<bool> isActive;
  final ValueListenable<double> navbarFrac;
  final ScrollController controller;
  final GlobalKey viewsParentKey;

  const NavBar({super.key, required this.overlayRestHeight, required this.isActive, required this.navbarFrac, required this.controller, required this.viewsParentKey});

  @override
  State<StatefulWidget> createState() => _NavBarState();
}

class _NavBarState extends AnimatedState<NavBar> with TickerProviderStateMixin {
  int? _prevActiveIndex = 0; // just to be same as _activeIndex at start
  int? _activeIndex = 0;
  int? _clickedIndex;
  static const Duration animationDurationActive = Duration(milliseconds: 200);
  static const Duration animationDurationClicked = Duration(milliseconds: 600);

  late final _activeColorController = AnimationController(vsync: this, duration: animationDurationActive)..autoDispose(this);
  late final _clickedColorController = AnimationController(vsync: this, duration: animationDurationClicked)..autoDispose(this);
  late final Listenable _listenable = Listenable.merge([_activeColorController, _clickedColorController, widget.isActive, widget.navbarFrac]);

  final _inactiveColor = Colors.grey[400]!.withValues(alpha: 0.75);
  final _activeColor = accentColor;
  final _clickedColor = const Color(0xFFFFCE3D);

  // TODO override all `jump to`s with animateTo (for mouse scrolling)
  void _animateTo(BuildContext context, GlobalKey viewKey) {
    final screenHeight = MediaQuery.of(context).size.height;
    final rbView = viewKey.currentContext!.findRenderObject() as RenderBox;
    final rbParent = widget.viewsParentKey.currentContext!.findRenderObject() as RenderBox;
    double targetOffset = rbView.localToGlobal(Offset.zero, ancestor: rbParent).dy - widget.overlayRestHeight;
    var position = widget.controller.position;
    targetOffset = clampDouble(targetOffset, position.minScrollExtent, position.maxScrollExtent); // controller.animateTo automatically does this but I want to ensure duration is updated too
    widget.controller.animateTo(
      targetOffset,
      duration: Duration(milliseconds: (700 * sqrt(((targetOffset - widget.controller.position.pixels) / screenHeight).abs())).round()),
      curve: Curves.easeInOut,
    );
  }

  void _whichActiveListener() {
    var context = views.firstOrNull?.globalKey.currentContext;
    double? screenHeight = context != null ? MediaQuery.maybeHeightOf(context) : null;
    assert(screenHeight != null, 'help! screenHeight == null');
    if (screenHeight == null) return;
    double middleScreen = screenHeight / 2;
    int? activeIndex;
    for (int i = 0; i < views.length; ++i) {
      GlobalKey key = views[i].globalKey;
      var rb = key.currentContext?.findRenderObject() as RenderBox?;
      if (rb == null || !rb.hasSize) continue;
      var top = rb.localToGlobal(Offset.zero);
      var bottom = rb.localToGlobal(Offset(0, rb.size.height));
      if (top.dy <= middleScreen && middleScreen <= bottom.dy) {
        assert(activeIndex == null, 'there can only be one!');
        activeIndex = i;
        // break; comment to ensure there aren't multiple
      }
    }
    if (_activeIndex != activeIndex) {
      _prevActiveIndex = _activeIndex;
      _activeIndex = activeIndex;
      _activeColorController.forward(from: 0); // .start()?
      // controller already updates state so no need for setState
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_whichActiveListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_whichActiveListener);
    super.dispose();
  }

  Color getColor(List<int> indicesToConsider) {
    bool isClicked = indicesToConsider.contains(_clickedIndex);
    bool isActive = indicesToConsider.contains(_activeIndex);
    bool isPrevActive = indicesToConsider.contains(_prevActiveIndex);
    double acv = _activeColorController.value;

    Color color2;
    if (isActive && isPrevActive) {
      color2 = Color.lerp(_inactiveColor, _activeColor, max(acv, 1 - acv))!; // active takes priority over inactive
    } else if (isActive) {
      color2 = Color.lerp(_inactiveColor, _activeColor, acv)!;
    } else if (isPrevActive) {
      color2 = Color.lerp(_inactiveColor, _activeColor, 1 - acv)!;
    } else {
      color2 = _inactiveColor;
    }
    return isClicked ? Color.lerp(_clickedColor, color2, _clickedColorController.value)! : color2;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> buttons = List.generate(
      views.length,
      (i) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              _clickedColorController.reset();
              _clickedIndex = i;
              _clickedColorController.forward();
              // I want to set _clickedIndex = null at end of animation but user may click same button multiple times in a row, and this actually works just fine because end of animation effectively ignores _clickedIndex anyway
              _animateTo(context, views[i].globalKey);
            },
            child: AnimatedBuilder(
              animation: _listenable,
              builder: (context, child) {
                Color mainColor = getColor([i]);
                Color leftColor = getColor([i, i - 1]);
                Color rghtColor = getColor([i, i + 1]);
                double widthT = widget.isActive.value ? 2 : 0;
                double widthB = widget.isActive.value ? 2 : 0;
                double widthL = (i == 0) ? 2 : 1;
                double widthR = (i == views.length - 1) ? 2 : 1;
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: mainColor, width: widthT),
                      bottom: BorderSide(color: mainColor, width: widthB),
                      left: BorderSide(color: leftColor, width: widthL),
                      right: BorderSide(color: rghtColor, width: widthR),
                    ),
                  ),
                  child: SizedBox.expand(
                    child: FittedBox(
                      child: Container(
                        width: 101.2, // see lib/measure_nav_bar_icons.dart max width/height for all buttons (before FittedBox scaling)
                        height: 77.0,
                        padding: const EdgeInsets.all(4),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                views[i].icon,
                                color: mainColor,
                                size: 50, // TODO make smaller for projects icon cuz it looks wack
                              ),
                              const SizedBox(height: 4),
                              Text(
                                views[i].name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: mainColor,
                                  fontSize: 15,
                                  height: 1,
                                  fontWeight: FontWeight.w400,
                                ),
                                // maxLines: 1,
                                // overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).toList();

    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        alignment: Alignment.topCenter,
        widthFactor: 0.9, // match ViewHome
        // Only the backdrop colour depends on the scroll position, and the
        // buttons ride through in the child slot, so a scroll repaints this
        // one Container instead of rebuilding the bar.
        child: AnimatedBuilder(
          animation: _listenable,
          child: Row(
            children: buttons.map((button) => Expanded(child: button)).toList(),
          ),
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              color: Color.lerp(Colors.black.withValues(alpha: 0.5), Colors.black, widget.navbarFrac.value)!,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
