#!/bin/sh
# Lane-3 status: read-only summary of guard + install state.
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin
BB=${BB:-/usr/local/bin/busybox}
[ -x "$BB" ] || BB=/var/local/tvtools/busybox
[ -x "$BB" ] || BB=$(command -v busybox)
L=${L:-/var/local/l3}
J=${J:-/APPS/channelA/operation-ui/apps/launcher/js}
CACHE=${CACHE:-/var/local/hisenseUI/cobalt_home/.cache}
GUARD=${GUARD:-/var/local/homeguard}
HOOK=${HOOK:-/var/local/otaTest.sh}
BOOTLOG=${BOOTLOG:-/var/local/otaTest.log}
GLOG=${GLOG:-/var/local/homeguard.log}
echo "=== status ==="
echo "guard:  $([ -f "$GUARD" ] && echo present || echo MISSING) $($BB md5sum "$GUARD" 2>/dev/null | $BB sed 's/ .*//')"
echo "armed:  $($BB grep -c homeguard "$HOOK" 2>/dev/null)"
echo "trial:  $($BB cat "$L/trial" 2>/dev/null || echo none)"
echo "alive:  $([ -f "$L/alive" ] && echo yes || echo no)"
echo "applied:$([ -f "$L/applied" ] && echo yes || echo no)"
echo "wipe:   $([ -f "$L/cache-wipe" ] && echo armed || echo no)"
echo "app.js: $($BB md5sum "$J/app.js" 2>/dev/null | $BB sed 's/ .*//')"
echo "cache:  $($BB ls -d "$CACHE"/cobalt/* 2>/dev/null | $BB sed 's#.*/##' | $BB awk '{ printf "%s ", $0 }')"
echo "=== guard log ==="
$BB tail -n 10 "$GLOG" 2>/dev/null
echo "=== boot log ==="
$BB tail -n 5 "$BOOTLOG" 2>/dev/null
echo DONE
