#!/usr/bin/env node
/* Build the dock bundle: the upstream clean-home wrappers are appended to YOUR
 * unmodified vendor launcher bundle. Vendor bytes stay byte-identical; only the
 * generated tail is new. The result contains OEM code, so keep it private.
 *
 *   node build-dock.mjs                 # -> pull/home.js + pull/assets/*.png
 *   OUT=pull/other.js node build-dock.mjs
 *   DOCK_ROOT=/path/to/repo node build-dock.mjs
 */
import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const ROOT = process.env.DOCK_ROOT || process.cwd();
const STOCK = path.join(ROOT, 'pull', 'app.js');
const REF = path.join(ROOT, 'ref', 'clean-home', 'build.mjs');

// sha256 of the stock launcher this build was verified against:
// Hisense 43A53FEVS, MTK9602, VIDAA U9, V0000.09.09F.P0930.
// A different firmware needs its own hash. Do not set STOCK_SHA just to silence
// the check unless you have a backup and accept the risk.
const STOCK_SHA = process.env.STOCK_SHA ||
  '42ff3268aa9a0e65b1713439c9dad26e6f48c4d7ce1475da1e4364b71c44d9d1';
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const md5 = b => crypto.createHash('md5').update(b).digest('hex');

if (!fs.existsSync(REF)) {
  console.error('Missing ref/clean-home. See ref/README.md for the clone + patch steps.');
  process.exit(1);
}
if (!fs.existsSync(STOCK)) {
  console.error('Missing ' + STOCK + '. Copy your TV\'s stock launcher bundle there.');
  process.exit(1);
}
if (process.env.STOCK_SHA) {
  console.warn('WARN: STOCK_SHA overridden. Verify pull/app.js is the bundle you backed up.');
}
const { assemble } = await import(pathToFileURL(REF).href);

const stock = fs.readFileSync(STOCK);
if (sha(stock) !== STOCK_SHA) throw new Error('stock hash mismatch: ' + sha(stock));

// storeAppId stays null until the real Store app id is read from the dock's
// app list. No local icon overrides, no video media -> static gradient bg.
const config = {
  version: 1,
  storeAppId: null,
  icons: {},
  media: [],
  defaults: { home: null, saver: null },
};

// Empty stock => the exact generated tail, so the vendor prefix cannot be
// re-encoded or altered.
const tail = assemble(Buffer.alloc(0), null, config, { homeOnly: true })['home.js'];
if (typeof tail !== 'string' || !tail.length) throw new Error('empty tail');

const out = Buffer.concat([stock, Buffer.from(tail, 'utf8')]);
const head = out.subarray(0, stock.length);
if (!head.equals(stock)) throw new Error('vendor prefix changed');

if (!Buffer.from(stock.toString('utf8'), 'utf8').equals(stock)) throw new Error('stock is not valid utf8');
new vm.Script(out.toString('utf8'), { filename: 'home.js' });

const OUT = process.env.OUT || 'pull/home.js';
fs.writeFileSync(path.join(ROOT, OUT), out);
fs.mkdirSync(path.join(ROOT, 'pull', 'assets'), { recursive: true });
for (const n of ['metal-icon-atlas.png', 'metal-tab-atlas.png']) {
  fs.copyFileSync(path.join(ROOT, 'ref', 'clean-home', n), path.join(ROOT, 'pull', 'assets', n));
  fs.copyFileSync(path.join(ROOT, 'ref', 'clean-home', n), path.join(ROOT, 'pull', n));
}

const assets = ['metal-icon-atlas.png', 'metal-tab-atlas.png'].map(n => {
  const b = fs.readFileSync(path.join(ROOT, 'pull', 'assets', n));
  return { n, bytes: b.length, sha256: sha(b), md5: md5(b) };
});

console.log(JSON.stringify({
  stockBytes: stock.length,
  tailBytes: Buffer.byteLength(tail),
  outBytes: out.length,
  outSha256: sha(out),
  outMd5: md5(out),
  assets,
}, null, 1));

// Paste these into the TV scripts when running them from a boot hook where
// environment overrides are awkward (see README, "Install").
console.log('\n# stage.sh / apply.sh values for this build');
console.log('NEW_MD5=' + md5(out) + ' NEW_SIZE=' + out.length +
  ' ICON_MD5=' + assets[0].md5 + ' TAB_MD5=' + assets[1].md5);
