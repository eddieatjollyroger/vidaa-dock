/* Offline smoke test of the generated tail against a synthetic vendor module.
 * Mirrors check-bundle.mjs fixtures; no TV, no network, no vendor bytes. */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { assemble } from './ref/clean-home/build.mjs';

const config = { version: 1, storeAppId: null, icons: { cleanframehome: 'cf.png', 1: 'nf.png', 2: 'zdf.png', 3: 'tw.png' }, media: [], defaults: { home: null, saver: null } };
const tail = assemble(Buffer.alloc(0), null, config, { homeOnly: true })['home.js'];

const fixture = `self.fixtureHome={route:[{path:'/Launcher',component:{name:'StockHome'}},{path:'/Other',component:{name:'Other'}}]};self._V_M_={launcher:function(){return self.fixtureHome;}};`;

const apps = [
  { appId: 'cleanframehome', appName: 'CleanFrame Home', url: 'http://127.0.0.1:4795/home/', storeType: 'hisense', typeCode: '600002' },
  { appId: '1', appName: 'Netflix' },
  { appId: '2', appName: 'ZDF' },
  { appId: '3', appName: 'Twitch' },
  { appId: '4', appName: 'App 4' },
  { appId: '5', appName: 'App 5' },
  { appId: '6', appName: 'App 6' },
  { appId: '7', appName: 'App 7' },
  { appId: '8', appName: 'App 8' },
  { appId: '9', appName: 'App 9' },
];
const sources = Array.from({ length: 5 }, (_, i) => ({ sourceId: 'source-' + i, name: 'Input ' + i }));

function environment(modern = false) {
  const listeners = new Map(), messages = new Map(), saved = new Map(), launched = [], timers = new Map(), invoked = [];
  let timer = 0, current = '/Launcher';
  const K = { LEFT: 37, RIGHT: 39, UP: 38, DOWN: 40, ENTER: 13, BACK: 8, RETURN: 27, SOURCE: 1000 };
  const sdk = {
    key: { KEYMAP: K },
    storage: { get: k => saved.get(k), set: (k, v) => saved.set(k, v) },
    router: { isCurrentPathEqualTo: p => current === p, back: () => { current = '/Launcher'; } },
    message: { on: (n, f) => messages.set(n, f), off: (n, f) => { if (messages.get(n) === f) messages.delete(n); }, emit: () => {} },
    apc: { CMDMETHOD: modern ? { LAUNCHER_RECOMMEND: '52' } : { REMOTECONTROL: '2', KEY_INPUT_START: '21' }, start: a => { launched.push(a); current = '/App'; } },
    me: {
      req: () => ({
        getData: (key, arg) => {
          if (key === 'getCurrentShowApps') { assert.equal(arg, 'Launcher'); return { result: apps }; }
          if (key === 'getAllInputsData') return { result: sources };
          assert.equal(key, 'getAppInfoByAppId');
          return { result: apps.find(a => a.appId === arg.appId) };
        },
        open: () => {}, invoke: (...a) => { invoked.push(a); },
      }),
    },
  };
  const root = {
    innerWidth: 1920, Image: class {}, addEventListener: () => {}, removeEventListener: () => {},
    _V_SDK_: { vre: { SDK: function () { return sdk; } } },
    document: { hidden: false, addEventListener: () => {}, removeEventListener: () => {}, body: {
      addEventListener: (n, f) => { if (!listeners.has(n)) listeners.set(n, new Set()); listeners.get(n).add(f); },
      removeEventListener: (n, f) => listeners.get(n)?.delete(f),
    } },
  };
  const context = { self: root, console, Date, Array, JSON, Math, String, Number, Object, setTimeout: (f, ms) => { timers.set(++timer, { f, ms }); return timer; }, clearTimeout: id => timers.delete(id), setInterval: () => ++timer, clearInterval: () => {} };
  return { root, context, sdk, launched, invoked, messages, listeners, timers, setRoute: p => (current = p) };
}

function instance(component) {
  const result = { ...component.data(), $nextTick: f => f() };
  for (const [name, method] of Object.entries(component.methods)) result[name] = method.bind(result);
  return result;
}
const h = (tag, data, children) => ({ tag, data, children: children || [] });

