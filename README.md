# Portfolio
[![Build and Deploy to GitHub Pages](https://github.com/ReubenBeeler/portfolio/actions/workflows/workflow.yml/badge.svg)](https://github.com/ReubenBeeler/portfolio/actions/workflows/workflow.yml)

A Flutter web application showcasing my technical projects and experience. Live at [reubenbeeler.me](https://reubenbeeler.me).

## Technical Highlights

**Built with:**
- Flutter 3.x for web
- Responsive design supporting desktop, tablet, and mobile viewports
- Custom animations and transitions
- Deployed via GitHub Pages with automated CI/CD

**Key implementation decisions:**
- The home page is intended to resemble a desktop with quick links for external profiles and app navigation (with computationally expensive rendering due to a beautiful parallax scrolling animation).
- To keep the animations smooth, I compile the build to WASM, which in turn slows the app initialization.
- To handle issues with slow app initialization such as FOUC, I use flutter_native_splash to inject a splash screen in the index.html
- And I added a bootstrapper at `lib/bootstrapper.dart` to immediately display a loading screen while asynchronously loading assets for the home page.
- Further, I replaced `AssetImage`s with `NetworkImage`s to prevent large asset bundling from delaying the bootstrapper.
- I use ListenableBuilders in favor of setState() to improve performance by targeting rebuilds to the animated widgets thereby avoiding rebuilds on unchanged widgets.

## Local Development

Running this locally is as simple as
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

Building this portfolio taught me how to develop and host a website with CI/CD via GitHub Actions, and how to optimize the design and build patterns for specific performance criteria.

---

**Contact:** reuben.beeler@gmail.com | [LinkedIn](https://linkedin.com/in/ReubenBeeler)
