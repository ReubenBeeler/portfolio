import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// See boot_trace.dart.
void reportBootPhase(String name) {
  try {
    final hook = globalContext.getProperty<JSAny?>('__bootPhase'.toJS);
    if (hook != null) (hook as JSFunction).callAsFunction(null, name.toJS);
  } catch (_) {
    // A profiler hook must never be able to break a boot.
  }
}