const e = environment();
vm.runInNewContext(fixture + '\n' + tail, e.context);
const registry = e.root._V_M_.launcher();
assert.equal(registry.route[1].component.name, 'Other', 'unrelated route survives');
const component = registry.route[0].component;
assert.equal(component.name, 'Launcher');
const ui = instance(component);
component.mounted.call(ui);
const tree = component.render.call(ui, h);
assert.equal(tree.data.attrs.id, 'owner-native-home');
// Apple TV-style home: bottom-anchored 6-column icon grid, full-bleed crossfaded
// wash (no zoomed artwork), no labels, no paging dots, tabs hidden until UP.
const flat = (n, out = []) => { for (const c of n.children || []) { if (!c) continue; if (Array.isArray(c)) flat({ children: c }, out); else { out.push(c); flat(c, out); } } return out; };
const keysOf = tree => flat(tree).map(c => c.data && String(c.data.key || '')).filter(Boolean);
const byKey = k => flat(component.render.call(ui, h)).find(c => c.data && c.data.key === k);
const artOf = k => { const n = byKey(k); return n && flat(n).find(c => c.data && c.data.key === 'art'); };
const homeKeys = keysOf(tree);
assert.ok(homeKeys.includes('hero-art-a') && homeKeys.includes('hero-art-b'), 'two crossfade wash layers');
assert.ok(!homeKeys.includes('hero-title'), 'no title text');
assert.ok(!homeKeys.includes('hero-hint'), 'no "Press OK" hint');
assert.ok(homeKeys.includes('home-panel'), 'home panel present');
assert.equal(homeKeys.filter(k => k.startsWith('dot-')).length, 0, 'no paging dots');
assert.equal(homeKeys.filter(k => k.startsWith('app-')).length, 10, 'both rows are rendered; the second one is only half on screen');

// tabs are hidden on the clean home and only appear when focus goes up
assert.ok(!homeKeys.includes('nav-0'), 'no tab bar on the bare home screen');
assert.ok(!homeKeys.includes('top-scrim'), 'no top scrim until the tabs show');

