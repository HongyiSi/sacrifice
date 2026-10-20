#!/usr/bin/env bash
# Publish a UI-only update without restarting live multiplayer rooms.
set -Eeuo pipefail
archive=${1:?web archive}
expected=${2:?sha256}
stamp=${3:?timestamp}
[[ "$archive" == /tmp/sacrifice-web-*.tar.gz ]]
[[ "$stamp" =~ ^[0-9]{8}-[0-9]{6}$ ]]
printf '%s  %s\n' "$expected" "$archive" | sha256sum --check --status
base=/srv/sacrifice
next="$base/web-releases/$stamp"
previous=$(readlink -f "$base/web")
[[ -d "$previous" && ! -e "$next" ]]
mkdir -p "$next"
tar -xzf "$archive" -C "$next"
test -s "$next/index.html"
test -s "$next/index.pck"
test -s "$next/music-lobby.wav"
test -s "$next/music-battle.mp3"
chown -R root:root "$next"
find "$next" -type d -exec chmod 0755 {} +
find "$next" -type f -exec chmod 0644 {} +
gzip -9 -k -f "$next/index.js" "$next/index.wasm" "$next/index.pck"
printf '%s\n' "$previous" > "$base/web-releases/previous-$stamp.txt"
rollback() {
    status=$?
    ln -sfn "$previous" "$base/web"
    echo "SACRIFICE_WEB_ROLLED_BACK previous=$previous" >&2
    exit "$status"
}
trap rollback ERR
ln -s "$next" "$base/web.next-$stamp"
mv -Tf "$base/web.next-$stamp" "$base/web"
curl --fail --silent --show-error --resolve sacrifice.shytomato.top:443:127.0.0.1 https://sacrifice.shytomato.top/ --output /dev/null
systemctl is-active --quiet sacrifice
trap - ERR
echo "SACRIFICE_WEB_UPDATED version=$stamp"
sha256sum "$next/index.html" "$next/index.pck"
systemctl show sacrifice -p MainPID
