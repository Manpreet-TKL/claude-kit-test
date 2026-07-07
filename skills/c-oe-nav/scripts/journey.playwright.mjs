#!/usr/bin/env node
// OpenEyes journey driver (Playwright, FALLBACK) - run a JSON action list against a
// running OE instance and print a compact text dump after every step.
// The primary driver is ../scripts/journey.mjs (Puppeteer, runs inside the web-live
// container). Use THIS one when the image carries Playwright instead (dev/debug),
// when connecting to an existing browser over CDP (browserless/remote-chrome), or
// in the Playwright sidecar container. Invocation: ../subs/probe-playwright.md
//
//   node journey.playwright.mjs <actions.json | - | '[...]'>  [--shot <dir>]
//   docker exec -i -e OE_ACTIONS='[...]' -w /var/www/openeyes <ctr> \
//     node --input-type=module - < journey.playwright.mjs        # dev/debug image
//
// Actions: array of single-key objects -
//   {"goto":"/patient/summary/17891"}   path or full URL
//   {"click":"#add-event"}              Playwright selector (CSS or text="Label")
//   {"fill":["#sel","value"]}  {"select":["#sel","value"]}  {"upload":["#sel","/file"]}
//   {"press":"Enter"}  {"wait":1500}  {"read":".element-fields"}
//   {"login":false}                     as FIRST action: skip the built-in login
//
// Env: BASE_URL (http://localhost; sidecar sets http://web), OE_USERNAME/
// OE_PASSWORD (admin/admin) or OE_PASSWORD_FILE, OE_INSTITUTION_ID/OE_SITE_ID
// (1/1), OE_SETTLE_MS (700), OE_ALLOW_WRITE=1 to permit delete-like clicks and
// native confirm dialogs, OE_ACTIONS carries the action list when the script
// itself is piped on stdin, OE_CDP_URL connects to an existing browser over CDP
// instead of launching, OE_CHROME launches a specific Chrome binary.
// Exit: 0 ok, 2 bad input or step failure, 3 login/infra failure.
import { readFileSync, mkdirSync } from 'node:fs';

let chromium;
try { ({ chromium } = await import('playwright')); }
catch {
  try { ({ chromium } = await import('playwright-core')); }
  catch { console.error('neither playwright nor playwright-core is installed here'); process.exit(3); }
}

const env = (k, d) => process.env[k] ?? d;
const BASE = env('BASE_URL', 'http://localhost').replace(/\/$/, '');
const SETTLE = Number(env('OE_SETTLE_MS', 700));
const ALLOW_WRITE = !!process.env.OE_ALLOW_WRITE;
const PASSWORD = env('OE_PASSWORD_FILE')
  ? readFileSync(env('OE_PASSWORD_FILE'), 'utf8').trim()
  : env('OE_PASSWORD', 'admin');

const argv = process.argv.slice(2);
const shotAt = argv.indexOf('--shot');
const shotDir = shotAt >= 0 ? argv.splice(shotAt, 2)[1] : null;
if (shotDir) mkdirSync(shotDir, { recursive: true });

// Actions come from $OE_ACTIONS (script is on stdin), else argv (path or inline JSON), else stdin.
let actions;
try {
  const a = argv[0];
  const raw = process.env.OE_ACTIONS
    ? process.env.OE_ACTIONS
    : a && a !== '-'
      ? (a.trim().startsWith('[') ? a : readFileSync(a, 'utf8'))
      : readFileSync(0, 'utf8');
  actions = JSON.parse(raw);
  if (!Array.isArray(actions)) throw new Error('top level must be an array');
} catch (e) {
  console.error(`bad action list: ${e.message}`);
  process.exit(2);
}

const out = (s) => console.log(s);

async function settle(page) {
  await page.waitForLoadState('domcontentloaded').catch(() => {});
  // OE long-polls (worklist sync, notifications) - never wait for networkidle.
  await page.waitForTimeout(SETTLE);
}

