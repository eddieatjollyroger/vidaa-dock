#!/bin/sh
# Lane-3 stage: fetch the candidate bundle + 2 atlases from the Mac into
# /var/local/l3 and verify hashes. No /APPS writes.
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin
BB=${BB:-/usr/local/bin/busybox}
[ -x "$BB" ] || BB=/var/local/tvtools/busybox
[ -x "$BB" ] || BB=$(command -v busybox)
[ -n "$BB" ] && [ -x "$BB" ] || { echo "NO BUSYBOX"; exit 1; }
L=${L:-/var/local/l3}
MAC=${MAC:-192.168.1.126}
PORT=${PORT:-8777}
NEW_MD5=${NEW_MD5:-4c092dc2c1f36a67c11a3efe75db4165}
NEW_SIZE=${NEW_SIZE:-370192}
ICON_MD5=${ICON_MD5:-af884e735c8e62b4c56ee2eb266f3f65}
TAB_MD5=${TAB_MD5:-3d42f6ca5e16b8effdba7d168168e5a3}
mkdir -p "$L/assets" || exit 1

cat > "$L/get.sh" <<'GET'
#!/bin/bash
mac=$1; port=$2; name=$3; out=$4
exec 3<>/dev/tcp/$mac/$port || exit 1
printf 'GET /%s HTTP/1.0\r\nHost: t\r\n\r\n' "$name" >&3 || exit 1
while IFS= read -r line <&3; do
  line=${line%$'\r'}
  [ -z "$line" ] && break
done
cat <&3 > "$out"
GET
chmod 755 "$L/get.sh"

get() {
  rm -f "$2"
  if $BB wget -q -O "$2" "http://$MAC:$PORT/$1" 2>/dev/null && [ -s "$2" ]; then
    echo "  $1: busybox-wget"; return 0
  fi
  if bash "$L/get.sh" "$MAC" "$PORT" "$1" "$2" && [ -s "$2" ]; then
    echo "  $1: tcp"; return 0
  fi
  echo "  $1: FETCH FAILED"; return 1
}

bad=0
get home.js "$L/home.js" || bad=1
get metal-icon-atlas.png "$L/assets/metal-icon-atlas.png" || bad=1
get metal-tab-atlas.png "$L/assets/metal-tab-atlas.png" || bad=1

check() {
  f=$1; want=$2; wsize=$3
  got=$($BB md5sum "$f" 2>/dev/null | $BB sed 's/ .*//')
  size=$($BB wc -c < "$f" 2>/dev/null | $BB sed 's/ //g')
  if [ "$got" = "$want" ] && [ "$size" = "$wsize" ]; then
    echo "  OK  $f  $size B  md5=$got"
  else
    echo "  BAD $f  ${size:-0}/${wsize} B  md5=${got:-none} want=$want"
    bad=1
  fi
}
echo "=== verify ==="
check "$L/home.js" "$NEW_MD5" "$NEW_SIZE"
check "$L/assets/metal-icon-atlas.png" "$ICON_MD5" 205172
check "$L/assets/metal-tab-atlas.png" "$TAB_MD5" 95518

if [ "$bad" = 0 ]; then
  echo "stage=ok $NEW_MD5" > "$L/stage.ok"
  echo "STAGE: ok - ready to apply"
else
  rm -f "$L/stage.ok"
  echo "STAGE: FAILED - nothing will be applied"
fi
echo DONE
