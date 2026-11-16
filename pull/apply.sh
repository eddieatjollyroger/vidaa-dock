#!/bin/sh
# Lane-3 apply: install the native dock bundle. Writes /APPS + /var/local/l3.
# Every precondition is checked before the first /APPS write.
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin
BB=${BB:-/usr/local/bin/busybox}
[ -x "$BB" ] || BB=/var/local/tvtools/busybox
[ -x "$BB" ] || BB=$(command -v busybox)
[ -n "$BB" ] && [ -x "$BB" ] || { echo "NO BUSYBOX"; exit 1; }
L=${L:-/var/local/l3}
ROOT=${ROOT:-/APPS/channelA/operation-ui/apps}
J=$ROOT/launcher/js
CACHE=${CACHE:-/var/local/hisenseUI/cobalt_home/.cache}
D=${D:-/APPS/channelA/hisenseUI/static/vidaa-clean-home}
GUARD=${GUARD:-/var/local/homeguard}
HOOK=${HOOK:-/var/local/otaTest.sh}
STOCK_MD5=${STOCK_MD5:-e988dfe7992a8d2eecea72c24896de05}
NEW_MD5=${NEW_MD5:-4c092dc2c1f36a67c11a3efe75db4165}
OWNER=${OWNER:-305:305}

stop() { echo "APPLY: STOP - $1"; echo "APPLY: nothing changed"; echo DONE; exit 1; }

echo "=== preconditions ==="
[ -s "$L/stage.ok" ] || stop "bundle not staged"
[ -s "$L/launcher.tar" ] || stop "launcher.tar missing"
[ -s "$L/launcher.md5" ] || stop "launcher.md5 missing"
[ -s "$L/cache.tar" ] || stop "cache.tar missing"
[ -f "$GUARD" ] || stop "guard missing (run step 0)"
$BB grep -q homeguard "$HOOK" 2>/dev/null || stop "guard not armed in hook"

cur=$($BB md5sum "$J/app.js" 2>/dev/null | $BB sed 's/ .*//')
new=$($BB md5sum "$L/home.js" 2>/dev/null | $BB sed 's/ .*//')
[ "$new" = "$NEW_MD5" ] || stop "staged bundle hash mismatch ($new)"
updating=0
if [ -s "$L/applied" ]; then
  updating=1
  old=$($BB cat "$L/applied" | $BB sed 's/ .*//')
  case "$cur" in
    "$STOCK_MD5"|"$old") echo "current bundle: known ($cur)" ;;
    *) stop "current app.js is an unknown version ($cur)" ;;
  esac
else
  [ "$cur" = "$STOCK_MD5" ] || stop "live app.js is not stock ($cur)"
fi

bad=0
while read -r sum path; do
  [ -n "$path" ] || continue
  [ "$path" = "launcher/js/app.js" ] && [ "$updating" = 1 ] && continue
  got=$($BB md5sum "$ROOT/$path" 2>/dev/null | $BB sed 's/ .*//')
  [ "$got" = "$sum" ] || { echo "  changed: $path"; bad=$((bad+1)); }
done < "$L/launcher.md5"
[ "$bad" = 0 ] || stop "launcher tree differs from backup ($bad files)"
echo "current hash, staged hash and manifest: ok"

echo "=== assets ==="
$BB mkdir -p "$D" || stop "mkdir $D"
$BB chown "$OWNER" "$D" 2>/dev/null
$BB chmod 0755 "$D" || stop "chmod $D"
for f in metal-icon-atlas.png metal-tab-atlas.png; do
  $BB cp "$L/assets/$f" "$D/.$f.new" || stop "copy $f"
  $BB chown "$OWNER" "$D/.$f.new" 2>/dev/null
  $BB chmod 0644 "$D/.$f.new" || stop "chmod $f"
  $BB mv -f "$D/.$f.new" "$D/$f" || stop "mv $f"
  echo "  $f $($BB wc -c < "$D/$f" | $BB sed 's/ //g') B"
done
$BB ls -ld "$D" "$D"/*.png

echo "=== bundle ==="
$BB cp "$L/home.js" "$J/.app.js.new" || stop "copy bundle"
$BB chown "$OWNER" "$J/.app.js.new" 2>/dev/null
$BB chmod 0664 "$J/.app.js.new" || stop "chmod bundle"
got=$($BB md5sum "$J/.app.js.new" | $BB sed 's/ .*//')
[ "$got" = "$NEW_MD5" ] || stop "staged copy corrupt ($got)"
$BB mv -f "$J/.app.js.new" "$J/app.js" || stop "atomic rename failed"
$BB sync
got=$($BB md5sum "$J/app.js" | $BB sed 's/ .*//')
[ "$got" = "$NEW_MD5" ] || stop "post-rename hash mismatch ($got)"
$BB ls -l "$J/app.js"

echo "=== cache + trial ==="
[ -d "$CACHE/cobalt" ] || stop "cache dir missing: $CACHE/cobalt"
had=0
for x in compiled_js uncompiled_js; do
  if [ -d "$CACHE/cobalt/$x" ]; then had=1; $BB rm -rf "$CACHE/cobalt/$x"; echo "  removed cobalt/$x"; fi
done
[ "$had" = 1 ] || echo "  no compiled cache present (nothing stale)"
: > "$L/cache-wipe"
echo 4 > "$L/trial"
rm -f "$L/alive" "$L/stage.ok"
echo "$NEW_MD5" > "$L/applied"
$BB sync
echo "trial=$($BB cat "$L/trial")  cache-wipe=armed  applied=$NEW_MD5"
echo "APPLY: ok"
echo "POWER CYCLE REQUIRED: unplug power, wait 5 s, plug in."
echo "If the old Home appears once, cycle once more (cache recompile)."
echo DONE