// resting state: six rectangular cards per row, second row peeking, glass on the top row only
assert.equal(byKey('app-cleanframehome').data.style.left, '80px', 'six 260 px columns, centred');
assert.equal(byKey('app-cleanframehome').data.style.width, '260px', 'cards are wider than they are tall');
assert.equal(byKey('app-cleanframehome').data.style.height, '170px', '3:2 rounded card, not a square');
assert.equal(byKey('app-cleanframehome').data.style.top, '761px', 'top row rests near the bottom');
assert.equal(byKey('app-6').data.style.top, '995px', 'second row peeks 85 px - half a card - above the edge');
assert.equal(Number(String(byKey('app-6').data.style.top).replace('px','')) - Number(String(byKey('app-cleanframehome').data.style.top).replace('px','')) - 170, 64, '64 px of daylight between rows');
assert.equal(ui.drawerOpen, false, 'drawer starts closed');
const drawer = byKey('home-drawer');
assert.ok(drawer, 'frosted glass behind the top row');
assert.equal(drawer.data.style.top, '723px', 'glass hugs the top row only');
assert.equal(drawer.data.style.height, '246px', 'a bar, not a full drawer');
assert.ok(!homeKeys.includes('date'), 'no date on Home');
assert.ok(!homeKeys.includes('utility-0'), 'no utility list is built on Home');
assert.equal(byKey('utility-panel').data.style.visibility, 'hidden', 'the utility panel cannot cover the dock');
assert.equal(byKey('left-edge').data.style.visibility, 'hidden', 'the left edge fade stays off the grid');
assert.equal(byKey('right-edge').data.style.visibility, 'hidden', 'the right edge fade stays off the grid');
assert.ok(byKey('clock-glass'), 'clock sits in a glass pill');
assert.equal(byKey('clock-glass').data.style.top, '63px', 'clock pill shares the tab row top');
assert.equal(byKey('clock-glass').data.style.height, '70px', 'clock pill shares the tab row height');
assert.equal(byKey('clock-glass').data.style.borderRadius, '35px', 'clock pill keeps its round ends');
assert.equal(byKey('clock').data.style.top, '63px', 'clock text box matches the pill');
assert.equal(byKey('clock').data.style.height, '70px', 'clock text box fills the pill');
assert.equal(byKey('clock').data.style.textAlign, 'center', 'clock digits stay horizontally centred');
assert.equal(byKey('clock').data.style.display, undefined, 'no flex: Cobalt right-aligned the digits with it');
assert.equal(byKey('clock').data.style.paddingTop, '2px', 'glyphs nudge 2 px down to sit optically centred');
assert.equal(byKey('clock').data.style.left, '1652px', 'box shifts 4 px right so the drawn digits sit centred');
assert.equal(byKey('clock-glass').data.style.left, '1634px', 'the pill itself does not move');
// the icon image is always stretched to fill the card, exactly as it looks on
// the focused card; the glass rim, sheen, shadow and size bump stay focus-only
const focusedArt = artOf('app-cleanframehome');
const idleArt = artOf('app-1');
for (const [key, art] of [['focused', focusedArt], ['idle', idleArt]]) {
  assert.match(String(art.data.style.backgroundImage), /url\("file:\/\/\/hisenseUI\//, key + ' card keeps the app artwork');
  assert.equal(art.data.style.backgroundSize, '100% 100%', key + ' card stretches the icon to fill the tile');
  assert.equal(art.data.style.backgroundColor, '#10141b', key + ' card keeps the neutral fallback');
}
assert.match(String(focusedArt.data.style.border), /^2px solid rgba\(255,255,255/, 'focused card carries the glass rim');
assert.match(String(focusedArt.data.style.backgroundImage), /^linear-gradient\(152deg,rgba\(255,255,255,\.30\)/, 'and the sheen sits over the icon');
assert.equal(focusedArt.data.style.transform, 'scale(1.06)', 'focus grows the whole button');
assert.equal(focusedArt.data.style.boxShadow.startsWith('inset'), true, 'and lifts it');
assert.equal(idleArt.data.style.border, 'none', 'unfocused cards have no rim');
assert.ok(!/linear-gradient/.test(String(idleArt.data.style.backgroundImage)), 'and no sheen');
assert.equal(idleArt.data.style.transform, 'scale(1)', 'unfocused cards sit at their resting size');
assert.equal(homeKeys.filter(k => k === 'glass').length, 0, 'no separate unscaled ring is drawn');

// clock is back and is a real 24h HH:MM
const clock = byKey('clock');
assert.ok(clock, 'clock shown on Home');
assert.match(String(clock.children[0]), /^\d\d:\d\d$/, 'clock renders HH:MM');

const layers = () => flat(component.render.call(ui, h)).filter(c => c.data && /^hero-art-/.test(c.data.key));
const visible = () => layers().filter(c => c.data.style.opacity !== '0');
assert.equal(layers().length, 2, 'exactly two wash layers');
assert.equal(visible().length, 1, 'exactly one wash layer is visible');
assert.match(visible()[0].data.style.backgroundImage, /rgba\(91,124,250/, 'wash starts on the CleanFrame colour');
assert.ok(!/blur|880px/.test(visible()[0].data.style.backgroundImage + visible()[0].data.style.filter || ''),
  'background is not a blurred, zoomed icon any more');
assert.equal(ui.artSlot, 1, 'slot b is live on first paint');

ui.handleKey(39);   // right -> Netflix
assert.equal(ui.index, 1, 'RIGHT moves one tile');
assert.equal(ui.artSlot, 0, 'wash slot flips so the new layer fades in');
assert.match(visible()[0].data.style.backgroundImage, /rgba\(229,9,20/, 'wash follows focus immediately');
assert.equal(visible()[0].data.key, 'hero-art-a', 'the other layer carries the new colour');
ui.handleKey(39); ui.handleKey(39); ui.handleKey(39); ui.handleKey(39);
assert.equal(ui.index, 5, 'RIGHT walks to the end of the six-tile top row');
assert.equal(ui.drawerOpen, false, 'the top row does not open the drawer');
ui.handleKey(39);
assert.equal(ui.index, 6, 'RIGHT past the end of a row wraps to the next row');
assert.equal(ui.drawerOpen, true, 'and that opens the drawer');
assert.equal(byKey('app-cleanframehome').data.style.top, '584px', 'the drawer slides up');
assert.equal(byKey('app-6').data.style.top, '818px', 'revealing the whole second row');
assert.equal(byKey('home-drawer').data.style.top, '546px', 'the frosted bar slides up with the drawer');
assert.equal(byKey('home-drawer').data.style.height, '246px', 'but it still wraps the top row only');
ui.handleKey(37); ui.handleKey(37); ui.handleKey(37); ui.handleKey(37); ui.handleKey(37); ui.handleKey(37);
assert.equal(ui.index, 0, 'LEFT walks back across rows');
assert.equal(ui.drawerOpen, false, 'back on the top row the drawer settles down again');
assert.equal(ui.artSlot, 1, 'wash slot flips again on the way back');
assert.match(visible()[0].data.style.backgroundImage, /rgba\(91,124,250/, 'wash is back on the CleanFrame colour');
assert.equal(visible()[0].data.key, 'hero-art-b', 'the other layer carries it');

ui.handleKey(40);   // down -> second row, same column
assert.equal(ui.index, 6, 'DOWN jumps a whole row of six');
assert.equal(ui.drawerOpen, true, 'DOWN from the top row opens the drawer');
ui.handleKey(40);
assert.equal(ui.index, 9, 'DOWN again lands on the short last row');
ui.handleKey(40);
assert.equal(ui.index, 9, 'DOWN on the last row does nothing');
ui.handleKey(38);
assert.equal(ui.index, 3, 'UP returns to the row above, keeping the column');
assert.equal(ui.drawerOpen, false, 'closing again on the way back');
ui.handleKey(38);
assert.equal(ui.zone, 'top', 'UP from the first row reaches the tabs');
const topKeys = keysOf(component.render.call(ui, h));
assert.ok(topKeys.includes('nav-0'), 'tab bar appears with the tabs focused');
assert.ok(topKeys.includes('top-scrim'), 'top scrim appears with the tab bar');
ui.handleKey(40);   // back into the grid
assert.equal(ui.zone, 'shelf', 'DOWN from the tabs returns to the grid');
assert.equal(ui.index, 3, 'grid focus is remembered');
assert.ok(!keysOf(component.render.call(ui, h)).includes('nav-0'), 'tab bar hides again');

// clock survives standby: the first key after a frozen timer re-syncs it
ui.now = new Date(0); ui._nowMs = 0;
ui.armSaver();
assert.ok(ui.now.getTime() > 0, 'clock re-syncs on the first key after wake');

ui.zone = 'shelf'; ui.index = 0; ui.appIndex = 0;   // back to the first tile
assert.equal(ui.shelf()[0].appId, 'cleanframehome', 'CleanFrame is first on the shelf');
assert.deepEqual(Array.from(ui.shelf(), a => a.appId), ['cleanframehome', '1', '2', '3', '4', '5', '6', '7', '8', '9'], 'all ten apps are on the shelf');
ui.select();
assert.equal(e.launched.length, 1, 'select launches');
assert.deepEqual(JSON.parse(JSON.stringify(e.launched[0])), {
  name: 'CleanFrame Home', appId: 'cleanframehome', url: 'http://127.0.0.1:4795/home/',
  storeType: 'hisense', startMethod: '2', typeCode: '600002',
});
// TV -> Default menu opens the OEM all-apps route. The dock only replaces the
// /Launcher component, so no stock home component or vidaa-home app record
// exists; the OEM route needs no APC id and changes no files.
assert.equal(e.launched.length, 1, 'selecting the first tile launched exactly once');
ui.show('tv');
assert.deepEqual(Array.from(ui.list()), ['TV Settings', 'All Apps', 'Edit Home', 'Screen Saver', 'Wallpaper', 'Default menu'], 'default menu entry is in the TV menu');
assert.equal(byKey('left-edge').data.style.visibility, 'visible', 'edge fades return on the scrolling All Apps strip');
assert.equal(byKey('utility-panel').data.style.visibility, 'visible', 'the utility panel works on other views');
assert.equal(e.launched.length, 1, 'the TV menu itself launches nothing');

// more than three rows: the drawer scrolls vertically instead of growing
ui.show('home');
ui.index = 0; ui.scrollRow = 0; ui.clamp();
// The auto-ordered shelf is capped at 18 (= three rows of six), so only an
// uncapped pinned-favourites list can reach the fourth row.
ui.apps = ui.apps.concat(['x1', 'x2', 'x3', 'x4', 'x5', 'x6', 'x7', 'x8', 'x9', 'x10'].map(n => ({ appId: n, appName: 'X' + n })));
ui.favorites = ui.apps.map(a => String(a.appId));
assert.equal(ui.shelf().length, 20, 'pinned favourites are not capped');
ui.index = 19; ui.clamp();
assert.equal(ui.scrollRow, 1, 'focus on the fourth row scrolls the drawer up one row');
const scrollKeys = keysOf(component.render.call(ui, h));
assert.ok(!scrollKeys.includes('app-cleanframehome'), 'scrolled-out row is not rendered');
assert.ok(scrollKeys.includes('app-x10'), 'the last row is rendered');
assert.equal(byKey('app-cleanframehome'), undefined);
ui.handleKey(38);
assert.equal(ui.index, 13, 'UP moves one row');
assert.equal(ui.scrollRow, 1, 'the window stays scrolled while row 2 is still visible');
ui.handleKey(38); ui.handleKey(38);
assert.equal(ui.index, 1);
assert.equal(ui.scrollRow, 0, 'back at the top the drawer returns to rest');

component.deactivated.call(ui);
component.beforeDestroy.call(ui);
assert.equal(e.listeners.get('key-down').size, 0);
assert.equal(e.messages.size, 0);

// TV -> Default menu renders the OEM launcher component captured by the entry
// wrapper. No route push (the All Apps route painted a black page because the
// stock home behind it was gone), no APC launch and no file writes.
const esc = environment();
vm.runInNewContext(fixture + '\n' + tail, esc.context);
const escComponent = esc.root._V_M_.launcher().route[0].component;
assert.equal(escComponent.name, 'Launcher', 'the dock still owns the /Launcher route');
assert.equal(esc.root.CleanHomeStockHome && esc.root.CleanHomeStockHome.name, 'StockHome', 'the OEM component is captured before the swap');
const escUI = instance(escComponent);
escComponent.mounted.call(escUI);
escUI.show('tv'); escUI.index = 5;
escUI.select();
assert.equal(escUI.stockMode, true, 'default menu switches to the OEM home');
assert.equal(esc.launched.length, 0, 'and launches no app');
assert.equal(esc.sdk.router.isCurrentPathEqualTo('/Launcher'), true, 'and navigates nowhere');
const stockTree = escComponent.render.call(escUI, h);
assert.equal(stockTree.tag && stockTree.tag.name, 'StockHome', 'the OEM component is rendered in place');
escComponent.beforeDestroy.call(escUI);

// Missing/foreign SDK keeps the OEM component.
for (const breakIt of [r => { delete r._V_SDK_; }, r => { r._V_SDK_.vre.SDK = () => { throw new Error('unsupported'); }; }]) {
  const bad = environment(); breakIt(bad.root);
  vm.runInNewContext(fixture + '\n' + tail, bad.context);
  assert.equal(bad.root._V_M_.launcher().route[0].component.name, 'StockHome');
}

// Invalid app-id (not in the native list) must not launch.
const miss = environment();
vm.runInNewContext(fixture + '\n' + tail, miss.context);
const mc = miss.root._V_M_.launcher().route[0].component, mu = instance(mc);
mc.mounted.call(mu);
assert.throws(() => mu._platform.launchApp('999'));
assert.equal(miss.launched.length, 0);
mc.beforeDestroy.call(mu);

console.log('PASS: route swap, Apple TV home (six 260x170 rounded cards per row in a frosted drawer that rests half-peeking and slides up, glass clock, full-bleed wash, no labels/dots/tabs until UP), 10-app shelf, OEM default-menu escape hatch, launch payload, cleanup, OEM fallback, app-id guard. Synthetic fixtures only.');
