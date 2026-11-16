# Upstream reference

`ref/clean-home/` is intentionally empty in git. Both `build-dock.mjs` and
`verify-dock.mjs` import `./ref/clean-home/build.mjs`, so the directory must be
present locally before building.

From the repository root:

```sh
git clone https://github.com/nineodernein/hisense-vidaa-clean-home.git ref/clean-home
git -C ref/clean-home checkout 5efad1bc7e1f83e7a5fb545d293be8a4baa23af3
git -C ref/clean-home apply ../../patches/0001-apple-tv-dock.patch
```

The patch touches seven files:

- `native-dock.js` — layout, cards, clock, drawer, escape hatch
- `native-entry.js` — keep the OEM `/Launcher` component in
  `root.CleanHomeStockHome`
- `native-actions.js` — English action labels
- `native-media.js` — English media strings
- `native-platform.js` — English platform prefs
- `native-saver.js` — English screen-saver strings
- `check-bundle.mjs` — accept the English video-status text

If `git apply` reports conflicts, the upstream tree is not at `5efad1b`; check
out the exact commit instead of editing the patch.

Do not commit `ref/clean-home/`. It is upstream PolyForm/MIT source, ignored by
`.gitignore`; the patch is the only upstream-derived code distributed here.

The build also uses the two ring atlases tracked by upstream
(`metal-icon-atlas.png`, `metal-tab-atlas.png`). They are MIT, see
`../LICENSE.metal-fx.txt`.
