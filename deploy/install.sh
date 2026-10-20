#!/usr/bin/env bash
set -Eeuo pipefail
archive=${1:?archive}
expected=${2:?sha256}
stamp=${3:?release timestamp}
[[ "$stamp" =~ ^[0-9]{8}-[0-9]{6}$ ]]
[[ "$archive" == /tmp/sacrifice-*.tar.gz ]]
printf '%s  %s\n' "$expected" "$archive" | sha256sum --check --status
base=/srv/sacrifice
release="$base/releases/$stamp"
[[ ! -e "$release" ]]
old_release=$(readlink -f "$base/current" || true)
old_web=$(readlink -f "$base/web" || true)
old_server=$(readlink -f "$base/server" || true)
backup="/var/backups/sacrifice-$stamp"
mkdir -p "$backup" "$release"
files=(/etc/systemd/system/sacrifice.service /etc/nginx/snippets/sacrifice-game.locations /etc/nginx/sites-available/sacrifice /etc/nginx/conf.d/sacrifice-diagnostics.conf /etc/logrotate.d/sacrifice-diagnostics)
for file in "${files[@]}"; do [[ ! -f "$file" ]] || cp -a "$file" "$backup/$(basename "$file")"; done
rollback() {
    status=$?
    set +e
    if [[ -n "$old_release" && -d "$old_release" ]]; then ln -sfn "$old_release" "$base/current"; fi
    if [[ -n "$old_web" && -d "$old_web" ]]; then ln -sfn "$old_web" "$base/web"; fi
    if [[ -n "$old_server" && -d "$old_server" ]]; then ln -sfn "$old_server" "$base/server"; fi
    for file in "${files[@]}"; do
        if [[ -f "$backup/$(basename "$file")" ]]; then cp -a "$backup/$(basename "$file")" "$file"; fi
    done
    for file in /etc/nginx/conf.d/sacrifice-diagnostics.conf /etc/logrotate.d/sacrifice-diagnostics; do
        if [[ ! -f "$backup/$(basename "$file")" ]]; then rm -f -- "$file"; fi
    done
    if [[ ! -f "$backup/sacrifice" ]]; then unlink /etc/nginx/sites-enabled/sacrifice; fi
    systemctl daemon-reload
    if [[ -n "$old_release" && -d "$old_release" ]]; then systemctl restart sacrifice; else systemctl disable --now sacrifice; fi
    nginx -t && systemctl reload nginx
    echo "SACRIFICE_DEPLOY_FAILED backup=$backup" >&2
    exit "$status"
}
trap rollback ERR
tar -xzf "$archive" -C "$release"
test -f "$release/web/index.html"
test -s "$release/web/index-mobile.pck"
test -s "$release/web/music-lobby.wav"
test -s "$release/web/music-battle.mp3"
test -f "$release/server/sacrifice-server.pck"
id sacrifice >/dev/null 2>&1 || useradd --system --home-dir /var/lib/sacrifice --shell /usr/sbin/nologin sacrifice
install -d -o sacrifice -g sacrifice /var/lib/sacrifice
chown -R root:root "$release"
find "$release" -type d -exec chmod 0755 {} +
find "$release" -type f -exec chmod 0644 {} +
chmod 0755 "$release/server/godot-server.x86_64"
gzip -9 -k -f "$release/web/index.js" "$release/web/index.wasm" "$release/web/index.pck" "$release/web/index-mobile.pck"
ln -sfn "$release" "$base/current"
ln -sfn "$base/current/web" "$base/web"
ln -sfn "$base/current/server" "$base/server"
install -m 0644 "$release/deploy/sacrifice.service" /etc/systemd/system/sacrifice.service
install -d /etc/nginx/snippets
install -m 0644 "$release/deploy/nginx-sacrifice-game.locations" /etc/nginx/snippets/sacrifice-game.locations
install -d -m 0750 -o www-data -g adm /var/log/sacrifice-client
install -m 0644 "$release/deploy/nginx-sacrifice-diagnostics.conf" /etc/nginx/conf.d/sacrifice-diagnostics.conf
install -m 0644 "$release/deploy/sacrifice-diagnostics.logrotate" /etc/logrotate.d/sacrifice-diagnostics
# Preserve Certbot's HTTPS additions on future releases.
if [[ ! -f /etc/nginx/sites-available/sacrifice ]]; then
    install -m 0644 "$release/deploy/nginx-sacrifice.conf" /etc/nginx/sites-available/sacrifice
fi
ln -sfn /etc/nginx/sites-available/sacrifice /etc/nginx/sites-enabled/sacrifice
nginx -t
systemctl daemon-reload
systemctl enable sacrifice
systemctl restart sacrifice
sleep 2
systemctl is-active --quiet sacrifice
ss -ltn | grep -q '127.0.0.1:7002'
systemctl reload nginx
curl --fail --silent --show-error --retry 5 --retry-all-errors --retry-delay 1 --resolve sacrifice.shytomato.top:80:127.0.0.1 http://sacrifice.shytomato.top/ --output /dev/null
systemctl is-active --quiet heart
systemctl is-active --quiet daifugo
trap - ERR
echo "SACRIFICE_DEPLOY_OK release=$release backup=$backup"
sha256sum "$release/web/index.pck" "$release/server/sacrifice-server.pck"
