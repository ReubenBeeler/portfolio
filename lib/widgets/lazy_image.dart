import 'package:flutter/material.dart';
import 'package:portfolio/bootstrapper.dart' show appBooted;

/// An image that never blocks layout on its own download.
///
/// [aspectRatio] reserves the final size from the first frame, so a slow image
/// cannot reflow the page when it arrives. Until it decodes, [placeholder] is
/// shown; the decoded image then cross-fades over it.
class LazyImage extends StatefulWidget {
  final ImageProvider image;
  final double? aspectRatio;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Duration fadeDuration;
  final Widget? placeholder;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Hold the request until the boot screen has handed over. For anything below
  /// the fold this costs the viewer nothing and keeps the download and the
  /// decode off the hand-over animation.
  final bool deferUntilBooted;

  /// Decode at the size this actually occupies rather than at the file's full
  /// resolution. A 2730x2030 thumbnail drawn 760px wide is 13x more pixels than
  /// anyone sees, all of them decoded and uploaded to the GPU.
  final bool decodeToFit;

  const LazyImage({
    super.key,
    required this.image,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
    this.fadeDuration = const Duration(milliseconds: 400),
    this.placeholder,
    this.errorBuilder,
    this.deferUntilBooted = false,
    this.decodeToFit = false,
  });

  @override
  State<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<LazyImage> {
  bool _faded = false;

  Widget _placeholder() => widget.placeholder ?? const UnloadedImagePlaceholder();

  Widget _image(ImageProvider provider) {
    return Image(
      image: provider,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: widget.errorBuilder,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || _faded) return child;
        final bool decoded = frame != null;
        return Stack(
          fit: StackFit.expand,
          children: [
            _placeholder(),
            AnimatedOpacity(
              opacity: decoded ? 1 : 0,
              duration: widget.fadeDuration,
              curve: Curves.easeOut,
              onEnd: () {
                if (decoded && !_faded && mounted) setState(() => _faded = true);
              },
              child: child,
            ),
          ],
        );
      },
    );
  }

  Widget _sized(BuildContext context) {
    if (!widget.decodeToFit) return _image(widget.image);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) return _image(widget.image);
        // Bucketed so that dragging a window edge does not re-decode on
        // every frame of the resize.
        final int px = ((constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)) / 256).ceil() * 256;
        return _image(ResizeImage(widget.image, width: px, allowUpscaling: false));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.deferUntilBooted
        ? ValueListenableBuilder<bool>(
            valueListenable: appBooted,
            builder: (context, booted, _) => booted ? _sized(context) : _placeholder(),
          )
        : _sized(context);

    return widget.aspectRatio == null ? content : AspectRatio(aspectRatio: widget.aspectRatio!, child: content);
  }
}

/// Muted stand-in that reads as "this image has not arrived yet".
class UnloadedImagePlaceholder extends StatelessWidget {
  const UnloadedImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x14FFFFFF),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}
