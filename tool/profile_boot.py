#!/usr/bin/env python3
"""
Boot-path profiler for the portfolio's Flutter web app.

Run this on a machine with a real GPU. It builds the app twice (the current
working tree, and HEAD as a baseline), serves each build over plain HTTP with a
small instrumentation script injected into index.html, drives a real Chrome
window through several boot cycles, and prints one pasteable report.

    python3 tool/profile_boot.py

Nothing is installed and nothing in your repo is modified: each build happens in
a throwaway copy under a temp directory. Takes roughly 10-20 minutes, most of it
waiting on two release+wasm builds.

Useful flags:
    --quick            current build only, 2 runs (skips the baseline build)
    --no-baseline      current build only, full run count
    --runs N           runs per variant (default 3: one cold, rest warm)
    --net 3g|4g|slow   shape the local link. localhost has zero latency and
                       infinite bandwidth, which hides everything that only
                       goes wrong when assets arrive slowly
    --dir PATH         profile an already-built directory, skip building
    --chrome PATH      explicit Chrome binary
    --keep             leave the temp build dirs in place

This measures a LOCAL build. To measure the deployed site on its real host,
over a real network, on a real device, open the site with ?profile instead:

    https://reubenbeeler.me/?profile

That path needs no tooling at all: the profiler ships in index.html, inert
unless that query parameter is present, and prints a pasteable report.

While it runs: leave the Chrome window visible and in the foreground. A
backgrounded tab is throttled by the browser and the numbers become meaningless.
"""

import argparse
import http.server
import json
import os
import platform
import re
import shutil
import socket
import socketserver
import statistics
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

# --------------------------------------------------------------------------
# instrumentation injected into index.html
# --------------------------------------------------------------------------

