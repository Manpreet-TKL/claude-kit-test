// Manpreet 24/07/2026
// Opens a tab to the extension's own options page after Chrome settles - chained after
// oe-login.mjs in the same background job (see startOeAutoLogin in entrypoint.sh) so this
// new tab is never one of the "extras" that script's own CDP-startup pass collapses away.
// Lets the one-time extension login (see docs/chrome-agent.md) sit ready in noVNC with no
// manual navigation. Non-fatal on failure - falls back to the manual URL in the docs.
//
// Env: CDP_PORT (9222), EXTENSION_ID (required). Pure Node - no dependencies.

const env = (k, d) => process.env[k] ?? d;
const CDP = `http://127.0.0.1:${env('CDP_PORT', '9222')}`;
const EXTENSION_ID = env('EXTENSION_ID', '');
if (!EXTENSION_ID) {
  console.log('EXTENSION_ID not set - skipping options tab');
  process.exit(0);
}

const url = `chrome-extension://${EXTENSION_ID}/options.html`;
const res = await fetch(`${CDP}/json/new?${url}`, { method: 'PUT' });
if (!res.ok) throw new Error(`open options tab: HTTP ${res.status}`);
console.log(`opened options tab: ${url}`);
