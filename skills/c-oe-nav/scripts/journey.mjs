#!/usr/bin/env node
// OpenEyes journey driver (Puppeteer): run a JSON action list against a running OE
// instance and print a compact text dump of what the user sees after every step.
//
// Runs INSIDE the standard web-live container using the Chrome + Puppeteer that
// ship in the image (docman uses them to render lightning previews) - no extra
// container, nothing installed, nothing written to the image. It is also the
// endpoint prover: goto a URL with the logged-in session, then read "body" for
// the JSON. Invocation + the Playwright-image fallback: ../subs/probe.md
//
//   docker exec -i -e OE_ACTIONS="$(cat acts.json)" -w /var/www/openeyes \
//     <stack>-web-1 node --input-type=module - < scripts/journey.mjs
//   node journey.mjs acts.json            # local file
//   node journey.mjs '[{"goto":"/"}]'     # inline JSON
//
// Actions: array of single-key objects -
//   {"goto":"/patient/summary/17891"}   path or full URL
//   {"click":"#add-event"}              CSS, text="Label", or "<sel> >> nth=N"
//   {"fill":["#sel","value"]}  {"select":["#sel","value"]}  {"upload":["#sel","/file"]}
//   {"press":"Enter"}  {"wait":1500}  {"read":".element-fields"}
//   {"dump":true}                       force a structural snapshot (quiet is the default)
//   {"login":false}                     as FIRST action: skip the built-in login
//
// Output is QUIET by default: the oe-version line, explicit reads, any STEP FAILED
// state, and one final snapshot of where you landed - nothing per step. Drop in a
// {"dump":true} action wherever you want a mid-journey structural view; pass
// --verbose (or OE_VERBOSE=1) to restore a full dump after every step.
//
// Env: BASE_URL (http://localhost), OE_USERNAME/OE_PASSWORD (admin/admin) or
// OE_PASSWORD_FILE, OE_INSTITUTION_ID/OE_SITE_ID (1/1), OE_SETTLE_MS (700)
//, OE_ALLOW_WRITE=1 to permit delete-like clicks and native confirm dialogs
//, OE_VERBOSE=1 (or --verbose) dumps the full page after every step (default is quiet)
//, OE_ACTIONS carries the action list when the script itself is piped on stdin.
// Exit: 0 ok, 2 bad input or step failure, 3 login/infra failure.
import puppeteer from 'puppeteer';
import { readFileSync, mkdirSync } from 'node:fs';

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
const verboseAt = argv.indexOf('--verbose');
if (verboseAt >= 0) argv.splice(verboseAt, 1);
// Quiet by default (oe-version + reads + failures + a final snapshot); --verbose restores per-step dumps.
const VERBOSE = verboseAt >= 0 || /^(1|true|yes)$/i.test(env('OE_VERBOSE', ''));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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

// Playwright-style selector sugar -> Puppeteer: text="X" -> ::-p-text(X); "<sel> >> nth=N".
const splitNth = (sel) => {
  const m = sel.match(/^(.*?)\s*>>\s*nth=(\d+)\s*$/);
  return m ? { base: m[1].trim(), nth: Number(m[2]) } : { base: sel, nth: null };
};
const toSel = (sel) => {
  const m = sel.match(/^text="(.+)"$/);
  return m ? `::-p-text(${m[1]})` : sel;
};
const find = async (page, sel, timeout = 8000) => {
  const { base, nth } = splitNth(sel);
  const s = toSel(base);
  await page.waitForSelector(s, { timeout });
  if (nth == null) return page.$(s);
  const els = await page.$$(s);
  if (!els[nth]) throw new Error(`no match #${nth} for "${s}"`);
  return els[nth];
};

