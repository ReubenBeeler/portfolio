'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"main.dart.wasm": "c650aad857ec6d51086363f0bc1f8a48",
"static/Reuben%20Beeler%20-%20Physics%20127BL%20-%20Lab%2011%20Report.pdf": "b27000e16d816c3c35b771c8ac97e7da",
"static/Reuben%20Beeler%20-%20Physics%20127BL%20-%20Lab%209%20and%2010%20Report.pdf": "e83c8a9f1e9c3dde99de9cd1eb8fcc60",
"static/Reuben%20Beeler%20Resume.pdf": "5b5a86dbe9951832e16ff8de23341049",
"manifest.json": "751e1a8bf22b8fd2a3b65a71e7cded3f",
"icon.png": "029a702dc4d287ebc2feb728be81cd7c",
"icons/Icon-192.png": "acc3945a97678e3d1dd6cda2107f2c39",
"icons/favicon-32.png": "7f90bb6953000b93979157a60e5bc203",
"icons/Icon-maskable-512.png": "481dd5f00dcedd557258dee8587bf304",
"icons/favicon-16.png": "e7cd75d958902085bf8510fcab02d2d9",
"icons/Icon-maskable-192.png": "acc3945a97678e3d1dd6cda2107f2c39",
"icons/Icon-512.png": "481dd5f00dcedd557258dee8587bf304",
"main.dart.js": "d4c875b0953ee577d17b0d10555c77a5",
"version.json": "009c9e65172e010890f7f65fde438006",
"assets/NOTICES": "8c0386250df936d55c7a30160cd1d9dc",
"assets/fonts/MaterialIcons-Regular.otf": "087c6b6cf89d2429d404947d3c8eb761",
"assets/AssetManifest.json": "e7b97e111691d2a5867cdf6136d5a12b",
"assets/assets/generator_thumbnail.webp": "56c8d1d025845e98cebed75d61128f0e",
"assets/assets/background.webp": "99ef2e41c81a7afdf3b9c8830fad1bb4",
"assets/assets/keylogging_thumbnail.webp": "8ce440e521a789b1c28ea23f8561c45d",
"assets/assets/PAOA%2520vs%2520QAOA%2520thumbnail.webp": "f956a7a6a8e3169fc60725f1e2e6feeb",
"assets/assets/linkedin_circle.webp": "ecd208800119ac48e71e1be0d837fa51",
"assets/assets/profile_pic.webp": "750a2c1180f2e62277c91dcb341fce53",
"assets/assets/github_logo_clean.webp": "d3cd8dbf8a5d683ee9910f043bd40377",
"assets/assets/auchanic_thumbnail.webp": "512f639a0c11495d26a0e78db544bbdb",
"assets/assets/resume.webp": "475df2ee558d79524c04014864a4a415",
"assets/assets/java_badge.webp": "133dbf78fda56f964b0d4fbdf497383f",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "e71529a39367fc4446452b005e0d679d",
"assets/AssetManifest.bin": "7ecf86fc2713f87ac4ee9816afe213fe",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"main.dart.mjs": "26d53262c08508a1fd6618f18f953b14",
"flutter_bootstrap.js": "8747b3dc3ff9658dde1c3f05778235d2",
"coi-serviceworker.js": "51824b4599970db5deba2391cf3a543e",
"favicon.png": "b3d8c96afb24a64ee5560822ef28ed68",
"index.html": "61e47b5d990a14073c1aaa47a494d9f1",
"/": "61e47b5d990a14073c1aaa47a494d9f1"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"main.dart.wasm",
"main.dart.mjs",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
