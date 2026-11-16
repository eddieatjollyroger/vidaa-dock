#!/bin/bash
# Local rehearsal of the lane-3 scripts against a fake TV tree.
# macOS only (uses `md5 -q`); the real TV uses busybox.
set -u
cd "$(dirname "$0")"
PASS=0; FAIL=0
NEW=$(md5 -q pull/home.js)   # candidate bundle hash, rebuilt locally
ck() { if [ "$2" = "$3" ]; then echo "  ok   $1"; PASS=$((PASS+1)); else echo "  FAIL $1: got [$2] want [$3]"; FAIL=$((FAIL+1)); fi; }
T=$(mktemp -d "${TMPDIR:-/tmp}/l3test.XXXXXX") || exit 1
R=$T/APPS/channelA/operation-ui/apps
CACHE=$T/cache
L=$T/l3
D=$T/APPS/channelA/hisenseUI/static/vidaa-clean-home
mkdir -p "$R/launcher/js" "$R/launcher/res" "$R/screen-saver/js" "$CACHE/cobalt/compiled_js" "$CACHE/cobalt/uncompiled_js" "$CACHE/cobalt/Cache" "$L" "$T/hook" "$T/bin"
cp pull/app.js "$R/launcher/js/app.js"
cp pull/app.js "$R/screen-saver/js/app.js"
echo a > "$R/launcher/res/x"
echo c > "$CACHE/cobalt/compiled_js/a.bin"
echo u > "$CACHE/cobalt/uncompiled_js/b.bin"
echo k > "$CACHE/cobalt/Cache/c"
printf '#!/bin/sh\n[ -f /var/local/hook.off ] && exit 0\n( [ -f /var/local/homeguard ] && . /var/local/homeguard )\nexec > /var/local/otaTest.log\n' > "$T/hook/otaTest.sh"
cp pull/homeguard "$T/guard"

cat > "$T/bb" <<'EOF'
#!/bin/sh
cmd=$1; [ $# -gt 0 ] && shift
case "$cmd" in
  --list) printf '%s\n' tar md5sum sha256sum find sort sed awk grep df ls cp mv chown chmod rm ln sync wc tr cat readlink tail;;
  md5sum) for f in "$@"; do printf '%s  %s\n' "$(md5 -q "$f")" "$f"; done;;
  sha256sum) for f in "$@"; do printf '%s  %s\n' "$(shasum -a 256 "$f" | cut -d' ' -f1)" "$f"; done;;
  readlink) shift; echo "${1:-}";;
  *) exec "$cmd" "$@";;
esac
EOF
chmod +x "$T/bb"
cat > "$T/bin/md5sum" <<'EOF'
#!/bin/sh
for f in "$@"; do printf '%s  %s\n' "$(md5 -q "$f")" "$f"; done
EOF
chmod +x "$T/bin/md5sum"
export PATH="$T/bin:$PATH"

echo "=== 1. backup ==="
OUT=$(BB=$T/bb L=$L ROOT=$R CACHE=$CACHE sh pull/backup.sh)
echo "$OUT" | sed 's/^/  | /'
ck "manifest exists" "$([ -s "$L/launcher.md5" ] && echo yes)" yes
ck "manifest entries" "$(wc -l < "$L/launcher.md5" | tr -d ' ')" 2
ck "launcher.tar" "$([ -s "$L/launcher.tar" ] && echo yes)" yes
ck "cache.tar" "$([ -s "$L/cache.tar" ] && echo yes)" yes
ck "app.js line present" "$(grep -c 'launcher/js/app.js$' "$L/launcher.md5")" 1

echo "=== 2. stage (127.0.0.1:8777) ==="
# stage fetches over HTTP; serve pull/ locally if nothing is listening.
SRV=""
if ! (exec 3<>/dev/tcp/127.0.0.1/8777) 2>/dev/null; then
  python3 -m http.server 8777 --bind 127.0.0.1 --directory pull >/dev/null 2>&1 &
  SRV=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    (exec 3<>/dev/tcp/127.0.0.1/8777) 2>/dev/null && break
    sleep 0.2
  done
fi
trap '[ -n "$SRV" ] && kill "$SRV" 2>/dev/null' EXIT
OUT=$(BB=$T/bb L=$L MAC=127.0.0.1 PORT=8777 sh pull/stage.sh)
echo "$OUT" | sed 's/^/  | /'
ck "stage ok marker" "$([ -s "$L/stage.ok" ] && echo yes)" yes
ck "staged md5" "$(md5 -q "$L/home.js")" $NEW

echo "=== 3. apply must refuse without guard ==="
OUT=$(BB=$T/bb L=$L ROOT=$R CACHE=$CACHE D=$D GUARD=$T/nope HOOK=$T/hook/otaTest.sh OWNER=$(id -un):$(id -gn) sh pull/apply.sh)
echo "$OUT" | sed 's/^/  | /'
ck "refused" "$(echo "$OUT" | grep -c 'guard missing')" 1
ck "app.js untouched" "$(md5 -q "$R/launcher/js/app.js")" e988dfe7992a8d2eecea72c24896de05

