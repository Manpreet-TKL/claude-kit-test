// Manpreet 25/07/2026
// Seeds the Claude in Chrome extension's chrome.storage.local for a FRESH profile: the
// saved claude.ai sign-in (OAuth tokens) restored from the kit's state file, plus an
// "always allow" site grant for OE_URL so the walk never needs the one-time noVNC
// approval click. Both live in a LevelDB store the extension owns for the lifetime of
// the Chrome process, so this must run before Chrome starts (see entrypoint.sh) - once
// Chrome is up it holds the file lock and an external writer can't reach it.
//
// The kit persists ~1KB of JSON rather than a whole Chrome profile: everything the
// extension needs to come up signed-in and pre-approved is these few keys (see
// save-state.sh for the other half of the round trip). Idempotent - runs on every boot.
//
// Env: EXTENSION_ID, CHROME_PROFILE_DIR (required, else no-op); OE_URL (optional - skips
//      the site grant when unset); STATE_FILE (optional - skips the sign-in restore when
//      unset or absent).
// Exit: always 0 - a seeding failure degrades to a manual /login + approval click, it
// doesn't block the container from starting.

import { ClassicLevel } from 'classic-level';
import crypto from 'node:crypto';
import fs from 'node:fs';

const env = (k) => process.env[k] || '';
const OE_URL = env('OE_URL').replace(/\/$/, '');
const EXTENSION_ID = env('EXTENSION_ID');
const PROFILE_DIR = env('CHROME_PROFILE_DIR');
const STATE_FILE = env('STATE_FILE');

if (!EXTENSION_ID || !PROFILE_DIR) {
  console.log('EXTENSION_ID/CHROME_PROFILE_DIR not set - skipping extension seed');
  process.exit(0);
}

const dbPath = `${PROFILE_DIR}/Default/Local Extension Settings/${EXTENSION_ID}`;

// Only these keys round-trip. The rest of the store is a per-install cache (`features`,
// ~230KB) or per-boot scratch (`anonymousId`, `bridgeDeviceId`, `codeVerifier`,
// `oauthState`, `tabGroups`, `mcpConnected`) that the extension rebuilds by itself -
// restoring them would pin stale values onto a new install for no gain.
const RESTORE_KEYS = [
  'accessToken',
  'refreshToken',
  'tokenExpiry',
  'accountUuid',
  'lastActiveOrgHint',
  'permissionStorage',
];

function readState() {
  if (!STATE_FILE || !fs.existsSync(STATE_FILE)) return null;
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  } catch (e) {
    console.log(`state file unreadable (${e.message}) - continuing without a restore`);
    return null;
  }
}

// The grant list the extension consults per navigation. Merged rather than replaced so a
// restored state file keeps every origin it already knew about.
function withSiteGrant(permissionStorage) {
  if (!OE_URL || OE_URL === 'about:blank') return permissionStorage;
  const netloc = OE_URL.replace(/^[a-z]+:\/\//, '').split('/')[0].split(':')[0];
  const current = permissionStorage ?? { permissions: [] };
  current.permissions ??= [];
  const granted = current.permissions.some(
    (p) => p.scope?.netloc === netloc && p.action === 'allow' && p.duration === 'always',
  );
  if (granted) {
    console.log(`always-allow permission already present for ${netloc}`);
    return current;
  }
  current.permissions.push({
    action: 'allow',
    createdAt: Date.now(),
    duration: 'always',
    id: crypto.randomUUID(),
    scope: { netloc, type: 'netloc' },
  });
  console.log(`seeded always-allow permission for ${netloc}`);
  return current;
}

try {
  const state = readState();
  const db = new ClassicLevel(dbPath, { valueEncoding: 'json', keyEncoding: 'utf8' });
  await db.open();

  let restored = 0;
  for (const key of RESTORE_KEYS) {
    if (key === 'permissionStorage' || state?.[key] === undefined) continue;
    await db.put(key, state[key]);
    restored += 1;
  }

  let permissionStorage = state?.permissionStorage;
  if (permissionStorage === undefined) {
    try {
      permissionStorage = await db.get('permissionStorage');
    } catch (e) {
      if (e.code !== 'LEVEL_NOT_FOUND') throw e;
    }
  }
  const merged = withSiteGrant(permissionStorage);
  if (merged !== undefined) await db.put('permissionStorage', merged);

  await db.close();
  console.log(
    restored > 0
      ? `restored claude.ai sign-in (${restored} keys) from ${STATE_FILE}`
      : 'no saved claude.ai sign-in to restore - the extension will ask for one',
  );
} catch (e) {
  console.log(`extension seed skipped - ${e.message} (falls back to a manual sign-in + "always allow" click)`);
}