INSTRUMENT = r"""
<script>
(function () {
  'use strict';
  function r1(x) { return Math.round(x * 10) / 10; }

  // Run index and document-load count are stamped in by the server when it
  // serves index.html. sessionStorage is unreliable here because the
  // coi-serviceworker reload dance can land us in a fresh session.
  var run = __RUN__;
  var navs = __NAVS__;
  var COI_MODE = '__COI__';

  // coi-serviceworker reloads the page until cross-origin isolation sticks.
  // That is real production behaviour and worth measuring, but it can also get
  // stuck in a loop. This script runs before it, so we can bound it.
  if (COI_MODE === 'off' || navs > 5) {
    window.coi = {
      shouldRegister: function () { return false; },
      coepDegrade: function () { return false; },
      doReload: function () {}
    };
  }

  // coi-serviceworker narrates what it does on the console; keep it.
  var logs = [];
  ['log', 'warn', 'error'].forEach(function (lvl) {
    var orig = console[lvl];
    console[lvl] = function () {
      try {
        if (logs.length < 60) {
          logs.push(lvl + ': ' + Array.prototype.map.call(arguments, String).join(' ').slice(0, 200));
        }
      } catch (e) {}
      return orig.apply(console, arguments);
    };
  });

  var frames = [];
  var loaf = [];
  var longtasks = [];
  var phases = [];
  var finished = false;
  var HARD_CAP_MS = 120000;

  // The Dart side calls this on every boot state transition. Only present in
  // builds made by this script; absent builds simply report no phases.
  window.__bootPhase = function (name) {
    name = String(name);
    phases.push([r1(performance.now()), name]);
    if (name === 'BOOTED') waitForQuiet();
  };


  // A resource entry only exists once its request has finished, so a single
  // large download in flight is indistinguishable from an idle network.
  // Count requests directly instead.
  var inflight = 0;
  try {
    var _fetch = window.fetch;
    if (_fetch) window.fetch = function () {
      inflight++;
      var dec = function () { inflight--; };
      var p;
      try { p = _fetch.apply(this, arguments); } catch (e) { dec(); throw e; }
      return p.then(function (r) { dec(); return r; }, function (e) { dec(); throw e; });
    };
  } catch (e) {}
  try {
    var _send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function () {
      var self = this;
      inflight++;
      var dec = function () { if (!self.__bpCounted) { self.__bpCounted = true; inflight--; } };
      try { self.addEventListener('loadend', dec); } catch (e) {}
      try { return _send.apply(this, arguments); } catch (e) { dec(); throw e; }
    };
  } catch (e) {}

  // The backdrop and the off-screen thumbnails start downloading at mount and
  // are still in flight when the boot screen leaves. Reporting 800ms after
  // handover counted neither their bytes nor the frames they cost.
  var QUIET_MS = 2500, TAIL_CAP_MS = 30000, tailCapped = false;
  function waitForQuiet() {
    var bootedAt = performance.now(), seen = -1, lastChange = bootedAt;
    (function poll() {
      if (finished) return;
      var n = 0, now = performance.now();
      try { n = performance.getEntriesByType('resource').length; } catch (e) {}
      if (n !== seen) { seen = n; lastChange = now; }
      if (inflight === 0 && now - lastChange >= QUIET_MS) return finish();
      if (now - bootedAt >= TAIL_CAP_MS) { tailCapped = true; return finish(); }
      setTimeout(poll, 250);
    })();
  }

  function tick(ts) {
    frames.push(Math.round(ts * 100) / 100);
    if (!finished) requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);

  function observe(type, sink, map) {
    try {
      new PerformanceObserver(function (list) {
        list.getEntries().forEach(function (e) { sink.push(map(e)); });
      }).observe({ type: type, buffered: true });
    } catch (e) { /* type unsupported in this Chrome */ }
  }
  observe('long-animation-frame', loaf, function (e) {
    return [r1(e.startTime), r1(e.duration), r1(e.blockingDuration || 0)];
  });
  observe('longtask', longtasks, function (e) {
    return [r1(e.startTime), r1(e.duration)];
  });

  var wasHidden = document.visibilityState === 'hidden';
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'hidden') wasHidden = true;
  });

  function gpuInfo() {
    try {
      var c = document.createElement('canvas');
      var gl2 = c.getContext('webgl2');
      var gl = gl2 || c.getContext('webgl');
      if (!gl) return { webgl: false };
      var dbg = gl.getExtension('WEBGL_debug_renderer_info');
      var out = {
        webgl: true,
        webgl2: !!gl2,
        vendor: dbg ? gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR),
        renderer: dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER)
      };
      var lose = gl.getExtension('WEBGL_lose_context');
      if (lose) lose.loseContext();
      return out;
    } catch (e) { return { webgl: false, error: String(e) }; }
  }

  function timings() {
    var out = { paint: {}, nav: null, resources: [] };
    try {
      performance.getEntriesByType('paint').forEach(function (e) { out.paint[e.name] = r1(e.startTime); });
    } catch (e) {}
    try {
      var n = performance.getEntriesByType('navigation')[0];
      if (n) out.nav = { type: n.type, dcl: r1(n.domContentLoadedEventEnd), load: r1(n.loadEventEnd),
                         bytes: n.transferSize || n.encodedBodySize || 0 };
    } catch (e) {}
    try {
      performance.getEntriesByType('resource').forEach(function (e) {
        out.resources.push([r1(e.startTime), r1(e.responseEnd), e.transferSize || 0, e.name, e.encodedBodySize || 0]);
      });
    } catch (e) {}
    return out;
  }

  function banner(text, ok) {
    var d = document.createElement('div');
    d.textContent = text;
    d.setAttribute('style',
      'position:fixed;z-index:2147483647;left:0;right:0;top:0;padding:14px 18px;' +
      'font:600 15px/1.4 ui-monospace,Menlo,Consolas,monospace;text-align:center;' +
      'background:' + (ok ? '#0b3d2e' : '#4a1410') + ';color:#eafff6;');
    document.body.appendChild(d);
  }

  function finish() {
    if (finished) return;
    finished = true;
    var t = timings();
    var payload = {
      run: run,
      navs: navs,
      wasHidden: wasHidden,
      elapsed: r1(performance.now()),
      ua: navigator.userAgent,
      cores: navigator.hardwareConcurrency || null,
      mem: navigator.deviceMemory || null,
      dpr: window.devicePixelRatio,
      vw: window.innerWidth,
      vh: window.innerHeight,
      coi: !!window.crossOriginIsolated,
      tailCapped: tailCapped,
      logs: logs,
      gpu: gpuInfo(),
      paint: t.paint,
      nav: t.nav,
      resources: t.resources,
      frames: frames,
      loaf: loaf,
      longtasks: longtasks,
      phases: phases
    };
    fetch('/__result', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    }).then(function (r) { return r.json(); })
      .then(function (j) {
        if (j && j.again) {
          setTimeout(function () { location.reload(); }, 500);
        } else {
          banner('profiling complete - you can close this window', true);
        }
      })
      .catch(function (e) {
        banner('could not reach the profiler: ' + e, false);
      });
  }

  setTimeout(finish, HARD_CAP_MS);
})();
</script>
"""

# --------------------------------------------------------------------------
# discovery helpers
# --------------------------------------------------------------------------

CHROME_CANDIDATES = {
    "Darwin": [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
    ],
    "Linux": [
        "/usr/bin/google-chrome",
        "/usr/bin/google-chrome-stable",
        "/usr/bin/chromium",
        "/usr/bin/chromium-browser",
        "/snap/bin/chromium",
    ],
    "Windows": [
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    ],
}