echo "=== 4. apply with guard ==="
OUT=$(BB=$T/bb L=$L ROOT=$R CACHE=$CACHE D=$D GUARD=$T/guard HOOK=$T/hook/otaTest.sh OWNER=$(id -un):$(id -gn) sh pull/apply.sh)
echo "$OUT" | sed 's/^/  | /'
ck "app.js is candidate" "$(md5 -q "$R/launcher/js/app.js")" $NEW
ck "app.js mode" "$(stat -f %Lp "$R/launcher/js/app.js")" 664
ck "assets installed" "$(ls "$D"/*.png | wc -l | tr -d ' ')" 2
ck "icon atlas md5" "$(md5 -q "$D/metal-icon-atlas.png")" af884e735c8e62b4c56ee2eb266f3f65
ck "tab atlas md5" "$(md5 -q "$D/metal-tab-atlas.png")" 3d42f6ca5e16b8effdba7d168168e5a3
ck "trial=4" "$(cat "$L/trial")" 4
ck "applied marker" "$([ -f "$L/applied" ] && echo yes)" yes
ck "wipe marker" "$([ -f "$L/cache-wipe" ] && echo yes)" yes
ck "compiled_js removed" "$([ -d "$CACHE/cobalt/compiled_js" ] && echo yes || echo no)" no
SECOND=$(BB=$T/bb L=$L ROOT=$R CACHE=$CACHE D=$D GUARD=$T/guard HOOK=$T/hook/otaTest.sh OWNER=$(id -un):$(id -gn) sh pull/apply.sh)
ck "second apply refused" "$(echo "$SECOND" | grep -c 'APPLY: STOP')" 1
ck "second apply left bundle" "$(md5 -q "$R/launcher/js/app.js")" $NEW
ck "applied records md5" "$(cat "$L/applied")" $NEW

echo "=== 4b. update apply after re-stage ==="
BB=$T/bb L=$L MAC=127.0.0.1 PORT=8777 sh pull/stage.sh > /dev/null
OUT=$(BB=$T/bb L=$L ROOT=$R CACHE=$CACHE D=$D GUARD=$T/guard HOOK=$T/hook/otaTest.sh OWNER=$(id -un):$(id -gn) sh pull/apply.sh)
echo "$OUT" | sed 's/^/  | /'
ck "update ok" "$(echo "$OUT" | grep -c 'APPLY: ok')" 1
ck "update kept bundle" "$(md5 -q "$R/launcher/js/app.js")" $NEW

echo "=== 5. accept ==="
OUT=$(BB=$T/bb L=$L J=$R/launcher/js/app.js sh pull/accept.sh)
echo "$OUT" | sed 's/^/  | /'
ck "alive marker" "$([ -f "$L/alive" ] && echo yes)" yes

echo "=== 6. guard boot with alive (disarms) ==="
rm -f "$L/alive"
echo ok > "$L/alive"
G() { BB= L3= ROOT= bash -c 'HOME_L3='"$L"' HOME_ROOT='"$R"' HOME_TAR='"$L"'/launcher.tar HOME_MAN='"$L"'/launcher.md5 HOME_CTAR='"$L"'/cache.tar HOME_CACHE='"$CACHE"' HOME_MARK='"$T"'/home.rollback HOME_TRIAL='"$L"'/trial HOME_ALIVE='"$L"'/alive HOME_WIPE='"$L"'/cache-wipe HOME_LOG='"$T"'/guard.log HOME_BB= . '"$T"'/guard'; }
G
ck "trial cleared" "$([ -f "$L/trial" ] && echo yes || echo no)" no
ck "alive cleared" "$([ -f "$L/alive" ] && echo yes || echo no)" no
ck "app.js still candidate" "$(md5 -q "$R/launcher/js/app.js")" $NEW

echo "=== 7. rollback boot (marker) ==="
echo 2 > "$L/trial"
: > "$T/home.rollback"
G
echo "  --- guard.log ---"; sed 's/^/  | /' "$T/guard.log"
ck "app.js restored" "$(md5 -q "$R/launcher/js/app.js")" e988dfe7992a8d2eecea72c24896de05
ck "screen-saver restored" "$(md5 -q "$R/screen-saver/js/app.js")" e988dfe7992a8d2eecea72c24896de05
ck "cache restored" "$([ -f "$CACHE/cobalt/compiled_js/a.bin" ] && [ -f "$CACHE/cobalt/uncompiled_js/b.bin" ] && echo yes)" yes
ck "markers cleared" "$([ -f "$T/home.rollback" ] || [ -f "$L/trial" ] || [ -f "$L/alive" ]; echo $?)" 1
ck "post-restore wipe set" "$([ -f "$L/cache-wipe" ] && echo yes)" yes

echo "=== 8. next boot drops compiled cache ==="
G
ck "compiled_js wiped" "$([ -d "$CACHE/cobalt/compiled_js" ] && echo yes || echo no)" no
ck "uncompiled_gone" "$([ -d "$CACHE/cobalt/uncompiled_js" ] && echo yes || echo no)" no
ck "wipe marker cleared" "$([ -f "$L/cache-wipe" ] && echo yes || echo no)" no

echo
echo "RESULT: pass=$PASS fail=$FAIL  tree=$T"
[ "$FAIL" = 0 ]
