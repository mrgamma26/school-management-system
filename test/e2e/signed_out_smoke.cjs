'use strict';
// Signed-out smoke test for the Flutter web app (login page, redirects, console/network, a11y).
// Never types credentials. Run (app already served on BASE_URL):
//   set PLAYWRIGHT_MODULE=<path to node_modules/playwright>   (optional, default: require('playwright'))
//   set BASE_URL=http://127.0.0.1:5151
//   node test/e2e/signed_out_smoke.cjs
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const BASE = (process.env.BASE_URL || 'http://127.0.0.1:5151').replace(/\/$/, '');
const OUT = process.env.OUT_DIR || path.join(__dirname, '..', '..', 'docs', 'ui-test-screenshots');
const VIEWPORTS = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'tablet', width: 820, height: 1180 },
  { name: 'phone', width: 390, height: 844 },
];
const PROTECTED = ['/admin/home', '/students', '/finance/payments', '/results/corrections',
  '/teacher/home', '/guardian/home', '/reports', '/admin/audit-log', '/settings/school'];
const results = [];
const record = (id, name, pass, detail = '') => {
  results.push({ id, name, pass, detail });
  console.log(`${pass ? 'PASS' : 'FAIL'}  ${id}  ${name}${detail ? '  -> ' + detail : ''}`);
};

// Project host is masked so results files never expose the Supabase project URL.
const mask = u => u.replace(/\/\/[a-z0-9-]+\.supabase\.co/, '//<project>.supabase.co');

function attach(page, bag) {
  page.on('console', m => {
    if (['error', 'warning'].includes(m.type())) bag.console.push(`${m.type()}: ${m.text().slice(0, 300)}`);
  });
  page.on('pageerror', e => bag.pageErrors.push(String(e).slice(0, 300)));
  page.on('requestfailed', r => bag.failed.push(`${r.method()} ${mask(r.url().split('?')[0])} ${r.failure()?.errorText}`));
  page.on('response', r => {
    const u = mask(r.url().split('?')[0]);
    if (r.status() >= 400) bag.http.push(`${r.status()} ${r.request().method()} ${u}`);
    if (!r.url().startsWith(BASE)) bag.external.push(`${r.status()} ${r.request().method()} ${u}`);
  });
}

async function openApp(page, route) {
  // The app uses hash routing (/#/route); a plain path would be ignored.
  await page.goto(route === '/' ? BASE + '/' : `${BASE}/#${route}`, { waitUntil: 'commit' });
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 240000 });
  await page.waitForTimeout(3000);
}

async function enableSemantics(page) {
  // The placeholder is a 1x1 off-screen element; focus + Enter activates it.
  await page.locator('flt-semantics-placeholder').focus();
  await page.keyboard.press('Enter');
  await page.waitForSelector('flt-semantics', { state: 'attached', timeout: 15000 });
  await page.waitForTimeout(800);
}

// Accessible names + roles of everything in the semantics tree.
const semantics = page => page.evaluate(() => [...document.querySelectorAll('flt-semantics')]
  .map(e => ({ role: e.getAttribute('role') || '', label: e.getAttribute('aria-label') || '', text: [...e.childNodes].filter(n => n.nodeType === 3 || (n.nodeType === 1 && n.tagName !== 'FLT-SEMANTICS')).map(n => n.textContent).join(' ').trim().slice(0, 80) }))
  .filter(x => x.role || x.label || x.text));

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  const bag = { console: [], pageErrors: [], failed: [], http: [], external: [] };

  for (const vp of VIEWPORTS) {
    const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
    const page = await ctx.newPage();
    const vbag = { console: [], pageErrors: [], failed: [], http: [], external: [] };
    attach(page, vbag);
    await openApp(page, '/');
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, `login-${vp.name}-${vp.width}x${vp.height}.png`) });
    record(`L-${vp.name}`, `login renders at ${vp.width}x${vp.height}`, /\/login$/.test(page.url()), page.url());
    const hs = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
    record(`L-${vp.name}-overflow`, 'no horizontal page overflow', !hs);
    for (const k of Object.keys(bag)) bag[k].push(...vbag[k].map(x => `[${vp.name}] ${x}`));

    if (vp.name === 'desktop') {
      record('T-title', 'page title', (await page.title()) === 'School Management System', await page.title());
      await enableSemantics(page);
      const sem = await semantics(page);
      fs.writeFileSync(path.join(OUT, 'login-semantics.json'), JSON.stringify(sem, null, 1));
      const has = re => sem.some(s => re.test(s.label + ' ' + s.text));
      record('A-email', 'email field has accessible name', has(/email/i));
      record('A-password', 'password field has accessible name', has(/password/i));
      record('A-submit', 'submit button named', has(/sign in securely/i));
      record('A-toggle', 'show-password toggle named', has(/show password/i));
      record('A-help', 'help link named', has(/need help signing in/i));
      record('A-heading', 'heading text present', has(/sign in to your account/i));

      // Keyboard tab order (no typing).
      const order = [];
      for (let i = 0; i < 7; i++) {
        await page.keyboard.press('Tab');
        await page.waitForTimeout(250);
        order.push(await page.evaluate(() => {
          const a = document.activeElement;
          return a ? `${a.tagName.toLowerCase()}|${a.getAttribute('aria-label') || ''}|${a.getAttribute('role') || ''}|${(a.innerText || '').trim().slice(0, 40)}` : 'none';
        }));
      }
      fs.writeFileSync(path.join(OUT, 'tab-order.txt'), order.join('\n'));
      record('K-tab', 'Tab moves focus through controls', new Set(order).size >= 4, order.join(' >> '));

      // Empty submit -> validation messages.
      await page.getByRole('button', { name: /sign in securely/i }).click();
      await page.waitForTimeout(1000);
      let s2 = await semantics(page);
      const has2 = re => s2.some(s => re.test(s.label + ' ' + s.text));
      record('V-email', 'empty submit shows "Email is required."', has2(/email is required/i));
      record('V-pass', 'empty submit shows "Password is required."', has2(/password is required/i));
      await page.screenshot({ path: path.join(OUT, 'login-desktop-validation.png') });

      // Show/hide password toggle (no password typed).
      await page.getByRole('button', { name: /show password/i }).click();
      await page.waitForTimeout(600);
      s2 = await semantics(page);
      record('P-toggle', 'toggle flips to "Hide password"', has2(/hide password/i));
      await page.getByRole('button', { name: /hide password/i }).click();
      await page.waitForTimeout(400);
    }
    await ctx.close();
  }

  // Redirects when signed out.
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  for (const r of ['/this-route-does-not-exist', ...PROTECTED, '/forgot-password']) {
    const page = await ctx.newPage(); // cold load per route
    attach(page, bag);
    await openApp(page, r);
    await page.waitForTimeout(1500);
    const hash = new URL(page.url()).hash;
    if (r === '/forgot-password') {
      record('R-forgot', '/forgot-password reachable signed out (page only opened, form not submitted)', hash === '#/forgot-password', page.url());
    } else {
      record(`R-${r}`, `${r} -> /login when signed out`, hash === '#/login', page.url());
    }
    await page.close();
  }
  await ctx.close();
  await browser.close();

  fs.writeFileSync(path.join(OUT, 'run-results.json'), JSON.stringify({ base: BASE, date: new Date().toISOString(), results, ...bag }, null, 1));
  console.log('\nconsole errors/warnings:', bag.console.length, ' page errors:', bag.pageErrors.length,
    ' failed requests:', bag.failed.length, ' http>=400:', bag.http.length);
  process.exit(results.some(r => !r.pass) ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
