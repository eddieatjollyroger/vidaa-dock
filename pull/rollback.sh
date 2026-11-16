#!/bin/sh
# Lane-3 rollback: arm the boot-time restore of the original launcher + cache.
: > "${MARK:-/var/local/home.rollback}"
echo "ROLLBACK: marker armed - power cycle to restore the original launcher"
echo "The guard verifies the backup manifest before clearing any marker."
echo DONE
