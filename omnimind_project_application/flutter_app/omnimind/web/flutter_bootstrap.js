// ============================================================================
// Custom Flutter Web bootstrap for OmniMind.
//
// Why this file exists
// --------------------
// Flutter's default auto-generated bootstrap uses the CanvasKit renderer.
// CanvasKit needs to download its own assets AND a Roboto font from
//   https://fonts.gstatic.com/s/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2
// In restricted / offline environments that fetch fails, the renderer throws
// a low-level "type 'bool' is not a subtype of type 'JSObject?'" error and
// the app never boots.
//
// The previous workaround in index.html used
//   window.flutterWebRenderer = 'html'
// which Flutter 3.22+ now ignores (it prints
//   "window.flutterWebRenderer is now deprecated.
//    Use engineInitializer.initializeEngine(config) instead.").
//
// The fix is to use the new engineInitializer.initializeEngine(config) API
// and explicitly pass renderer: "html". The HTML renderer does not need
// CanvasKit or the Roboto font — it uses the browser's native text engine
// and our locally bundled NotoSans font (see pubspec.yaml).
// ============================================================================

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.loadEntrypoint({
  serviceWorker: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    // Force the HTML renderer so the app works without network access.
    // - renderer: "html"   -> no CanvasKit, no Roboto download from Google
    // - useColorEmoji: false -> avoid any extra font fetch
    const config = {
      renderer: "html",
      useColorEmoji: false,
    };

    const appRunner = await engineInitializer.initializeEngine(config);
    await appRunner.runApp();
  },
});
