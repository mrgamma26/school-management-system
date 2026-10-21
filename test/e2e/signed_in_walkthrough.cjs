'use strict';
// Signed-in walkthrough: YOU sign in by hand, the script then visits every parameter-free route.
// The script never reads, types, stores or logs credentials. Run it once per role you want to check.
//
//   set PLAYWRIGHT_MODULE=<path to node_modules/playwright>   (optional)
//   set BASE_URL=http://127.0.0.1:5151        (any served build: flutter run, or flutter build web + static server)
//   set ROLE_LABEL=teacher                    (only used in file names)
//   node test/e2e/signed_in_walkthrough.cjs
//
// 1. A headed Chromium opens on the login page. Sign in manually (change the password if the app asks).
// 2. When the app leaves /login, the script waits 5 s and starts walking the routes below.
// 3. For each route it records: final URL (a redirect means the role may not open it), console errors,
//    failed/4xx/5xx requests, a screenshot. Output goes to OUT_DIR (default: <os tmp>/ui-walkthrough-<role>).
//    Screenshots contain REAL school data: keep them out of git (the default OUT_DIR is outside the repo).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const BASE = (process.env.BASE_URL || 'http://127.0.0.1:5151').replace(/\/$/, '');
const ROLE = process.env.ROLE_LABEL || 'role';
const OUT = process.env.OUT_DIR || path.join(os.tmpdir(), `ui-walkthrough-${ROLE}`);
const VIEWPORT = { width: 1440, height: 900 };
const SIGN_IN_TIMEOUT_MS = 10 * 60 * 1000;

// Parameter-free routes from lib/core/router.dart. Add :id routes by hand once you know real ids.
const ROUTES = [
  '/admin/home', '/administrator/home', '/teacher/home', '/headteacher/home', '/accountant/home', '/guardian/home',
  '/admin/users', '/admin/users/create', '/admin/audit-log', '/admin/email-log', '/settings/school',
  '/academics/years', '/academics/years/new', '/academics/class-setup',
  '/academics/subjects', '/academics/subjects/new', '/academics/assignments',
  '/students', '/students/new', '/users/staff', '/users/staff/new', '/users/guardians',
  '/assessments', '/progression/reviews', '/weeding/reviews', '/results/corrections', '/results/publish',
  '/finance/payments', '/finance/payment-configuration', '/finance/fees', '/finance/deposit-slips',
  '/finance/arrangements', '/finance/reversals',
  '/calendar', '/calendar/new', '/notifications', '/teacher/comments', '/reports',
  '/guardian/payments', '/guardian/progress', '/guardian/report-card',
];

const slug = r => r.replace(/^\//, '').replace(/[^a-z0-9]+/gi, '-') || 'root';

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ headless: false });
  const ctx = await browser.newContext({ viewport: VIEWPORT });
  const page = await ctx.newPage();
  const bag = { console: [], failed: [], http: [] };
  let current = '(sign-in)';
  page.on('console', m => { if (m.type() === 'error') bag.console.push({ route: current, text: m.text().slice(0, 300) }); });
  page.on('pageerror', e => bag.console.push({ route: current, text: 'pageerror: ' + String(e).slice(0, 300) }));
  page.on('requestfailed', r => bag.failed.push({ route: current, url: r.url().split('?')[0], error: r.failure()?.errorText }));
  page.on('response', r => { if (r.status() >= 400) bag.http.push({ route: current, status: r.status(), url: r.url().split('?')[0] }); });

  await page.goto(`${BASE}/`, { waitUntil: 'commit' });
  console.log('Sign in manually in the browser window. Waiting up to 10 minutes...');
  await page.waitForFunction(() => location.hash && !/^#\/(login|forgot-password|reset-password)?$/.test(location.hash),
    null, { timeout: SIGN_IN_TIMEOUT_MS, polling: 1000 });
  await page.waitForTimeout(5000);
  const home = new URL(page.url()).hash;
  console.log('Signed in; landed on', home, '- walking routes');
  if (home === '#/change-password') {
    console.log('The app wants a password change first. Do it, then press Enter in this terminal.');
    await new Promise(res => process.stdin.once('data', res));
  }

  const rows = [];
  for (const route of ROUTES) {
    current = route;
    await page.evaluate(h => { location.hash = h; }, route);
    await page.waitForTimeout(2500);
    const finalHash = new URL(page.url()).hash.replace(/^#/, '');
    const redirected = finalHash !== route;
    await page.screenshot({ path: path.join(OUT, `${ROLE}-${slug(route)}.png`) });
    rows.push({ route, finalHash, redirected });
    console.log(`${redirected ? 'REDIRECTED' : 'opened    '} ${route}${redirected ? ' -> ' + finalHash : ''}`);
    if (finalHash === '/login') { console.log('Session lost (signed out). Stopping.'); break; }
  }

  fs.writeFileSync(path.join(OUT, `${ROLE}-results.json`), JSON.stringify({ base: BASE, rows, ...bag }, null, 1));
  console.log(`\nDone. Opened ${rows.filter(r => !r.redirected).length}/${rows.length}. ` +
    `console errors ${bag.console.length}, failed requests ${bag.failed.length}, HTTP>=400 ${bag.http.length}.`);
  console.log('Results + screenshots in', OUT);
  await browser.close();
})().catch(e => { console.error(e); process.exit(2); });