// What the user currently sees; when an OE popup/dialog is open, scope to it.
async function dump(page) {
  const s = await page.evaluate(() => {
    const clean = (t) => (t || '').replace(/\s+/g, ' ').trim();
    // Icon-only controls carry their name in aria/title or the enclosing list item.
    const label = (el) => clean(el.innerText || el.value) || clean(el.getAttribute('aria-label') || el.title)
      || clean(el.closest('li,td,th')?.innerText).slice(0, 60);
    const noise = (t) => /^This page is intended/i.test(t);
    const vis = (el) => { const r = el.getBoundingClientRect(); return r.width > 1 && r.height > 1; };
    const ref = (el) => el.id ? `#${el.id}`
      : el.dataset?.test ? `[data-test="${el.dataset.test}"]`
      : el.name ? `[name="${el.name}"]` : '';
    const popup = [...document.querySelectorAll('.oe-popup-wrap, .oe-dialog, [role="dialog"]')].find(vis) || null;
    const root = popup || document;
    const q = (sel) => [...root.querySelectorAll(sel)].filter(vis);
    const cap = (arr, n) => arr.length > n ? [...arr.slice(0, n), `... +${arr.length - n} more`] : arr;
    return {
      popup: !!popup,
      behind: popup ? [...document.querySelectorAll('h1')].map((e) => clean(e.innerText)).find((t) => t && !noise(t)) : null,
      version: clean(document.querySelector('#js-openeyes-info')?.innerText)
        || clean(document.querySelector('#js-openeyes-info')?.getAttribute('title')),
      headings: cap(q('h1,h2,h3,.oe-h1,.event-title').map((e) => clean(e.innerText)).filter((t) => t && !noise(t)), 8),
      banners: q('.errorMessage, .alert-box, .flash-error, .error, .warning')
        .map((e) => clean(e.innerText)).filter(Boolean).slice(0, 8),
      buttons: cap(q('button, input[type=submit], input[type=button], a.button, .oe-button, [role=button], li.oe-event-type')
        .map((e) => `"${label(e)}" ${ref(e)}`.trim()).filter((x) => x !== '""'), 45),
      fields: cap(q('input:not([type=hidden]), select, textarea').map((e) => {
        const lab = e.id && document.querySelector(`label[for="${e.id}"]`);
        const name = clean(lab?.innerText) || e.placeholder || e.name || '';
        return `"${name}" ${ref(e)} <${e.tagName.toLowerCase()}${e.type ? ':' + e.type : ''}>`;
      }), 40),
      links: cap(q('a[href]:not([href^="javascript"])')
        .map((e) => `"${clean(e.innerText)}" -> ${e.getAttribute('href')}`)
        .filter((x) => !x.startsWith('"" ')), 30),
    };
  });
  out(`url: ${page.url()}`);
  if (s.popup) out(`popup: OPEN - controls below are the popup's (page behind: "${s.behind}")`);
  if (s.headings.length) out(`headings: ${s.headings.join(' | ')}`);
  if (s.banners.length) out(`banners: ${s.banners.join(' | ')}`);
  for (const [label, items] of [['buttons', s.buttons], ['fields', s.fields], ['links', s.links]]) {
    if (!items.length) continue;
    out(`${label}:`);
    for (const it of items) out(`  - ${it}`);
  }
  return s;
}

async function login(page) {
  await page.goto(BASE + '/site/login', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.fill('#LoginForm_username', env('OE_USERNAME', 'admin'));
  await page.fill('#LoginForm_password', PASSWORD);
  // The institution/site pickers are custom JS; the real inputs are hidden.
  await page.evaluate(({ inst, site }) => {
    const i = document.querySelector('#LoginForm_institution_id'); if (i) i.value = inst;
    const s = document.querySelector('#LoginForm_site_id'); if (s) s.value = site;
  }, { inst: env('OE_INSTITUTION_ID', '1'), site: env('OE_SITE_ID', '1') });
  await page.click('#login_button');
  await settle(page);
  if (page.url().includes('/site/login')) {
    throw new Error('still on /site/login - check creds / institution / site ids');
  }
}

const acts = {
  goto: async (page, url) => {
    const r = await page.goto(/^https?:/.test(url) ? url : BASE + url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    if (r && r.status() >= 400) out(`HTTP ${r.status()}`);
  },
  click: async (page, sel) => {
    if (/delete/i.test(sel) && !ALLOW_WRITE) {
      throw new Error(`refusing delete-like click "${sel}" (set OE_ALLOW_WRITE=1 on a sample box to permit)`);
    }
    await page.click(sel, { timeout: 8000 });
  },
  fill: (page, [sel, val]) => page.fill(sel, val, { timeout: 8000 }),
  select: (page, [sel, val]) => page.selectOption(sel, val, { timeout: 8000 }),
  upload: (page, [sel, file]) => page.setInputFiles(sel, file, { timeout: 8000 }),
  press: (page, key) => page.keyboard.press(key),
  wait: (page, ms) => page.waitForTimeout(Number(ms)),
  read: async (page, sel) =>
    out('TEXT ' + JSON.stringify((await page.locator(sel).first().innerText({ timeout: 8000 })).slice(0, 2000))),
};

const browser = env('OE_CDP_URL')
  ? await chromium.connectOverCDP(env('OE_CDP_URL'))
  : await chromium.launch({ args: ['--no-sandbox'], ...(env('OE_CHROME') ? { executablePath: env('OE_CHROME') } : {}) });
try {
  const page = await (await browser.newContext({ viewport: { width: 1400, height: 900 } })).newPage();
  page.on('dialog', (d) => (ALLOW_WRITE ? d.accept() : d.dismiss()).catch(() => {}));

  if (actions[0]?.login !== false) {
    try {
      await login(page);
    } catch (e) {
      console.error(`LOGIN FAILED: ${e.message}`);
      process.exit(3);
    }
    out('### logged in');
    const s = await dump(page);
    if (s.version) out(`oe version: ${s.version}`);
  }

  for (let i = 0; i < actions.length; i++) {
    const [verb, arg] = Object.entries(actions[i])[0] ?? [];
    if (verb === 'login') continue;
    if (!acts[verb]) {
      console.error(`step ${i + 1}: unknown action "${verb}"`);
      process.exit(2);
    }
    out(`\n### step ${i + 1}: ${verb} ${JSON.stringify(arg)}`);
    try {
      await acts[verb](page, arg);
      await settle(page);
    } catch (e) {
      out(`STEP FAILED: ${e.message.split('\n')[0]}`);
      out('state at failure:');
      await dump(page).catch(() => {});
      if (shotDir) await page.screenshot({ path: `${shotDir}/step-${String(i + 1).padStart(2, '0')}-failed.png` }).catch(() => {});
      process.exit(2);
    }
    if (verb !== 'wait' && verb !== 'read') await dump(page);
    if (shotDir) await page.screenshot({ path: `${shotDir}/step-${String(i + 1).padStart(2, '0')}.png` }).catch(() => {});
  }
  out('\nJOURNEY OK');
} finally {
  await browser.close();
}
