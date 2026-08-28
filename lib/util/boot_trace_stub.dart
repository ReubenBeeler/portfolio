/// Non-web fallback. See boot_trace.dart.
void reportBootPhase(String name) {}

/// See boot_trace.dart. Without a page-side splash the Dart animation runs.
bool bootSplashPresent() => false;

void bootSplashFlyOut() {}

void onBootSplashDone(void Function() callback) {}
