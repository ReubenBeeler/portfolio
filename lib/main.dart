import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:portfolio/bootstrapper.dart';
import 'package:portfolio/widgets/link_text.dart';
import 'package:portfolio/widgets/parallax_scroller.dart';
import 'package:portfolio/widgets/my_view.dart';
import 'package:portfolio/views/view_certifications.dart';
import 'package:portfolio/views/view_home.dart';
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
  debugProfileBuildsEnabled = true;
  debugProfilePaintsEnabled = true;

  assert(views.isNotEmpty);
  const String title = "Reuben's Portfolio";
  final loadKey = GlobalKey();

  final images = [
    // maybe don't pre-cache all?
    NetworkImage('assets/background.webp'),
    NetworkImage('assets/github_logo_clean.webp'),
    NetworkImage('assets/IBM Applied DevOps Engineering Certificate.webp'),
    NetworkImage('assets/java_badge.webp'),
    NetworkImage('assets/keylogging_thumbnail.webp'),
    NetworkImage('assets/linkedin_circle.webp'),
    NetworkImage('assets/PAOA vs QAOA thumbnail.webp'),
    NetworkImage('assets/profile_pic.webp'),
  ];
  runApp(
    MaterialApp(
      title: title,
      color: accentColor,
      // theme: ...
      home: Bootstrapper(
        // TODO remove pubspec.yaml assets and load from web/ so that Bootstrapper animation runs while we load assets instead of waiting until app + assets bundle is loaded
        precache: (context) async {
          for (var view in views) {
            view.precache?.call();
          }
          // TODO merge these images into specific view precache
          for (var imageProvider in images) {
            await precacheImage(imageProvider, context);
          }
        },
        child: () => Scaffold(
          key: loadKey, // to prevent re-initializing state immediately after fade-in by bootstrapper
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

class _ViewControllerState extends AnimatedState<_ViewController> with SingleTickerProviderStateMixin {
  // late final SmoothScroller _smoothScroller = SmoothScroller(scrollDirection: Axis.vertical, vsync: this);
  late final ScrollController _controller = ScrollController()..addListener(_updateNavBarListener);
  final GlobalKey _navBarKey = GlobalKey(); // for keeping state across switch between inline and overlay
  final GlobalKey _inlineNavBarKey = GlobalKey();
  final GlobalKey _viewsParentKey = GlobalKey();
  final GlobalKey _firstScreenKey = GlobalKey();
  late double _inlineNavBarHeight;
  late double _overlayNavBarHeight;
  bool _doNavBarOverlay = false;
  double? _currentNavBarTop;
  double? _currentNavBarHeight;
  double _navBarFrac = 0;

  void _updateNavBarListener() {
    double? homeBottom = getBottomFromRenderBox(views.first.globalKey);
    double? inlineNavBarTop = getTopFromRenderBox(_inlineNavBarKey);
    double? screenHeight = MediaQuery.maybeHeightOf(context);
    if (homeBottom != null && inlineNavBarTop != null && screenHeight != null) {
      double x, minHeight, maxHeight;
      // if (_inlineNavBarHeight < _overlayNavBarHeight) {
      //   // expand once inline navbar leaves floor
      //   x = screenHeight - homeBottom;
      //   minHeight = _inlineNavBarHeight;
      //   maxHeight = _overlayNavBarHeight;
      // }
      assert(_overlayNavBarHeight < _inlineNavBarHeight);
      // shrink once inline navbar hits ceiling
      x = inlineNavBarTop + _inlineNavBarHeight; // inlineNavBarBottom
      minHeight = _overlayNavBarHeight;
      maxHeight = _inlineNavBarHeight;

      bool doNavBarOverlay = homeBottom < 0; // _controller.position.hasPixels && _controller.position.pixels > 0;
      double currentNavBarTop = max(inlineNavBarTop, 0.0);
      double currentNavBarHeight = clampDouble(x, minHeight, maxHeight);
      double navBarFrac = clampDouble((maxHeight - x) / (maxHeight - minHeight), 0, 1);

      if (_doNavBarOverlay != doNavBarOverlay || _currentNavBarTop != currentNavBarTop || _currentNavBarHeight != currentNavBarHeight || _navBarFrac != navBarFrac) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => setState(() {
            _doNavBarOverlay = doNavBarOverlay;
            _currentNavBarTop = currentNavBarTop;
            _currentNavBarHeight = currentNavBarHeight;
            _navBarFrac = navBarFrac;
          }),
        ); // TODO replace with listenables
      }
    }
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
                  child: _doNavBarOverlay ? null : navBar,
                ),
              ],
            ),
          ),
        );
      } else if (i < views.length - 1) {
        scrollContent.add(views[i]);
        scrollContent.add(const SizedBox(height: 50));
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
                    background: Image.network(
                      background_path,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
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
                    color: const Color(0xFF4E423F),
                    padding: EdgeInsets.only(left: 20.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LinkText(
                        style: TextStyle(color: Colors.white),
                        line: ['Background photo by ', 'Dalton Beeler', () => launchUrl(Uri.parse('https://dbshots.myportfolio.com/'))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_doNavBarOverlay)
          Positioned(
            left: 0.0,
            width: screenSize.width,
            top: _currentNavBarTop,
            height: _currentNavBarHeight,
            child: navBar,
          ),
      ],
    );
  }
}

class NavBar extends StatefulWidget {
  final double overlayRestHeight;
  final bool isActive;
  final double navbarFrac;
  final ScrollController controller;
  final GlobalKey viewsParentKey;

  const NavBar({super.key, required this.overlayRestHeight, required this.isActive, required this.navbarFrac, required this.controller, required this.viewsParentKey});

  @override
  State<StatefulWidget> createState() => _NavBarState();
}

// TODO when switching between inline and overlay, NavBar gets a new state! Prevent this from happening...
class _NavBarState extends AnimatedState<NavBar> with TickerProviderStateMixin {
  int? _prevActiveIndex = 0; // just to be same as _activeIndex at start
  int? _activeIndex = 0;
  int? _clickedIndex;
  static const Duration animationDurationActive = Duration(milliseconds: 200);
  static const Duration animationDurationClicked = Duration(milliseconds: 600);

  late final _activeColorController = AnimationController(vsync: this, duration: animationDurationActive)..autoDispose(this);
  late final _clickedColorController = AnimationController(vsync: this, duration: animationDurationClicked)..autoDispose(this);
  late final Listenable _listenable = Listenable.merge([_activeColorController, _clickedColorController]);

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
      duration: Duration(milliseconds: (700 * sqrt(((targetOffset - widget.controller.position.pixels) / screenHeight).abs())).round()), // TODO set max time of e.g. 1 second
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
                double widthT = widget.isActive ? 2 : 0; // TODO set to const 2 pixels and change inactiveColor to accentColor to match divider if navbar not yet overlayed
                double widthB = widget.isActive ? 2 : 0;
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
        child: Container(
          decoration: BoxDecoration(
            color: Color.lerp(Colors.black.withValues(alpha: 0.5), Colors.black, widget.navbarFrac)!,
          ),
          child: Row(
            children: buttons.map((button) => Expanded(child: button)).toList(),
          ),
        ),
      ),
    );
  }
}
