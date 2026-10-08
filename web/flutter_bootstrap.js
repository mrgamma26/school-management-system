{{flutter_js}}
{{flutter_build_config}}

function showStartupError(error) {
  console.error('Flutter startup failed:', error);
  const loading = document.getElementById('loading');
  if (!loading) return;
  loading.querySelector('.loading-spinner')?.remove();
  const message = loading.querySelector('p');
  if (message) {
    message.textContent = 'The app could not start. Please refresh the page or restart the app.';
  }
}

// Serve the SDK-matched renderer with the app instead of requiring Google CDN access.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).toString(),
  },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    } catch (error) {
      showStartupError(error);
    }
  },
}).catch(showStartupError);
