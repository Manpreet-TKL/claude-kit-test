// Manpreet 25/07/2026
// Reads the Claude in Chrome extension's sign-in + site grants back out of a COPY of its
// chrome.storage.local LevelDB and prints them as the state JSON seed-extension-state.mjs
// consumes. Run against a copy, never the live store: Chrome holds the original's file
// lock for its whole lifetime (save-state.sh does the copying).
//
// A copy taken while Chrome is writing can end with a torn record; LevelDB just stops at
// the checksum failure, so the read succeeds with slightly stale values. That is why this
// refuses to print anything unless accessToken and refreshToken both came back - a
// half-read state file would overwrite a good one with an unusable login.
//
// Env: DB_PATH (required) - the copied LevelDB directory.
// Exit: 0 with JSON on stdout, 1 with a reason on stderr.

import { ClassicLevel } from 'classic-level';

const DB_PATH = process.env.DB_PATH || '';
if (!DB_PATH) {
  console.error('DB_PATH not set');
  process.exit(1);
}

const KEYS = [
  'accessToken',
  'refreshToken',
  'tokenExpiry',
  'accountUuid',
  'lastActiveOrgHint',
  'permissionStorage',
  'bridgeDeviceId',
];
const REQUIRED = ['accessToken', 'refreshToken'];

const db = new ClassicLevel(DB_PATH, { valueEncoding: 'json', keyEncoding: 'utf8' });
await db.open();

const state = {};
for (const key of KEYS) {
  try {
    state[key] = await db.get(key);
  } catch (e) {
    if (e.code !== 'LEVEL_NOT_FOUND') throw e;
  }
}
await db.close();

const missing = REQUIRED.filter((k) => state[k] === undefined);
if (missing.length) {
  console.error(`refusing to save - missing ${missing.join(', ')} (is the extension signed in?)`);
  process.exit(1);
}

console.log(JSON.stringify(state, null, 2));
