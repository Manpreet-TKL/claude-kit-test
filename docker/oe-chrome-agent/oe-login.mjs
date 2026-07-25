// Manpreet 23/07/2026
// OE auto-login over CDP: drives the container's already-running Chrome (started with
// --remote-debugging-port) to the OpenEyes login form and submits the sample credentials,
// so the OE session cookie exists before any Claude in Chrome session starts - the
// extension itself refuses to type passwords, so login has to happen below it. Also
// collapses any tabs left over from session restore down to the one it drives, since the
// container's sole purpose is OE and this runs on every boot.
//
// Env: CDP_PORT (9222), OE_URL (required), OE_USERNAME/OE_PASSWORD (admin/admin),
//      OE_INSTITUTION_ID/OE_SITE_ID (1/1)
// Exit: 0 logged in (or already logged in), 1 failure. Pure Node 22 - no dependencies.

const env = (k, d) => process.env[k] ?? d;
const CDP = `http://127.0.0.1:${env('CDP_PORT', '9222')}`;
const OE_URL = env('OE_URL', '').replace(/\/$/, '');
if (!OE_URL || OE_URL === 'about:blank') {
  console.log('OE_URL not set - skipping auto-login');
  process.exit(0);
}

const deadline = Date.now() + 60000;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function cdpReady() {
  while (Date.now() < deadline) {
    try {
      const targets = await (await fetch(`${CDP}/json/list`)).json();
      const pages = targets.filter((t) => t.type === 'page');
      if (pages.length) {
        // Keep a web page, never the extension's options tab: that one is also type "page",
        // and driving OE through it means closing the real OE tab to navigate a settings
        // screen instead. Which tab /json/list returns first isn't ours to control.
        const page = pages.find((t) => /^https?:/.test(t.url)) || pages[0];
        const extra = pages.filter((t) => t.id !== page.id);
        await Promise.all(extra.map((t) => fetch(`${CDP}/json/close/${t.id}`).catch(() => {})));
        return page;
      }
    } catch { /* chrome not up yet */ }
    await sleep(1000);
  }
  throw new Error('CDP endpoint never came up - was Chrome started with --remote-debugging-port?');
}

const page = await cdpReady();
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP websocket failed')); });

let msgId = 0;
const pending = new Map();
const loadWaiters = [];
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  if (m.method === 'Page.loadEventFired') loadWaiters.splice(0).forEach((r) => r());
};
function send(method, params = {}) {
  const id = ++msgId;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((res, rej) => {
    pending.set(id, (m) => (m.error ? rej(new Error(`${method}: ${m.error.message}`)) : res(m.result)));
    setTimeout(() => { if (pending.delete(id)) rej(new Error(`${method}: timeout`)); }, 30000);
  });
}
const waitLoad = (ms = 20000) => Promise.race([new Promise((r) => loadWaiters.push(r)), sleep(ms)]);
async function evaluate(expression) {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true });
  if (r.exceptionDetails) throw new Error(`evaluate: ${r.exceptionDetails.text}`);
  return r.result.value;
}

await send('Page.enable');
await send('Page.navigate', { url: `${OE_URL}/site/login` });
await waitLoad();
await sleep(1500);

if (!(await evaluate("!!document.querySelector('#LoginForm_username')"))) {
  const where = await evaluate('location.href');
  console.log(`no login form at ${where} - assuming already logged in`);
  ws.close();
  process.exit(0);
}

// The institution/site pickers are custom JS; the real inputs are hidden (same trick as
// c-oe-nav's journey.mjs).
await evaluate(`
  document.querySelector('#LoginForm_username').value = ${JSON.stringify(env('OE_USERNAME', 'admin'))};
  document.querySelector('#LoginForm_password').value = ${JSON.stringify(env('OE_PASSWORD', 'admin'))};
  const i = document.querySelector('#LoginForm_institution_id'); if (i) i.value = ${JSON.stringify(env('OE_INSTITUTION_ID', '1'))};
  const s = document.querySelector('#LoginForm_site_id'); if (s) s.value = ${JSON.stringify(env('OE_SITE_ID', '1'))};
  document.querySelector('#login_button').click();
`);
await waitLoad();
await sleep(1500);

const finalUrl = await evaluate('location.href');
ws.close();
if (finalUrl.includes('/site/login')) {
  console.error(`still on ${finalUrl} - check credentials / institution / site ids`);
  process.exit(1);
}
console.log(`logged in - landed on ${finalUrl}`);