def find_chrome(explicit=None):
    if explicit:
        if Path(explicit).exists():
            return explicit
        die(f"--chrome path does not exist: {explicit}")
    env = os.environ.get("CHROME")
    if env and Path(env).exists():
        return env
    for c in CHROME_CANDIDATES.get(platform.system(), []):
        if Path(c).exists():
            return c
    for name in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "chrome"):
        p = shutil.which(name)
        if p:
            return p
    die("Could not find Chrome. Pass --chrome /path/to/chrome or set $CHROME.")


def run_cmd(args, cwd=None, capture=True):
    return subprocess.run(
        args, cwd=cwd, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )


def version_of(cmd_args, pattern=r"(\d+\.\d+\.\d+)"):
    try:
        r = run_cmd(cmd_args)
        out = (r.stdout or "").strip()
        m = re.search(pattern, out)
        return out.splitlines()[0].strip() if not m else out.splitlines()[0].strip()
    except Exception:
        return "unknown"


def die(msg):
    print(f"\n  ERROR: {msg}\n", file=sys.stderr)
    sys.exit(1)


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def step(msg):
    print(f"\n>> {msg}", flush=True)


# --------------------------------------------------------------------------
# building
# --------------------------------------------------------------------------


BOOT_HOOK_CALL = "..addListener(() => reportBootPhase(state.name))"


def ensure_boot_hook(src_root: Path, repo: Path):
    """lib/util/boot_trace.dart is part of the app now, so normally there is
    nothing to do. A tree that predates it (an older HEAD, say) gets the files
    copied in and the one call site added, so both variants report phases and
    stay comparable."""
    lib = src_root / "lib" / "util"
    boot = src_root / "lib" / "bootstrapper.dart"
    if not boot.exists():
        return
    text = boot.read_text("utf-8")
    if BOOT_HOOK_CALL in text:
        return
    for name in ("boot_trace.dart", "boot_trace_stub.dart", "boot_trace_web.dart"):
        src = repo / "lib" / "util" / name
        if not src.exists():
            print("   note: boot_trace files not found; this variant will report no phases")
            return
        lib.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, lib / name)
    anchor = "        ..addListener(_stateMachineListener)"
    if anchor not in text:
        print("   note: could not add the phase hook; this variant will report no phases")
        return
    if "boot_trace.dart" not in text:
        text = "import 'util/boot_trace.dart';\n" + text
    text = text.replace(anchor, "        " + BOOT_HOOK_CALL + "\n" + anchor, 1)
    boot.write_text(text, "utf-8")
    print("   added the boot phase hook to this variant (it predates boot_trace.dart)")


COPY_SKIP = {".git", "build", ".dart_tool", ".devcontainer", "node_modules", "__pycache__"}


def copy_worktree(repo: Path, dest: Path):
    def ignore(d, names):
        if Path(d) == repo:
            return [n for n in names if n in COPY_SKIP]
        return [n for n in names if n in {".dart_tool", "build", "__pycache__"}]
    shutil.copytree(repo, dest, symlinks=True, ignore=ignore)


def export_head(repo: Path, dest: Path):
    dest.mkdir(parents=True, exist_ok=True)
    tar = subprocess.run(["git", "archive", "HEAD"], cwd=repo, stdout=subprocess.PIPE)
    if tar.returncode != 0:
        raise RuntimeError("git archive HEAD failed")
    extract = subprocess.run(["tar", "-x", "-C", str(dest)], input=tar.stdout)
    if extract.returncode != 0:
        raise RuntimeError("tar extract failed")
    # HEAD pins google_fonts 6.3.0, which does not compile on current stable
    # Flutter. Carry the working tree's lockfile across so the baseline builds.
    lock = repo / "pubspec.lock"
    if lock.exists():
        shutil.copy2(lock, dest / "pubspec.lock")


def build(src: Path, label: str) -> Path:
    step(f"building '{label}' (flutter build web --release --wasm --pwa-strategy=none)"
         f" - this is the slow part")
    r = run_cmd(["flutter", "pub", "get"], cwd=src)
    if r.returncode != 0:
        print(r.stdout)
        raise RuntimeError(f"{label}: flutter pub get failed")
    r = run_cmd(["flutter", "build", "web", "--release", "--wasm", "--pwa-strategy=none"], cwd=src)
    if r.returncode != 0:
        print((r.stdout or "")[-4000:])
        raise RuntimeError(f"{label}: flutter build failed")
    out = src / "build" / "web"
    if not (out / "index.html").exists():
        raise RuntimeError(f"{label}: build produced no index.html")
    print(f"   built -> {out}")
    return out


# --------------------------------------------------------------------------
# serving + driving
# --------------------------------------------------------------------------


