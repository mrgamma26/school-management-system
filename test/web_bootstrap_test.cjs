const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('web/flutter_bootstrap.js', 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

function bootstrap() {
  let options;
  let spinnerRemoved = false;
  const message = { textContent: 'Loading...' };
  const context = {
    URL, console: { error() {} },
    document: {
      baseURI: 'http://localhost:8080/school/',
      getElementById: () => ({ querySelector: selector => selector === 'p'
        ? message : { remove() { spinnerRemoved = true; } } }),
    },
    _flutter: { loader: { load(value) { options = value; return Promise.resolve(); } } },
  };
  vm.runInNewContext(source, context);
  return { options, message, spinnerRemoved: () => spinnerRemoved };
}

test('CanvasKit is served locally, including deployments under a subpath', () => {
  assert.equal(bootstrap().options.config.canvasKitBaseUrl,
    'http://localhost:8080/school/canvaskit/');
});
test('startup initializes the engine and starts the app', async () => {
  let started = false;
  await bootstrap().options.onEntrypointLoaded({
    async initializeEngine() { return { async runApp() { started = true; } }; },
  });
  assert.equal(started, true);
});
test('an engine failure replaces the indefinite spinner with an error', async () => {
  const app = bootstrap();
  await app.options.onEntrypointLoaded({ async initializeEngine() { throw Error('unavailable'); } });
  assert.equal(app.spinnerRemoved(), true);
  assert.match(app.message.textContent, /could not start/);
});
