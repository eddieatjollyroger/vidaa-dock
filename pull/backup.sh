#!/bin/sh
# Lane-3 backup: ${L} only. No /APPS writes.
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin
BB=${BB:-/usr/local/bin/busybox}
[ -x "$BB" ] || BB=/var/local/tvtools/busybox
[ -x "$BB" ] || BB=$(command -v busybox)
[ -n "$BB" ] && [ -x "$BB" ] || { echo "NO BUSYBOX"; exit 1; }
L=${L:-/var/local/l3}
ROOT=${ROOT:-/APPS/channelA/operation-ui/apps}
CACHE=${CACHE:-/var/local/hisenseUI/cobalt_home/.cache}

mkdir -p "$L" || { echo "BACKUP: cannot mkdir $L"; exit 1; }
chmod 755 "$L"
if [ -s "$L/launcher.tar" ] && [ -s "$L/launcher.md5" ] && [ -s "$L/cache.tar" ]; then
  echo "BACKUP: already present, keeping it"
else
  ( cd "$ROOT" || exit 1
    $BB find launcher -type f | while read -r f; do
      h=$($BB md5sum "$f" 2>/dev/null); echo "${h%% *} $f"
    done > "$L/launcher.md5"
    $BB tar -C "$ROOT" -cf "$L/launcher.tar" launcher || { echo "BACKUP: tar launcher FAILED"; exit 1; }
    $BB tar -C "$CACHE" -cf "$L/cache.tar" cobalt || { echo "BACKUP: tar cache FAILED"; exit 1; }
  ) || { echo "BACKUP: aborted"; exit 1; }
fi

$BB tar -tf "$L/launcher.tar" > /dev/null 2>&1 && echo "launcher.tar: readable" || echo "launcher.tar: CORRUPT"
$BB tar -tf "$L/cache.tar" > /dev/null 2>&1 && echo "cache.tar: readable" || echo "cache.tar: CORRUPT"
echo "manifest files: $($BB wc -l < "$L/launcher.md5" | $BB sed 's/ //g')"
echo "app.js line:    $($BB grep 'launcher/js/app.js$' "$L/launcher.md5")"
echo "cache files:    $($BB find "$CACHE/cobalt" -type f 2>/dev/null | $BB wc -l | $BB sed 's/ //g')"
$BB ls -l "$L/launcher.tar" "$L/launcher.md5" "$L/cache.tar"
echo "free: $($BB df -k "$L" | $BB sed -n '2p')"
echo DONE
