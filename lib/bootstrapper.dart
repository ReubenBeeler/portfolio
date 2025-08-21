import 'package:flutter/material.dart';

late ValueNotifier<Offset> mouseGlobalPosition;

class Bootstrapper extends StatefulWidget {
  final Widget loader;
  final Widget? child;

  const Bootstrapper({super.key, this.loader = const ColoredBox(color: Colors.transparent, child: SizedBox.expand()), this.child});

  @override
  State<Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<Bootstrapper> {
  bool booted = false;
  void updateMouseGlobalPosition(PointerEvent event) {
    if (!booted) {
      mouseGlobalPosition = ValueNotifier(event.position);
      setState(() => booted = true); // boot child
    } else {
      mouseGlobalPosition.value = event.position;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: updateMouseGlobalPosition,
      onPointerHover: updateMouseGlobalPosition,
      onPointerDown: updateMouseGlobalPosition,
      onPointerCancel: updateMouseGlobalPosition,
      onPointerUp: updateMouseGlobalPosition,
      onPointerPanZoomUpdate: updateMouseGlobalPosition,
      onPointerPanZoomEnd: updateMouseGlobalPosition,
      onPointerPanZoomStart: updateMouseGlobalPosition,
      onPointerSignal: updateMouseGlobalPosition,
      behavior: HitTestBehavior.translucent,
      child: booted ? widget.child : widget.loader,
    );
  }
}
