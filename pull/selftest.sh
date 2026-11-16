export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin
BB=/usr/local/bin/busybox
G=/var/local/homeguard
WANT=dc420ec592d2c86efa57d04557bfc411
mkdir -p /var/local/l3
if [ ! -s "$G" ]; then echo "GUARD MISSING - run /send?src=homeguard&dst=/var/local/homeguard first"; echo DONE; return 0 2>/dev/null || exit 0; fi
chmod 755 "$G"
GOT=$("$BB" md5sum "$G" | sed 's/ .*//')
if [ "$GOT" != "$WANT" ]; then echo "GUARD MISMATCH got=$GOT want=$WANT - not testing"; echo DONE; return 0 2>/dev/null || exit 0; fi
# v1 already inserted the source line; these fallbacks are no-ops when present.
if ! grep -q homeguard /var/local/otaTest.sh; then
  awk '{ print } /^\[ -f \/var\/local\/hook\.off \]/ && !done { print "( [ -f /var/local/homeguard ] && . /var/local/homeguard )"; done=1 }' \
    /var/local/otaTest.sh > /var/local/otaTest.new
  [ -s /var/local/otaTest.new ] && grep -q 'otaTest' /var/local/otaTest.new && \
    cat /var/local/otaTest.new > /var/local/otaTest.sh
  rm -f /var/local/otaTest.new
fi
if ! grep -q homeguard /var/local/otaTest.sh; then
  awk '{ print } /^exec >\/var\/local\/otaTest\.log/ && !done { print "( [ -f /var/local/homeguard ] && . /var/local/homeguard )"; done=1 }' \
    /var/local/otaTest.sh > /var/local/otaTest.new
  [ -s /var/local/otaTest.new ] && grep -q 'otaTest' /var/local/otaTest.new && \
    cat /var/local/otaTest.new > /var/local/otaTest.sh
  rm -f /var/local/otaTest.new
fi
T=/var/local/hgtest
rm -rf "$T"; mkdir -p "$T/l3" "$T/apps/launcher/js" "$T/cache/cobalt/compiled_js"
printf 'STOCK' > "$T/apps/launcher/js/app.js"
printf 'CHUNK' > "$T/apps/launcher/js/chunk.js"
( cd "$T/apps" && "$BB" find launcher -type f | while read -r f; do
    echo "$("$BB" md5sum "$f" | sed 's/ .*//') $f"
  done ) > "$T/l3/launcher.md5"
"$BB" tar -C "$T/apps" -cf "$T/l3/launcher.tar" launcher
printf 'CACHE' > "$T/cache/cobalt/compiled_js/x.js"
"$BB" tar -C "$T/cache" -cf "$T/l3/cache.tar" cobalt
hg() { ( HOME_L3="$T/l3" HOME_ROOT="$T/apps" HOME_CACHE="$T/cache" HOME_MARK="$T/mark" HOME_LOG="$T/log" HOME_TRIAL="$T/l3/trial" HOME_ALIVE="$T/l3/alive" . /var/local/homeguard ); }
ck() { [ "$2" = "$3" ] && echo "$1: ok" || echo "$1: FAIL want=$3 got=$2"; }
hg; ck T0_nomark "$(cat "$T/apps/launcher/js/app.js")" STOCK; ck T0_notrial "$([ -f "$T/l3/trial" ] && echo yes || echo no)" no
printf 'NEW' > "$T/apps/launcher/js/app.js"; printf '2' > "$T/l3/trial"
hg; ck T1_trial1 "$(cat "$T/l3/trial")" 1; ck T1_ui "$(cat "$T/apps/launcher/js/app.js")" NEW
printf 'NEWCACHE' > "$T/cache/cobalt/compiled_js/x.js"
hg; ck T2_restored "$(cat "$T/apps/launcher/js/app.js")" STOCK; ck T2_trial "$([ -f "$T/l3/trial" ] && echo yes || echo no)" no
ck T2_cache "$(cat "$T/cache/cobalt/compiled_js/x.js" 2>/dev/null)" CACHE
printf 'NEW' > "$T/apps/launcher/js/app.js"; printf '2' > "$T/l3/trial"; printf '1' > "$T/l3/alive"
hg; ck T3_commit "$(cat "$T/apps/launcher/js/app.js")" NEW; ck T3_trial "$([ -f "$T/l3/trial" ] && echo yes || echo no)" no
printf 'NEW' > "$T/apps/launcher/js/app.js"; printf '1' > "$T/mark"
hg; ck T4_marker "$(cat "$T/apps/launcher/js/app.js")" STOCK; ck T4_mark "$([ -f "$T/mark" ] && echo yes || echo no)" no
printf 'X' > "$T/cache/cobalt/compiled_js/y.js"
hg; ck T5_wipe "$([ -f "$T/cache/cobalt/compiled_js/y.js" ] && echo yes || echo no)" no
rm -rf "$T"
echo "GUARD: $(grep -c '' /var/local/homeguard) lines md5=$( "$BB" md5sum /var/local/homeguard | sed 's/ .*//')"
echo "HOOK: $(grep -c homeguard /var/local/otaTest.sh)"
echo "L3: $("$BB" ls /var/local/l3 2>/dev/null | "$BB" wc -l) entries"
echo DONE
