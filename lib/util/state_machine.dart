import 'package:flutter/foundation.dart';

class StateMachine<State> extends ValueNotifier {
  final Map<State, State? Function()> _evolutions;
  StateMachine(State super.start, this._evolutions);

  void update() {
    final currentState = value;
    if (_evolutions.containsKey(currentState)) {
      State? nextState = _evolutions[currentState]!.call();
      // use null to signify that we don't want to change state.
      if (nextState != null) {
        value = nextState;
      }
    }
  }
}
