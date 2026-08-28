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

/// Whether index.html is running the loading animation. When it is, Dart skips
/// its own fly-in/wait/fly-out and only fades the page up at the end.
bool bootSplashPresent() {
  try {
    return globalContext.getProperty<JSAny?>('__splashFlyOut'.toJS) != null;
  } catch (_) {
    return false;
  }
}

/// Tells the page-side splash the app is ready, so it can fly the letters out.
void bootSplashFlyOut() {
  try {
    final hook = globalContext.getProperty<JSAny?>('__splashFlyOut'.toJS);
    if (hook != null) (hook as JSFunction).callAsFunction(null);
  } catch (_) {}
}

/// Registers the callback the splash invokes once the letters have left.
void onBootSplashDone(void Function() callback) {
  try {
    globalContext.setProperty('__splashDone'.toJS, callback.toJS);
  } catch (_) {}
}
