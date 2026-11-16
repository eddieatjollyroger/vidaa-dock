#!/bin/sh
# Root half of the guard install: the browser wrote /var/local/homeguard.new
# (the dir is 0777, so that works); this archives the old guard and swaps the
# new one in. Nothing under /APPS is touched. The guard is inert until
# /var/local/l3 markers exist.
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin
BB=${BB:-/usr/local/bin/busybox}
[ -x "$BB" ] || BB=/var/local/tvtools/busybox
[ -x "$BB" ] || BB=$(command -v busybox)
[ -n "$BB" ] && [ -x "$BB" ] || { echo "NO BUSYBOX"; echo DONE; exit 1; }
NEW=${NEW:-/var/local/homeguard.new}
GUARD=${GUARD:-/var/local/homeguard}
BAK=${BAK:-/var/local/homeguard.v0.bak}
HOOK=${HOOK:-/var/local/otaTest.sh}
WANT=${WANT:-dc420ec592d2c86efa57d04557bfc411}

stop() { echo "GUARD: STOP - $1"; echo "GUARD: nothing changed"; echo DONE; exit 1; }

echo "=== staged file ==="
got=$($BB md5sum "$NEW" 2>/dev/null | $BB sed 's/ .*//')
size=$($BB wc -c < "$NEW" 2>/dev/null | $BB sed 's/ //g')
echo "homeguard.new: ${got:-none} ${size:-0} B  want $WANT"
[ "$got" = "$WANT" ] || stop "staged guard missing or wrong hash"
[ "$size" = "3496" ] || stop "staged guard wrong size ($size)"

echo "=== hook ==="
n=$($BB grep -c homeguard "$HOOK" 2>/dev/null)
echo "sourced in hook: $n time(s)"
[ "$n" = "1" ] || stop "hook guard line is not exactly one ($n)"
$BB grep -n homeguard "$HOOK" | $BB sed 's/^/  /'

echo "=== old guard -> archive ==="
if [ -f "$GUARD" ]; then
  old=$($BB md5sum "$GUARD" | $BB sed 's/ .*//')
  echo "existing: $old ($($BB wc -c < "$GUARD" | $BB sed 's/ //g') B)"
  $BB cp -f "$GUARD" "$BAK" || stop "cannot archive the old guard"
  $BB chmod 0644 "$BAK"
  echo "archived: $BAK"
else
  echo "existing: none"
fi

echo "=== swap ==="
$BB mv -f "$NEW" "$GUARD" || stop "mv failed"
$BB chmod 0755 "$GUARD"
$BB sync
now=$($BB md5sum "$GUARD" | $BB sed 's/ .*//')
echo "guard now: $now  lines=$($BB grep -c '' "$GUARD")"
[ "$now" = "$WANT" ] || stop "post-swap hash mismatch ($now)"
$BB ls -l "$GUARD" "$BAK" 2>&1
echo "GUARD: installed - inert until /var/local/l3 markers exist"
echo "GUARD: bridge cannot overwrite this file again (root-owned); use this path."
echo DONE