async function settle(page) {
  // OE long-polls (worklist sync, notifications) - never wait for network-idle.
  await sleep(SETTLE);
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
  const user = await find(page, '#LoginForm_username');
  await user.type(env('OE_USERNAME', 'admin'));
  const pass = await find(page, '#LoginForm_password');
  await pass.type(PASSWORD);
  // The institution/site pickers are custom JS; the real inputs are hidden.
  await page.evaluate(({ inst, site }) => {
    const i = document.querySelector('#LoginForm_institution_id'); if (i) i.value = inst;
    const s = document.querySelector('#LoginForm_site_id'); if (s) s.value = site;
  }, { inst: env('OE_INSTITUTION_ID', '1'), site: env('OE_SITE_ID', '1') });
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 20000 }).catch(() => {}),
    page.click('#login_button'),
  ]);
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
    const el = await find(page, sel);
    await el.click();
  },
  fill: async (page, [sel, val]) => {
    const el = await find(page, sel);
    await el.evaluate((e) => { e.value = ''; });
    await el.type(String(val));
  },
  select: async (page, [sel, val]) => {
    const s = toSel(splitNth(sel).base);
    await page.waitForSelector(s, { timeout: 8000 });
    await page.select(s, val);
  },
  upload: async (page, [sel, file]) => {
    const el = await find(page, sel);
    await el.uploadFile(file);
  },
  press: (page, key) => page.keyboard.press(key),
  wait: (page, ms) => sleep(Number(ms)),
  read: async (page, sel) => {
    const el = await find(page, sel);
    out('TEXT ' + JSON.stringify((await el.evaluate((e) => e.innerText)).slice(0, 2000)));
  },
};

const browser = await puppeteer.launch({ args: ['--no-sandbox', '--disable-dev-shm-usage'] });
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 900 });
  page.on('dialog', (d) => (ALLOW_WRITE ? d.accept() : d.dismiss()).catch(() => {}));

  if (actions[0]?.login !== false) {
    try {
      await login(page);
    } catch (e) {
      console.error(`LOGIN FAILED: ${e.message}`);
      process.exit(3);
    }
    out('### logged in');
    // The in-app version is signal even when quiet; the full structural dump is the noise.
    const version = await page.evaluate(() => {
      const el = document.querySelector('#js-openeyes-info');
      const raw = (el?.innerText || el?.getAttribute('title') || '').replace(/\s+/g, ' ').trim();
      return raw.match(/Version:?\s*(v?[\d][\w.\-]*)/i)?.[1] || '';
    });
    if (version) out(`oe version: ${version}`);
    if (VERBOSE) await dump(page);
  }

  let lastDumped = false;
  for (let i = 0; i < actions.length; i++) {
    const [verb, arg] = Object.entries(actions[i])[0] ?? [];
    if (verb === 'login') continue;
    out(`\n### step ${i + 1}: ${verb} ${JSON.stringify(arg)}`);
    if (verb === 'dump') {                 // force a structural snapshot (quiet is the default)
      await dump(page).catch(() => {});
      lastDumped = true;
      continue;
    }
    if (!acts[verb]) {
      console.error(`step ${i + 1}: unknown action "${verb}"`);
      process.exit(2);
    }
    try {
      await acts[verb](page, arg);
      await settle(page);
    } catch (e) {
      out(`STEP FAILED: ${e.message.split('\n')[0]}`);
      out('state at failure:');
      await dump(page).catch(() => {});    // failures always dump, even when quiet
      if (shotDir) await page.screenshot({ path: `${shotDir}/step-${String(i + 1).padStart(2, '0')}-failed.png` }).catch(() => {});
      process.exit(2);
    }
    // Quiet (default) suppresses per-step dumps; --verbose restores them. read prints its own text; wait shows nothing.
    if (verb !== 'wait' && verb !== 'read' && VERBOSE) {
      await dump(page);
      lastDumped = true;
    } else if (verb === 'read') {
      lastDumped = true;   // the read is the output - no redundant final snapshot after it
    } else {
      lastDumped = false;  // wait / quiet step - let the final snapshot show where we landed
    }
    if (shotDir) await page.screenshot({ path: `${shotDir}/step-${String(i + 1).padStart(2, '0')}.png` }).catch(() => {});
  }
  if (!VERBOSE && !lastDumped) await dump(page);   // quiet: one final snapshot of where we landed
  out('\nJOURNEY OK');
} finally {
  await browser.close();
}
