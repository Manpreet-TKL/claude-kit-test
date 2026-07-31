// Deterministic highlight + screenshot over CDP - no agent session involved.
// Usage: node /usr/local/bin/highlight-shot.mjs '<css-selector>' [url]
// Navigates the existing http(s) tab (if a url is given), draws a red box around every
// element the selector matches, and captures the viewport once per element that isn't
// already fully visible in an earlier shot. Boxes are position:fixed overlay divs, not
// CSS outlines: outlines are painted outside the element's border box and get clipped
// by any scrolling ancestor (OE scrolls inside main#event-content), fixed overlays
// escape that clipping. Writes /tmp/claude-chrome-highlight-*.png (the drive.sh
// evidence prefix, so a later drive would copy them out too) and prints one path per line.
import fs from 'node:fs';

const [selector, url] = process.argv.slice(2);
if (!selector) {
    console.error('usage: highlight-shot.mjs <css-selector> [url]');
    process.exit(1);
}

const targets = await (await fetch('http://127.0.0.1:9222/json')).json();
const page = targets.find((t) => t.type === 'page' && /^https?:/i.test(t.url));
if (!page) {
    console.error('no http(s) page tab found on CDP');
    process.exit(1);
}

const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => {
    ws.onopen = res;
    ws.onerror = () => rej(new Error('CDP connect failed'));
});

let seq = 0;
const pending = new Map();
const events = [];
ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id && pending.has(msg.id)) {
        const { res, rej } = pending.get(msg.id);
        pending.delete(msg.id);
        msg.error ? rej(new Error(msg.error.message)) : res(msg.result);
    } else if (msg.method) {
        events.push(msg.method);
    }
};
const send = (method, params = {}) =>
    new Promise((res, rej) => {
        const id = ++seq;
        pending.set(id, { res, rej });
        ws.send(JSON.stringify({ id, method, params }));
    });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const evaluate = async (expression) => {
    const r = await send('Runtime.evaluate', { expression, returnByValue: true });
    if (r.exceptionDetails) {
        throw new Error(r.exceptionDetails.exception?.description || 'evaluate failed');
    }
    return r.result.value;
};

await send('Page.enable');
if (url) {
    await send('Page.navigate', { url });
    for (let waited = 0; waited < 60000 && !events.includes('Page.loadEventFired'); waited += 500) {
        await sleep(500);
    }
    await sleep(3000);
}

const sel = JSON.stringify(selector);
const count = await evaluate(`document.querySelectorAll(${sel}).length`);
if (!count) {
    console.error(`selector matched 0 elements: ${selector}`);
    process.exit(2);
}
if (count > 20) {
    console.error(`selector matched ${count} elements - tighten it (max 20)`);
    process.exit(2);
}

// Redraws every box at current viewport coordinates and returns per-element full visibility.
const draw = `(() => {
    document.querySelectorAll('.cdp-highlight').forEach((e) => e.remove());
    const els = [...document.querySelectorAll(${sel})];
    els.forEach((el) => {
        const r = el.getBoundingClientRect();
        const d = document.createElement('div');
        d.className = 'cdp-highlight';
        d.style.cssText = 'position:fixed;border:4px solid red;z-index:2147483647;'
            + 'pointer-events:none;box-sizing:border-box;'
            + 'left:' + (r.left - 6) + 'px;top:' + (r.top - 6) + 'px;'
            + 'width:' + (r.width + 12) + 'px;height:' + (r.height + 12) + 'px;';
        document.body.appendChild(d);
    });
    return els.map((el) => {
        const r = el.getBoundingClientRect();
        return r.top >= 6 && r.left >= 6 && r.bottom <= innerHeight - 6 && r.right <= innerWidth - 6;
    });
})()`;

const stamp = Date.now();
const covered = new Set();
for (let i = 0; i < count; i++) {
    if (covered.has(i)) continue;
    await evaluate(`document.querySelectorAll(${sel})[${i}].scrollIntoView({block:'center',inline:'nearest'})`);
    await sleep(400);
    const visible = await evaluate(draw);
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    const path = `/tmp/claude-chrome-highlight-${stamp}-${i}.png`;
    fs.writeFileSync(path, Buffer.from(shot.data, 'base64'));
    console.log(path);
    covered.add(i);
    visible.forEach((v, j) => v && covered.add(j));
}

await evaluate(`document.querySelectorAll('.cdp-highlight').forEach((e) => e.remove())`);
ws.close();
