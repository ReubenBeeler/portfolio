import 'package:flutter/material.dart';

Animation<double> linearFractionAnimation(Animation<double> parent) {
  return Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: parent, curve: Curves.linear));
}

abstract class AnimatedState<T extends StatefulWidget> extends State<T> with TickerProviderStateMixin {
  List<AnimationController> create_controllers();

  late final List<AnimationController> controllers;

  @override
  void initState() {
    super.initState();
    controllers = List.of(create_controllers());
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

class SimpleAnimationController extends AnimationController {
  late Animation<double> animation;
  final Duration? default_duration;
  SimpleAnimationController({required super.vsync, required void Function(double) update, this.default_duration}) : super(duration: default_duration) {
    super.addListener(() => update(animation.value));
  }

  TickerFuture run([Duration? duration]) {
    this.duration = duration ?? default_duration;
    animation = linearFractionAnimation(this);
    reset();
    return forward();
  }
}
