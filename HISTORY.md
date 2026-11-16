# Build history

Dates are local (Europe/Berlin). Sizes and hashes are for the reference TV:
Hisense 43A53FEVS, MTK9602, VIDAA U9, `V0000.09.09F.P0930`. Every build keeps the
stock prefix byte-identical; only the appended tail changes.

## 2026-11-14 — groundwork

- OTA freeze installed separately (`/var/local/tvfw`): boot re-applies two hosts
  pins and a reject rule; no effect on the dock.
- Home revert guard v2 written and tested in a fake tree: trial counter, alive
  marker, full `launcher/` + cobalt-cache restore, md5 manifest, cache-wipe.
- Read-only pull of the stock launcher: 293,330 B,
  md5 `e988dfe7992a8d2eecea72c24896de05`,
  sha256 `42ff3268aa9a0e65b1713439c9dad26e6f48c4d7ce1475da1e4364b71c44d9d1`.
  Confirmed the `/Launcher` route shape and the SDK surface in the real bytes.
- Learned the hard parts: swapping `app.js` requires dropping Cobalt's compiled
  JS cache; the APM does not reliably respawn the engine, so a cold power cycle
  is the only proven path; install must write `app.js.new`, chown 305:305,
  chmod 0664 and rename atomically.

## 2026-11-15 — first live dock

- v1 (German, `42e08a…`, 359,619 B): upstream wrappers + CleanFrame-first patch,
  empty config (no local icons, no video media), static gradient background.
  Guard and backups installed, trial applied, power-cycled: dock rendered with
  no stock Home flash. `accept.sh` disarmed the trial.
- English pass (`e24c5eb6…`, 359,425 B): all UI strings translated; upstream
  `check-bundle.mjs` relaxed only for the video-status assertion.
- tvOS-style hero attempt (`29700ab7…`, 360,727 B): blurred focused artwork,
  hero title/hint, one raised row. Held for feedback; the lagging background
  was fixed by using `index` on the shelf row instead of `appIndex`.
- Two-row redesign (`ae630a21…`, 364,591 B): hero text removed, apps and inputs
  rows, bigger artwork.
- v3 (`c22ac6b1…`, 362,628 B): bare six-column grid, crossfaded artwork.
- v4 (`36df2121…`, 365,523 B): full-bleed per-app wash, bottom-anchored grid,
  hidden tabs, first Default-menu escape attempt.
- v5 (`45f46a0c…`, 367,002 B): four per row in a frosted drawer, glass clock.
- v6 / build v8 (`2bb093ca…`, 367,853 B): resting peek + slide-up drawer; the
  frosted bar covers the top row only.
- v7 / build v9 (`67764473…`, 368,192 B): six rectangular 3:2 cards per row.
- v8 / build v10 (`72943d56…`, 368,611 B): glass focus on the card, frosted bar
  stays one row.
- v9 / build v11 (`0ce0bb55…`, 368,611 B): row gap 44 → 64, column gap 32 → 40;
  derived pitch 234, card 260×170, resting top 761, open drawer top 584/350.
- v9 fixes / build v12 (`3cf0d2b7…`, 368,869 B): OEM escape hatch changed from
  a fake `vidaa-home` app record to the captured stock route component; stray
  utility rows and edge fades hidden on Home; clock box centred on the tab line.
- v10 / build v13 (`6d83cec0…`, 370,245 B): cards use the app's own icon artwork
  over `#10141b`; `appColor` only feeds the wash; clock back to block text with
  `text-align:center`; Default menu renders the real OEM home lazily, one-way,
  with a 1.5 s error fallback.
- v10 / build v14 (`4c092dc2…`, 370,192 B): icon image always fills the card
  (`background-size:100% 100%`); rim, sheen, shadow and `scale(1.06)` are
  focus-only. Clock box moved to `left:1652` after pixel-measuring the rendered
  preview: ink centre 1737.5 px vs pill centre 1737 px. This is the current
  install and the reference for `stage.sh`/`apply.sh`.

## Rehearsal status

`test-l3-local.sh` covers backup, stage over `/dev/tcp`, refuse-without-guard,
apply, double-apply refusal, update-apply, accept, guard disarm, marker restore
with cache, and the post-restore wipe: **35/35** checks.

`verify-dock.mjs` covers route swap, CleanFrame-first ordering, launch payload,
listener cleanup, OEM fallback, app-id guard, card fill, focus-only effects,
clock centring and the captured-stock-home path.

## Deliberately not done

- Moonlight/game streaming: needs an unpublished ARM32 binary, a private seed
  bundle and a phoenix service; the installer overwrites `autoStart` and was
  only verified on a different SoC/firmware. Not worth it on this Wi-Fi module.
- Jellyfin integration in the dock: Jellyfin is installed as a normal app via
  the store and ticked in Edit Home. No special-case code.
- Camera/HKSV work: not started.
