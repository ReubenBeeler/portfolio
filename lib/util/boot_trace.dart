
/// Reports boot state transitions to a page-side profiler, when one is present.
///
/// Nothing installs `window.__bootPhase` unless the page was opened with
/// `?profile`, so in a normal load this is one property lookup per boot state
/// transition: six per boot, total.
///
/// It exists so the deployed build can be profiled on its real host, over a
/// real network, on a real device. Boot timing measured against localhost is
/// not the same measurement.
library;
export 'boot_trace_stub.dart' if (dart.library.js_interop) 'boot_trace_web.dart';