class RateLimiter:
    """One shared pipe across all connections, so the cap is the link speed and
    not the per-connection speed. Chrome opens several sockets; without this,
    '1.6 Mbps' would silently mean six times that."""

    def __init__(self, bytes_per_sec):
        self.bps = bytes_per_sec
        self.lock = threading.Lock()
        self.free_at = time.monotonic()

    def consume(self, n):
        if not self.bps:
            return
        with self.lock:
            now = time.monotonic()
            if self.free_at < now:
                self.free_at = now
            self.free_at += n / self.bps
            finish = self.free_at
        delay = finish - time.monotonic()
        if delay > 0:
            time.sleep(delay)


NET_PRESETS = {
    "none": (0, 0),
    "cable": (25, 20000),
    "4g": (70, 9000),
    "3g": (150, 1600),
    "slow": (300, 400),
}


class Collector:
    def __init__(self, total_runs):
        self.total_runs = total_runs
        self.results = []
        self.event = threading.Event()
        self.lock = threading.Lock()
        self.navs = 0


class Handler(http.server.SimpleHTTPRequestHandler):
    serve_dir = None
    collector = None
    coi_mode = "auto"
    latency_ms = 0
    limiter = RateLimiter(0)

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(Handler.serve_dir), **kw)

    def log_message(self, *a):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def copyfile(self, source, outputfile):
        if not Handler.limiter.bps:
            return super().copyfile(source, outputfile)
        while True:
            buf = source.read(16384)
            if not buf:
                return
            Handler.limiter.consume(len(buf))
            outputfile.write(buf)

    def do_GET(self):
        if Handler.latency_ms:
            time.sleep(Handler.latency_ms / 1000.0)
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
            col = Handler.collector
            with col.lock:
                col.navs += 1
                run = len(col.results) + 1
                navs = col.navs
            html = (Handler.serve_dir / "index.html").read_text("utf-8")
            script = (INSTRUMENT.replace("__RUN__", str(run))
                                .replace("__NAVS__", str(navs))
                                .replace("__COI__", Handler.coi_mode))
            if "<head>" in html:
                html = html.replace("<head>", "<head>\n" + script, 1)
            else:
                html = script + html
            body = html.encode("utf-8")
            Handler.limiter.consume(len(body))
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        return super().do_GET()

    def do_POST(self):
        if self.path.split("?")[0] != "/__result":
            self.send_error(404)
            return
        n = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(n)
        col = Handler.collector
        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception as e:
            payload = {"error": str(e)}
        with col.lock:
            col.results.append(payload)
            col.navs = 0
            again = len(col.results) < col.total_runs
        body = json.dumps({"again": again}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        got = len(col.results)
        print(f"   run {got}/{col.total_runs} collected "
              f"({len(payload.get('frames', []))} frames, "
              f"{len(payload.get('phases', []))} phase marks)", flush=True)
        if not again:
            col.event.set()


class Server(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True


def measure(serve_dir: Path, label: str, runs: int, chrome: str, timeout: int,
            coi_mode="auto", net="none"):
    step(f"profiling '{label}': {runs} boot cycles (run 1 cold, the rest warm)")
    print("   keep the Chrome window in the FOREGROUND and do not switch tabs")
    port = free_port()
    Handler.serve_dir = serve_dir
    Handler.coi_mode = coi_mode
    lat, kbps = NET_PRESETS.get(net, (0, 0))
    Handler.latency_ms = lat
    Handler.limiter = RateLimiter(kbps * 1000 / 8.0 if kbps else 0)
    if kbps:
        print(f"   network shaping: {lat}ms latency, {kbps}kbps shared. "
              f"CPU is NOT throttled, so this only approximates a slow link")
    collector = Collector(runs)
    Handler.collector = collector
    httpd = Server(("127.0.0.1", port), Handler)
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()

    profile_dir = tempfile.mkdtemp(prefix=f"bootprof-chrome-{label}-")
    args = [
        chrome,
        f"--user-data-dir={profile_dir}",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-background-timer-throttling",
        "--disable-backgrounding-occluded-windows",
        "--disable-renderer-backgrounding",
        "--window-size=1280,900",
        "--window-position=40,40",
    ]
    args += [f for f in os.environ.get("BOOTPROF_CHROME_FLAGS", "").split() if f]
    args.append(f"http://127.0.0.1:{port}/")
    proc = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = collector.event.wait(timeout=timeout)
    if not ok:
        print(f"   TIMED OUT after {timeout}s with {len(collector.results)}/{runs} runs")
    time.sleep(1.0)
    try:
        proc.terminate()
        proc.wait(timeout=10)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
    httpd.shutdown()
    httpd.server_close()
    shutil.rmtree(profile_dir, ignore_errors=True)
    return collector.results


# --------------------------------------------------------------------------
# analysis
# --------------------------------------------------------------------------

BUDGET = 16.7
NOMINAL = {"FLY_IN": 1300, "FLY_OUT": 1300, "FADE_IN_CHILD": 1000}


def pct(values, p):
    if not values:
        return 0.0
    s = sorted(values)
    k = min(len(s) - 1, int(round((p / 100.0) * (len(s) - 1))))
    return s[k]


def intervals(frames):
    return [round(b - a, 2) for a, b in zip(frames, frames[1:]) if b > a]


def phase_windows(payload):
    """[(name, start, end)] from the Dart phase marks, else derived from timing."""
    phases = payload.get("phases") or []
    frames = payload.get("frames") or []
    end_of_boot = frames[-1] if frames else payload.get("elapsed", 0)
    # Gate flags ride the same channel but are events, not spans.
    phases = [p for p in phases if not str(p[1]).startswith(("flag:", "WATCHDOG"))]
    if phases:
        out = []
        if frames and frames[0] < phases[0][0]:
            out.append(("(before FLY_IN)", frames[0], phases[0][0]))
        for i, (t, name) in enumerate(phases):
            nxt = phases[i + 1][0] if i + 1 < len(phases) else end_of_boot
            # The trailing BOOTED window is the profiler's own rAF loop spinning
            # on an idle app. It is a sanity check: it should read ~16.7 ms on a
            # machine that can hit 60 fps at all.
            out.append(("BOOTED (post-boot tail)" if name == "BOOTED" else name, t, nxt))
        return out, "reported by the app"

    # fallback: anchor on the known controller durations
    if not frames:
        return [], "unavailable"
    ivs = intervals(frames)
    first = frames[0]
    for a, b in zip(frames, frames[1:]):
        if b - a < 100:
            first = a
            break
    fade_end = end_of_boot
    return ([
        ("FLY_IN(derived)", first, first + NOMINAL["FLY_IN"]),
        ("WAITING(derived)", first + NOMINAL["FLY_IN"], fade_end - 2300),
        ("FLY_OUT(derived)", fade_end - 2300, fade_end - 1000),
        ("FADE(derived)", fade_end - 1000, fade_end),
    ], "derived from nominal durations, approximate")


def phase_stats(payload):
    frames = payload.get("frames") or []
    wins, how = phase_windows(payload)
    rows = []
    for name, a, b in wins:
        sel = [f for f in frames if a <= f < b]
        ivs = intervals(sel)
        if not sel:
            continue
        # A phase can legitimately last one or two frames (WAITING usually does,
        # once precaching has already finished). Show it anyway: that is exactly
        # where the expensive one-off frames get parked.
        rows.append({
            "phase": name,
            "n": len(ivs),
            "p50": pct(ivs, 50) if ivs else 0.0,
            "p90": pct(ivs, 90) if ivs else 0.0,
            "max": max(ivs) if ivs else 0.0,
            "over": sum(1 for x in ivs if x > BUDGET),
            "span": round(b - a),
        })
    return rows, how


def worst_frame(payload):
    frames = payload.get("frames") or []
    wins, _ = phase_windows(payload)
    best = (0.0, "?")
    for a, b in zip(frames, frames[1:]):
        d = b - a
        if d > best[0]:
            where = next((n for n, s, e in wins if s <= a < e), "?")
            best = (d, where)
    return best




def renderer_of(payload):
    names = " ".join(r[3] for r in (payload.get("resources") or []))
    app = "wasm" if "main.dart.wasm" in names else ("dart2js FALLBACK" if "main.dart.js" in names else "?")
    eng = "skwasm" if "skwasm" in names else ("canvaskit" if "canvaskit" in names else "?")
    return app, eng


def boot_stall(payload):
    """Dead time between flutter_bootstrap.js landing and the renderer download
    starting. Flutter's bootstrap waits up to 4s for its own service worker,
    which cannot install because coi-serviceworker already owns scope '/'."""
    res = payload.get("resources") or []
    boot_end = None
    engine_start = None
    for start, end, name in ((r[0], r[1], r[3]) for r in res):
        if name.endswith("flutter_bootstrap.js"):
            boot_end = end if boot_end is None else min(boot_end, end)
    for start, end, name in ((r[0], r[1], r[3]) for r in res):
        if any(k in name for k in ("canvaskit.js", "canvaskit.wasm", "skwasm",
                                   "main.dart.wasm", "main.dart.js", "main.dart.mjs")):
            engine_start = start if engine_start is None else min(engine_start, start)
    if boot_end is None or engine_start is None:
        return None
    return round(engine_start - boot_end)


def warnings_of(payload):
    logs = payload.get("logs") or []
    out = []
    for l in logs:
        if "prepareServiceWorker" in l:
            out.append("flutter service worker timed out (blocks the renderer download)")
        if "CPU-only rendering" in l or "webGLVersion is -1" in l:
            out.append("*** Flutter fell back to CPU-only rendering: no GPU in play ***")
        if "Reloading page" in l:
            out.append("coi-serviceworker forced a reload: " + l[:120])
    return sorted(set(out))

def fmt_table(rows, indent="     "):
    if not rows:
        return indent + "(no phase data)"
    head = f"{indent}{'phase':<20}{'span':>7}{'n':>6}{'p50':>8}{'p90':>8}{'max':>9}{'>16.7ms':>10}"
    lines = [head, indent + "-" * (len(head) - len(indent))]
    for r in rows:
        if r["n"] == 0:
            lines.append(f"{indent}{r['phase']:<20}{r['span']:>6}ms{r['n']:>6}"
                         f"{'-':>9}{'-':>9}{'-':>9}{'  too short':>10}")
            continue
        lines.append(
            f"{indent}{r['phase']:<20}{r['span']:>6}ms{r['n']:>6}"
            f"{r['p50']:>7.1f}ms{r['p90']:>7.1f}ms{r['max']:>8.1f}ms"
            f"{r['over']:>6}/{r['n']:<4}"
        )
    return "\n".join(lines)


INTERESTING = ("canvaskit", "main.dart.wasm", "main.dart.js", "skwasm",
               ".ttf", ".otf", ".woff", ".webp", "AssetManifest", "FontManifest")


def waterfall(payload, limit=30):
    res = payload.get("resources") or []
    picked = [r for r in res if any(k in r[3] for k in INTERESTING)]
    picked.sort(key=lambda r: r[0])
    lines = []
    for row in picked[:limit]:
        start, end, size, name = row[0], row[1], row[2], row[3]
        encoded = row[4] if len(row) > 4 else 0
        short = name.split("/")[-1][:46]
        origin = "local" if "127.0.0.1" in name else name.split("/")[2][:22]
        shown = size if size else encoded
        kb = f"{shown/1024:.0f}K" if shown else "-"
        lines.append(f"     {start:>8.0f} -> {end:>8.0f}  {kb:>7}  {origin:<22} {short}")
    return lines


def fmt_bytes(n):
    if n >= 1024 * 1024:
        return f"{n / 1048576:.2f}MB"
    if n >= 1024:
        return f"{n / 1024:.0f}K"
    return f"{n}B"


def byte_totals(payload):
    """Bytes on the wire, and how many of them the boot screen waited on.

    Pre-boot counts every request that had finished by the BOOTED mark, so it
    is the payload standing between a cold visitor and the actual page.
    """
    res = payload.get("resources") or []
    doc = (payload.get("nav") or {}).get("bytes") or 0
    booted = next((t for t, n in (payload.get("phases") or []) if n == "BOOTED"), None)
    # transferSize reads 0 both for a cache hit and for anything a service
    # worker served, so fall back to the encoded body size.
    size = lambda r: r[2] if r[2] > 0 else (r[4] if len(r) > 4 else 0)
    total, count = doc + sum(size(r) for r in res), 1 + len(res)
    if booted is None:
        return total, count, None, None
    pre = [r for r in res if r[1] <= booted]
    return total, count, doc + sum(size(r) for r in pre), 1 + len(pre)


def image_concurrency(payload):
    """Overlap factor for the precached images.

    An absolute gap threshold is meaningless: on a fast local server a serial
    await chain still puts requests only ~20 ms apart. Compare the sum of the
    individual download durations against the wall-clock span instead. Above 1
    means the downloads overlapped; well below 1 means they were awaited one at
    a time with idle gaps in between.
    """
    res = payload.get("resources") or []
    imgs = sorted([r for r in res if r[3].endswith(".webp")], key=lambda r: r[0])
    if len(imgs) < 2:
        return None
    # keep only the first burst; later views pull their own images much later
    first = imgs[0][0]
    imgs = [r for r in imgs if r[0] - first < 1000]
    if len(imgs) < 2:
        return None
    span = max(r[1] for r in imgs) - first
    total = sum(r[1] - r[0] for r in imgs)
    factor = (total / span) if span > 0 else 0
    return len(imgs), round(factor, 2), round(span)


def summarize_variant(label, results, out):
    out.append("")
    out.append(f"=== VARIANT: {label} ===")
    if not results:
        out.append("   (no runs collected)")
        return {}
    warm_medians = {}
    for r in results:
        if "error" in r:
            out.append(f"   run ?: collection error: {r['error']}")
            continue
        cold = r.get("run") == 1
        paint = r.get("paint") or {}
        fp = paint.get("first-paint")
        fcp = paint.get("first-contentful-paint")
        phases = r.get("phases") or []
        booted = next((t for t, n in phases if n == "BOOTED"), None)
        frames = r.get("frames") or []
        ivs = intervals(frames)
        out.append("")
        out.append(f"  run {r.get('run')} [{'cold' if cold else 'warm'}]"
                   f"  document loads={r.get('navs')}"
                   f"  coi={r.get('coi')}"
                   f"  tab-hidden={r.get('wasHidden')}")
        out.append(f"     first paint {fp if fp is not None else '-'} ms"
                   f" | FCP {fcp if fcp is not None else '-'} ms"
                   f" | booted {round(booted) if booted else '-'} ms"
                   f" | frames {len(frames)}")
        total, count, pre, pren = byte_totals(r)
        capped = "  <-- still downloading 30s after boot, so total is a floor" if r.get("tailCapped") else ""
        if pre is None:
            out.append(f"     bytes: total {fmt_bytes(total)} / {count} requests"
                       f" | pre-boot n/a (boot never finished){capped}")
        else:
            out.append(f"     bytes: total {fmt_bytes(total)} / {count} requests"
                       f" | pre-boot {fmt_bytes(pre)} / {pren} ({round(100 * pre / total) if total else 0}%)"
                       f" | after boot {fmt_bytes(total - pre)} / {count - pren}{capped}")
        if ivs:
            wd, wp = worst_frame(r)
            out.append(f"     all frames: p50 {pct(ivs,50):.1f}ms  p90 {pct(ivs,90):.1f}ms"
                       f"  max {max(ivs):.1f}ms  over budget {sum(1 for x in ivs if x>BUDGET)}/{len(ivs)}")
            out.append(f"     worst single frame: {wd:.1f}ms, during {wp}")
        gates = [p for p in (r.get("phases") or []) if str(p[1]).startswith(("flag:", "WATCHDOG"))]
        if gates:
            out.append("     boot gates: " + ", ".join(f"{p[1]}@{round(p[0])}ms" for p in gates))
        missing = [g for g in ("firstFrameDone", "fontsReady", "childReady", "mountChild", "childLaidOut")
                   if not any(g in str(p[1]) for p in gates)]
        if gates and missing:
            out.append(f"     NEVER OPENED: {', '.join(missing)}  <-- what the boot was waiting on")
        rows, how = phase_stats(r)
        out.append(f"     phases ({how}):")
        out.append(fmt_table(rows))
        if not cold:
            for row in rows:
                warm_medians.setdefault(row["phase"], []).append(row["p50"])
        loaf = [e for e in (r.get("loaf") or []) if e[1] >= 50]
        if loaf:
            loaf.sort(key=lambda e: -e[1])
            top = ", ".join(f"{d:.0f}ms(blocking {b:.0f})" for _, d, b in loaf[:6])
            out.append(f"     long animation frames >=50ms: {len(loaf)} | worst: {top}")
        else:
            out.append("     long animation frames >=50ms: none")
        app, eng = renderer_of(r)
        flag = "   <-- NOT the wasm build; check the GPU line, no WebGL forces this" if "FALLBACK" in app else ""
        out.append(f"     renderer: app={app} engine={eng}{flag}")
        stall = boot_stall(r)
        if stall is not None:
            flag = "  <-- dead time on the critical path" if stall > 300 else ""
            out.append(f"     gap between flutter_bootstrap.js and the renderer download: {stall} ms{flag}")
        for w in warnings_of(r):
            out.append(f"     ! {w}")
        if cold:
            conc = image_concurrency(r)
            if conc:
                n, factor, span = conc
                verdict = "concurrent" if factor >= 1.0 else "SERIALISED / awaited one at a time"
                out.append(f"     {n} precached .webp images: overlap factor {factor} ({verdict}), "
                           f"whole batch took {span}ms")
            wf = waterfall(r)
            if wf:
                out.append("     cold load waterfall (ms from navigation start):")
                out.extend(wf)
    return {k: statistics.median(v) for k, v in warm_medians.items() if v}


NET_SHAPE = ["unshaped (localhost)"]


def environment_block(results, chrome_ver, flutter_ver, out):
    first = next((r for r in results if r and "gpu" in r), None)
    out.append(f"host      : {platform.system()} {platform.release()} {platform.machine()}"
               f" | python {platform.python_version()}")
    out.append(f"chrome    : {chrome_ver}")
    out.append(f"flutter   : {flutter_ver}")
    out.append("build     : flutter build web --release --wasm --pwa-strategy=none")
    out.append(f"network   : {NET_SHAPE[0]}")
    if not first:
        out.append("GPU       : (not reported)")
        return
    g = first.get("gpu") or {}
    out.append(f"viewport  : {first.get('vw')}x{first.get('vh')} dpr={first.get('dpr')}"
               f" cores={first.get('cores')} mem={first.get('mem')}")
    out.append(f"GPU       : webgl={g.get('webgl')} webgl2={g.get('webgl2')}")
    if g.get("webgl"):
        out.append(f"            vendor   = {g.get('vendor')}")
        out.append(f"            renderer = {g.get('renderer')}")
    else:
        out.append("            *** NO WEBGL - this machine cannot answer the question ***")
    out.append(f"agent     : {(first.get('ua') or '')[:110]}")


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Profile the Flutter web boot path on a GPU machine.")
    ap.add_argument("--repo", default=None, help="repo root (default: parent of this script)")
    ap.add_argument("--runs", type=int, default=3, help="boot cycles per variant (default 3)")
    ap.add_argument("--no-baseline", action="store_true", help="skip the HEAD baseline build")
    ap.add_argument("--quick", action="store_true", help="current build only, 2 runs")
    ap.add_argument("--dir", default=None, help="profile an already-built web dir, skip building")
    ap.add_argument("--chrome", default=None, help="path to Chrome")
    ap.add_argument("--timeout", type=int, default=420, help="seconds to wait per variant")
    ap.add_argument("--net", choices=sorted(NET_PRESETS), default="none",
                    help="shape the local link to approximate a real host. localhost has no "
                         "latency and infinite bandwidth, which hides load-order problems "
                         "that only appear in production")
    ap.add_argument("--coi", choices=["auto", "off"], default="auto",
                    help="auto: let coi-serviceworker do its normal reload dance (default). "
                         "off: stop it registering, so no extra navigations")
    ap.add_argument("--keep", action="store_true", help="keep temp build dirs")
    ap.add_argument("--out", default="boot-profile.json", help="raw data output file")
    args = ap.parse_args()

    if args.net != "none":
        _l, _k = NET_PRESETS[args.net]
        NET_SHAPE[0] = f"{args.net}: {_l}ms latency, {_k}kbps (network only, CPU unthrottled)"
    if args.quick:
        args.no_baseline = True
        args.runs = 2

    repo = Path(args.repo).resolve() if args.repo else Path(__file__).resolve().parent.parent
    chrome = find_chrome(args.chrome)
    chrome_ver = version_of([chrome, "--version"])
    flutter_ver = "n/a (--dir given)" if args.dir else version_of(["flutter", "--version"])

    print("=" * 72)
    print(" Flutter web boot profiler")
    print("=" * 72)
    print(f" repo   : {repo}")
    print(f" chrome : {chrome_ver}")
    print(f" runs   : {args.runs} per variant"
          f"{'' if args.no_baseline else ', two variants (baseline + current)'}")
    if not args.dir:
        print(" note   : two release+wasm builds take a while. Go make coffee.")

    tmp = Path(tempfile.mkdtemp(prefix="bootprof-"))
    variants = []
    raw = {"generated": datetime.now(timezone.utc).isoformat(), "variants": {}}

    try:
        if args.dir:
            variants.append(("prebuilt", Path(args.dir).resolve()))
        else:
            if not shutil.which("flutter"):
                die("flutter is not on PATH")
            if not args.no_baseline:
                step("exporting HEAD as the baseline")
                base_src = tmp / "baseline-src"
                try:
                    export_head(repo, base_src)
                    ensure_boot_hook(base_src, repo)
                    variants.append(("baseline (HEAD)", build(base_src, "baseline")))
                except Exception as e:
                    print(f"   baseline unavailable ({e}); continuing with the current tree only")

            step("copying the working tree")
            cur_src = tmp / "current-src"
            copy_worktree(repo, cur_src)
            ensure_boot_hook(cur_src, repo)
            variants.append(("current (working tree)", build(cur_src, "current")))

        report = []
        all_results = []
        medians = {}
        for label, web_dir in variants:
            res = measure(web_dir, label.split()[0], args.runs, chrome, args.timeout, args.coi, args.net)
            raw["variants"][label] = res
            all_results.extend(res)
            medians[label] = res

        Path(args.out).write_text(json.dumps(raw), "utf-8")

        report.append("#" * 72)
        report.append("#  PASTE EVERYTHING BETWEEN THESE LINES")
        report.append("#" * 72)
        report.append(f"BOOT PROFILE  {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%MZ')}")
        environment_block(all_results, chrome_ver, flutter_ver, report)

        warm = {}
        for label, res in medians.items():
            warm[label] = summarize_variant(label, res, report)

        if len(warm) > 1:
            labels = list(warm.keys())
            a, b = labels[0], labels[1]
            report.append("")
            report.append("=== DELTA: median warm-run frame interval per phase ===")
            keys = [k for k in warm[b] if k in warm[a]]
            if keys:
                report.append(f"     {'phase':<20}{a[:18]:>20}{b[:18]:>20}")
                for k in keys:
                    report.append(f"     {k:<20}{warm[a][k]:>18.1f}ms{warm[b][k]:>18.1f}ms")
            else:
                report.append("     (phases did not line up between variants)")

        report.append("")
        report.append("=" * 72)
        report.append("#" * 72)
        text = "\n".join(report)
        print("\n" + text)
        Path("boot-profile.txt").write_text(text, "utf-8")
        print(f"\n(report also saved to boot-profile.txt, raw data to {args.out})")

    finally:
        if args.keep:
            print(f"\ntemp builds kept at {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
