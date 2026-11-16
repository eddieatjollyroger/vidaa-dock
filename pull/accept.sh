#!/bin/sh
# Lane-3 accept: disarm the trial after the dock was seen working.
L=${L:-/var/local/l3}
if [ ! -f "$L/trial" ]; then echo "note: no trial armed"; fi
: > "$L/alive"
echo "ACCEPT: alive marker written; guard disarms on the next boot"
echo "app.js: $(${BB:-/usr/local/bin/busybox} md5sum ${J:-/APPS/channelA/operation-ui/apps/launcher/js/app.js} 2>/dev/null)"
echo DONE
