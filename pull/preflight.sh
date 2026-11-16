#!/bin/sh
# Read-only lane-3 preflight. Writes nothing.
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin
BB=${BB:-/usr/local/bin/busybox}
[ -x "$BB" ] || BB=/var/local/tvtools/busybox
[ -x "$BB" ] || BB=$(command -v busybox)
[ -n "$BB" ] && [ -x "$BB" ] || { echo "NO BUSYBOX"; echo DONE; exit 1; }
ROOT=${ROOT:-/APPS/channelA/operation-ui/apps}
CACHE=${CACHE:-/var/local/hisenseUI/cobalt_home/.cache}
MAC=${MAC:-192.168.1.126}
PORT=${PORT:-8777}

echo "=== identity ==="
echo "id: $($BB id 2>&1)"
echo "busybox: $BB"
MISS=""
for a in id uname cat mkdir tail tr wc xargs sleep date tee cut dirname basename kill \
         wget tar md5sum sha256sum find sort sed awk grep df ls cp mv chown chmod rm ln sync; do
  $BB --list 2>/dev/null | $BB grep -qx "$a" || MISS="$MISS $a"
done
echo "bb missing:${MISS:- none}"
$BB readlink -f /bin/sh 2>/dev/null | $BB sed 's/^/sh -> /'

echo "=== paths ==="
for p in /APPS /APPS/channelA /APPS/channelA/hisenseUI /APPS/channelA/hisenseUI/static \
         "$ROOT/launcher/js" "$ROOT/screen-saver/js" "$CACHE/cobalt" \
         /var/local /var/local/l3 /var/local/homeguard /var/local/homeguard.new \
         /var/local/cmd.sh /var/local/cmd.out /var/local/otaTest.sh /var/local/hisenseUI; do
  $BB ls -ld "$p" 2>&1
done
echo "--- whose dir is /apps ---"
$BB ls -ld /apps 2>&1

echo "=== cache ==="
$BB ls -d "$CACHE"/cobalt/* 2>&1 | $BB sed 's/^/  /'
$BB df -k /var/local /APPS 2>&1 | $BB sed -n '2,3p'

echo "=== bundle ==="
$BB md5sum "$ROOT/launcher/js/app.js" 2>&1
$BB ls -l "$ROOT/launcher/js/app.js" 2>&1
$BB md5sum /var/local/homeguard 2>&1

echo "=== hook ==="
echo "guard-line: $($BB grep -c homeguard /var/local/otaTest.sh 2>/dev/null)"
echo "cmd-line:   $($BB grep -c cmd.sh /var/local/otaTest.sh 2>/dev/null)"
echo "killswitch: $($BB grep -c hook.off /var/local/otaTest.sh 2>/dev/null)"
$BB sed -n '1,6p' /var/local/otaTest.sh 2>&1 | $BB sed 's/^/  /'

echo "=== l3 ==="
$BB ls -la /var/local/l3 2>&1

echo "=== net ==="
bash -c "exec 3<>/dev/tcp/$MAC/$PORT && echo mac-tcp-ok && exec 3<&-" 2>/dev/null || echo mac-tcp-FAIL
echo DONE
