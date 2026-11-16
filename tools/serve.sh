#!/bin/sh
# Serve pull/ to the TV on :8777. Run from the repository root.
# This is plain HTTP on the LAN: no TLS, no auth, no internet exposure.
PORT=${PORT:-8777}
cd "$(dirname "$0")/../pull" || exit 1
echo "serving $(pwd) on http://0.0.0.0:$PORT/"
echo "on the TV: MAC=<this machine's LAN IP> PORT=$PORT sh /var/local/l3/stage.sh"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
