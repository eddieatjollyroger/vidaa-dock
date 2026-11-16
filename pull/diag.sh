#!/bin/sh
# Read-only diagnostic. Prints who runs the channel, what the live guard is,
# and how the last boot went. Writes nothing.
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin
BB=${BB:-/usr/local/bin/busybox}
[ -x "$BB" ] || BB=/var/local/tvtools/busybox
[ -x "$BB" ] || BB=$(command -v busybox)
[ -n "$BB" ] && [ -x "$BB" ] || { echo "NO BUSYBOX"; echo DONE; exit 1; }

echo "=== who am i ==="
$BB id 2>&1
$BB uname -a 2>&1
echo "shell: $0"

echo "=== applets we still need ==="
MISS=""
for a in id cat mkdir tail tr wc xargs sleep date tee cut dirname basename kill uname \
         awk sed grep sort wget sha256sum md5sum tar find df ls cp mv chown chmod rm ln sync; do
  $BB --list 2>/dev/null | $BB grep -qx "$a" || MISS="$MISS $a"
done
echo "bb missing:${MISS:- none}"

echo "=== channel files ==="
$BB ls -l /var/local/cmd.run /var/local/cmd.out /var/local/cmd.sh \
           /var/local/chan.ready /var/local/otaTest.sh 2>&1

echo "=== live guard (this is what boots source) ==="
$BB md5sum /var/local/homeguard 2>&1
$BB wc -c /var/local/homeguard 2>&1
$BB cat /var/local/homeguard 2>&1

echo "=== guard log ==="
$BB tail -n 20 /var/local/homeguard.log 2>&1

echo "=== last boot hook log ==="
$BB tail -n 15 /var/local/otaTest.log 2>&1
echo DONE
