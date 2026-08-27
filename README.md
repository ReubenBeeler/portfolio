# Portfolio
[![Build and Deploy to GitHub Pages](https://github.com/ReubenBeeler/portfolio/actions/workflows/workflow.yml/badge.svg)](https://github.com/ReubenBeeler/portfolio/actions/workflows/workflow.yml)

A Flutter web application showcasing my technical credentials. See [reubenbeeler.me](https://reubenbeeler.me).

## Technical Highlights

**Built with:**
- Flutter 3.x for web
- Responsive design supporting desktop, tablet, and mobile viewports
- Custom animations and transitions
- Deployed via GitHub Pages with automated CI/CD

**Key implementation decisions:**
- The home page is intended to resemble a desktop with quick links for external profiles and app navigation (with computationally expensive rendering due to a beautiful parallax scrolling animation).
- To keep the animations smooth, I compile the build to WASM (`flutter build web --release --wasm` in CI), which in turn slows the app initialization.
- `web/coi-serviceworker.js` supplies the COOP/COEP headers GitHub Pages cannot set, so the WASM renderer can use SharedArrayBuffer. It costs an extra page navigation on a visitor's first load.
- The build passes `--pwa-strategy=none`. Flutter's own service worker cannot install (coi-serviceworker already owns scope `/`), and shipping it anyway made `flutter.js` wait out a 4 second timeout before downloading the renderer, and stopped cross-origin isolation from being established at all.
- To handle issues with slow app initialization such as FOUC, I use flutter_native_splash to inject a splash screen in the index.html
- And I added a bootstrapper at `lib/bootstrapper.dart` to immediately display a loading screen while asynchronously loading assets for the home page.
- Further, I replaced `AssetImage`s with `NetworkImage`s to prevent large asset bundling from delaying the bootstrapper.
- The three fonts on the boot critical path are bundled under `google_fonts/` so the loading animation never waits on a fonts.gstatic.com round-trip. Everything else still resolves over the network.
- Assets are precached concurrently (`Future.wait`) rather than one at a time, so the loading screen waits for the slowest download instead of the sum of all of them.
- The home page is built and laid out behind the splash screen, so its first (expensive) layout does not land in the middle of the loading animation.
- The fade-in overlaps the fly-out (`_kFadeOverlap` in `lib/bootstrapper.dart`) rather than following it, so the home page rises behind the departing letters. Assets are ready long before the animation ends, so running the two back to back was about 0.7s of pure waiting.
- Two ways to profile the boot path. `tool/profile_boot.py` builds and measures locally (`--net 3g` shapes the link, since localhost hides anything that only breaks when assets arrive slowly). For the deployed site on its real host and a real device, open [reubenbeeler.me/?profile](https://reubenbeeler.me/?profile): the profiler ships in `index.html`, inert without that query parameter, and prints a pasteable report.
- I use ListenableBuilders in favor of setState() to improve performance by targeting rebuilds to the animated widgets thereby avoiding rebuilds on unchanged widgets.

## Local Development

Run the code locally with
```bash
flutter config --enable-web
flutter pub get
flutter run -d chrome --wasm
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── bootstrapper.dart      # Loading page
├── views/                 # Main portfolio sections
├── widgets/               # Reusable components
└── util/                  # General utility functions
```

## What I Learned

Building this portfolio taught me how to develop and host a website with CI/CD, and how to optimize the design and build patterns for specific performance criteria (such as faster bundling and avoiding FOUC).

---

**Contact:** reuben.beeler@gmail.com | [LinkedIn](https://linkedin.com/in/ReubenBeeler)
