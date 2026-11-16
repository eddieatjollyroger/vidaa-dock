# VIDAA native dock

An Apple-TV-style home screen for a Hisense VIDAA TV, built as a small patch on
top of [`nineodernein/hisense-vidaa-clean-home`](https://github.com/nineodernein/hisense-vidaa-clean-home).
It replaces only the `/Launcher` route of the stock launcher bundle: the original
OEM routes, app list, player and settings stay in place.

This is a personal, source-available project. It is **not** a jailbreak, an
installer for other people's TVs, or a supported product. Read
[Safety and recovery](#safety-and-recovery) before writing anything to a TV.

A static offline preview lives in `preview/mock.html`; it renders at 1920×1080
in a browser and contains no OEM code.

---

## What it looks like

- Full-bleed colour wash taken from the focused app's icon.
- Six rounded, rectangular cards per row (260×170), generous spacing.
- A frosted-glass drawer holds **only the top row**. At rest you see the top row
  and about half of the second row; pressing DOWN/RIGHT past the end of a row
  slides the drawer up so the focus can continue below.
- A liquid-glass pill with a centred clock. **No date on Home** — the date only
  appears in settings-style screens.
- Icons fill their card. The rim, sheen, drop shadow and 6% size lift are
  focus-only; an unfocused tile keeps the same filled artwork.
- English UI throughout, including long-press menus.
- A **Default** menu entry that renders the real OEM home component inside the
  dock again (one-way until the launcher reloads).

`preview/mock.html` is a static browser mock of the current geometry. It is not
the TV engine and contains no OEM code.

## Verified target

| Item | Value |
| --- | --- |
| TV | Hisense 43A53FEVS |
| SoC / panel profile | MTK9602, VIDAA U9 |
| Firmware | `V0000.09.09F.P0930` |
| Launcher bundle | `/APPS/channelA/operation-ui/apps/launcher/js/app.js` |
| Stock size / md5 | 293,330 B / `e988dfe7992a8d2eecea72c24896de05` |
| Stock sha256 | `42ff3268aa9a0e65b1713439c9dad26e6f48c4d7ce1475da1e4364b71c44d9d1` |
| Reference build v14 | 370,192 B / md5 `4c092dc2c1f36a67c11a3efe75db4165` |
| Guard | `/var/local/homeguard`, md5 `dc420ec592d2c86efa57d04557bfc411` |

The build is deterministic for this stock bundle and the empty config in
`build-dock.mjs` (no local icons, no video media). Another firmware will have a
different stock hash and may have a different launcher shape. Do not force it.

## Repository layout

```
build-dock.mjs            append the generated dock tail to pull/app.js
verify-dock.mjs           offline behaviour/geometry checks on the generated tail
test-l3-local.sh          local rehearsal of the TV install scripts (fake tree)
pull/                     TV-side scripts, guard, boot-hook guard
  preflight.sh            read-only environment/path/network check
  backup.sh               archive launcher + cobalt cache into /var/local/l3
  guard-install.sh        root swap of /var/local/homeguard.new
  selftest.sh             on-TV self-test of the guard
  stage.sh                fetch bundle + 2 atlases from the Mac, verify hashes
  apply.sh                guarded atomic install
  accept.sh               disarm the trial after the dock is seen working
  rollback.sh             arm the boot-time restore
  status.sh               read-only state summary
  diag.sh                 read-only diagnostics
  homeguard               boot-time guard (sourced by the hook)
patches/
  0001-apple-tv-dock.patch  full diff against upstream 5efad1b
ref/
  README.md               how to clone and patch upstream
preview/
  mock.html               offline 1920x1080 preview (variants via ?v=)
tools/
  serve.sh                serve pull/ on :8777 for stage.sh
LICENSE                   PolyForm Noncommercial 1.0.0
LICENSE-SCOPE.md          upstream scope note (required notice)
LICENSE.alvidaa.txt       MIT notice for upstream-derived code
LICENSE.free-my-tv.txt    MIT notice for upstream-derived code
LICENSE.metal-fx.txt      MIT notice for the ring atlases
NOTICE                    attribution and what is not distributed
HISTORY.md                build-by-build log
```

## Prerequisites

1. **A way to run a root shell on the TV.** The scripts assume a root command
   channel already exists. This repository does **not** contain the file bridge,
   the browser runner, an exploit, or root instructions. If you cannot already
   copy `pull/app.js` off the TV and run a script as root, stop here.
2. **A boot hook that sources the guard.** `apply.sh` refuses to run unless
   `/var/local/otaTest.sh` contains exactly one line like:
   ```sh
   ( [ -f /var/local/homeguard ] && . /var/local/homeguard )
   ```
   This project does not create that hook. It is what makes the trial counter
   and the automatic restore possible. Without it, there is no rollback path.
3. **Node.js 18+** on the machine that builds the bundle.
4. **A world-readable copy of the TV's stock launcher** at `pull/app.js`.
   The vendor file is not distributed here. `build-dock.mjs` checks its sha256.
5. **Busybox on the TV.** The scripts expect `/usr/local/bin/busybox` or
   `/var/local/tvtools/busybox`; this unit's busybox lacks `tr`, `xargs`,
   `dirname`, `sort` and `sha256sum`, so the scripts avoid those applets.
6. **Same LAN for TV and build machine.** `stage.sh` uses plain HTTP on port
   8777. No cloud service is involved.

## Build

```sh
# 1. Upstream source at the commit this patch was made against.
git clone https://github.com/nineodernein/hisense-vidaa-clean-home.git ref/clean-home
git -C ref/clean-home checkout 5efad1bc7e1f83e7a5fb545d293be8a4baa23af3
git -C ref/clean-home apply ../../patches/0001-apple-tv-dock.patch

# 2. Your own stock bundle (not included).
cp /path/to/your/app.js pull/app.js

# 3. Build. Writes pull/home.js and copies the two atlases to pull/assets/.
node build-dock.mjs

# 4. Offline checks.
node verify-dock.mjs
node ref/clean-home/check-bundle.mjs   # upstream check
```

`build-dock.mjs` prints the output size, sha256/md5 and the exact
`NEW_MD5=... NEW_SIZE=...` line for the install scripts. It never modifies
`pull/app.js`; it concatenates a generated tail and asserts the vendor prefix is
byte-identical.

### Preview

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1920,1080 \
  --screenshot=layout-L.png \
  "file://$PWD/preview/mock.html?v=L"
```

Variants: `L` resting, `M` open drawer, `N` tabs/clock line. Other letters are
older iterations kept for comparison.

### Local rehearsal

`test-l3-local.sh` builds a fake TV tree and runs backup → stage → apply →
accept → guard restore → cache wipe against it. It needs `pull/home.js`,
`pull/assets/*.png` and `pull/app.js` from the build above, plus macOS `md5`.
It starts a temporary server on `127.0.0.1:8777` if nothing is listening there.

```sh
bash test-l3-local.sh
# RESULT: pass=35 fail=0
```

## Install

The order matters. Every step except `stage`, `apply`, `rollback` and
`guard-install` is read-only. The guard is inert until `stage`/`apply` create
markers under `/var/local/l3`.

### 0. Serve the build to the TV

On the build machine, from the repository root:

```sh
tools/serve.sh            # python3 -m http.server 8777 --directory pull
```

Put the TV scripts on the TV once, through your existing root channel, e.g. into
`/var/local/l3/`. `stage.sh` downloads only `home.js`,
`metal-icon-atlas.png` and `metal-tab-atlas.png` from this server.

If your TV's LAN address for the build machine is not `192.168.1.126`, pass
`MAC=` and `PORT=` explicitly:

```sh
MAC=192.168.1.50 PORT=8777 sh /var/local/l3/stage.sh
```

### 1. Preflight (read-only)

```sh
sh /var/local/l3/preflight.sh
```

Check: right owner/uid, busybox applets, the launcher/cache paths, the hook
line, the free space in `/var/local`, and that the TV can reach the Mac.

### 2. Backup

```sh
sh /var/local/l3/backup.sh
```

Writes only `/var/local/l3`: `launcher.tar` (whole `launcher/`),
`launcher.md5` (every file) and `cache.tar` (the cobalt cache). It refuses to
overwrite an existing backup. This is the restore source for the guard and for
manual recovery. Keep it.

### 3. Guard

Only needed once per TV. Stage the guard and run the root half:

```sh
# copy pull/homeguard to /var/local/homeguard.new through your root channel
sh /var/local/guard-install.sh     # verifies md5 dc420ec… and size 3496
sh /var/local/l3/selftest.sh       # optional: T0..T5, expect all ok
```

The guard is sourced at boot. It does nothing without markers; with a
`trial` it counts boots, and when the count runs out it restores
`launcher.tar` + `cache.tar` and verifies every md5.

### 4. Stage

```sh
sh /var/local/l3/stage.sh
```

Fetches the bundle and atlases into `/var/local/l3`, verifies size + md5, and
writes `stage.ok`. Writes nothing under `/APPS`.

The defaults in `stage.sh` are pinned to the reference build. If your build
differs, either edit the constants at the top or run with the values printed by
`build-dock.mjs`:

```sh
NEW_MD5=<md5> NEW_SIZE=<bytes> \
ICON_MD5=<md5> TAB_MD5=<md5> PORT=8777 \
sh /var/local/l3/stage.sh
```

### 5. Apply

```sh
sh /var/local/l3/apply.sh
```

`apply.sh` checks every precondition before the first `/APPS` write:

- `stage.ok` present, backup present, guard present and armed in the hook;
- staged hash/size match the constants;
- the live `app.js` is either the known stock bundle or the previously applied
  version (update path);
- all files recorded in `launcher.md5` still match the backup.

Then it installs the two atlases, writes `app.js.new` with owner `305:305` and
mode `0664`, atomically renames it, reads the hash back, removes
`compiled_js` + `uncompiled_js`, arms `trial=4` and `cache-wipe`, and records
`applied=<md5>`. If anything fails, it stops before the rename (or reports the
post-rename mismatch) and prints `APPLY: STOP`.

**Power cycle** (unplug, wait 5 s, plug in). A cold cycle is required: the APM
does not reliably respawn the renderer after a kill. If the old Home appears
once, cycle once more so Cobalt recompiles the JS.

### 6. Accept

```sh
sh /var/local/l3/accept.sh
```

Run after the dock has rendered and you have opened an app or two. It writes
`alive`; the next boot clears the trial and disarms the countdown. Until then,
four failed boots restore the stock launcher automatically.

### Environment overrides

| Variable | Used by | Default |
| --- | --- | --- |
| `MAC`, `PORT` | `stage.sh`, `preflight.sh` | `192.168.1.126`, `8777` |
| `L` | all TV scripts | `/var/local/l3` |
| `ROOT` | backup/apply/status | `/APPS/channelA/operation-ui/apps` |
| `CACHE` | backup/apply/status | `/var/local/hisenseUI/cobalt_home/.cache` |
| `D` | apply | `/APPS/channelA/hisenseUI/static/vidaa-clean-home` |
| `GUARD`, `HOOK` | apply/status/selftest | `/var/local/homeguard`, `/var/local/otaTest.sh` |
| `STOCK_MD5`, `NEW_MD5` | apply | reference hashes above |
| `NEW_MD5`, `NEW_SIZE`, `ICON_MD5`, `TAB_MD5` | stage | reference build |
| `STOCK_SHA`, `DOCK_ROOT`, `OUT` | `build-dock.mjs` | reference hash, cwd, `pull/home.js` |

## Updating

Run `backup.sh` once (it keeps the first backup; later runs are refused), then
`stage.sh` and `apply.sh`. `apply.sh` accepts the update when the live hash
equals the recorded `applied` value. Power cycle, look at the dock, `accept.sh`.

## Safety and recovery

There is no stock Home flash on boot: the dock replaces the `/Launcher` route
inside the same module. Still, this writes to a vendor partition and changes the
boot-visible UI. Keep the backup.

Repair ladder, least destructive first:

1. **`sh /var/local/l3/rollback.sh`** → `touch /var/local/home.rollback` →
   power cycle. The guard restores the launcher and cache from
   `/var/local/l3`, verifies the manifest, then arms `cache-wipe`. A second
   cycle drops `compiled_js`/`uncompiled_js` so the stock JS recompiles.
2. If the guard cannot run (hook broken), restore manually from the backup:
   ```sh
   tar -C /APPS/channelA/operation-ui/apps -xf /var/local/l3/launcher.tar
   tar -C /var/local/hisenseUI/cobalt_home/.cache -xf /var/local/l3/cache.tar
   rm -rf /var/local/hisenseUI/cobalt_home/.cache/cobalt/compiled_js \
          /var/local/hisenseUI/cobalt_home/.cache/cobalt/uncompiled_js
   ```
   Then power cycle.
3. **Last resort:** `touch /var/local/hook.off` disarms all boot work;
   removing `/var/local/otaTest.sh` removes the hook itself; removing
   `/var/local/tvfw` stops the OTA-freeze loop if you installed that earlier.
   Removing `/var/local/pull` and `/var/local/l3` removes the install support
   files (do not do this before you have a working backup elsewhere).

Do not press **INSTALL ROOT HOOK** in unrelated tools, do not change TV DNS for
this project, and do not flash a stock Home image at boot. The dock is a route
swap, not a firmware replacement.

## Using the dock

- Favourites come from `alvidaa.freeMyTV.favorites` and are stored by app id.
  A newly installed app does not appear until you tick it in **Edit Home**.
- Long-press (OK held) opens the per-app action menu. English labels only.
- **Default** in the menu renders the OEM launcher component captured from the
  original `/Launcher` route. It is one-way until the launcher reloads; a 1.5 s
  error guard falls back to the dock if the OEM component throws.
- The clock text box is at `left:1652` inside the 1634..1840 px pill, with
  `text-align:center` and `paddingTop:2px`; the measured ink centre is within
  0.5 px of the pill centre. There is no date on
  Home by design.
- Drawer geometry: six 260×170 cards per row, pitch 234 px, 64 px between rows,
  40 px between columns. Focused cards scale 1.06. The frosted bar covers the
  top row only, including when the drawer expands.

## What is not included

- No OEM launcher bytes, no `pull/app.js`, no built `pull/home.js`, no atlases
  generated from vendor artwork. `.gitignore` keeps them out of git. The build
  output is for your own TV only; do not redistribute it.
- No root/bridge/exploit tooling and no instructions for obtaining root.
- No DNS changes, no telemetry, no analytics, no cloud calls. The only network
  traffic is the LAN HTTP fetch during `stage.sh`.
- No Moonlight/game-streaming integration: this TV's Wi-Fi module made it not
  worth pursuing. No Jellyfin-specific code; install Jellyfin through the store
  and tick it in Edit Home.
- No promise of portability. The app-id guard, excluded ids, asset paths and
  launcher shape are specific to the verified firmware.

## License and credits

The upstream project is **PolyForm Noncommercial License 1.0.0** — source-
available for noncommercial use, not an OSI open-source license. This repository
keeps that license and the upstream scope/attribution notices. See `LICENSE`,
`LICENSE-SCOPE.md`, `LICENSE.alvidaa.txt`, `LICENSE.free-my-tv.txt`,
`LICENSE.metal-fx.txt` and `NOTICE`.

Upstream: [nineodernein/hisense-vidaa-clean-home](https://github.com/nineodernein/hisense-vidaa-clean-home),
commit `5efad1b`. The dock changes are distributed as
`patches/0001-apple-tv-dock.patch`; apply them to your own clone.

Hisense, VIDAA, Apple, Netflix and all app names/logos are trademarks of their
owners. This project is not affiliated with or endorsed by any of them. You are
responsible for using it only on hardware you own or are authorised to modify.
