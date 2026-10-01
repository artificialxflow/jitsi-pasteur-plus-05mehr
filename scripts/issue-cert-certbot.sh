#!/usr/bin/env bash
# Issue TLS with host certbot and wire certs into docker-jitsi-meet.
# Use when container acme.sh fails (e.g. ZeroSSL EAB errors).
#
#   sudo bash scripts/issue-cert-certbot.sh
#   # or:
#   sudo LETSENCRYPT_EMAIL=you@pasteur-plus.com bash scripts/issue-cert-certbot.sh

set -euo pipefail

JITSI_INSTALL_DIR="${JITSI_INSTALL_DIR:-/opt/jitsi}"
PUBLIC_URL="${PUBLIC_URL:-https://meet.pasteur-plus.com}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@pasteur-plus.com}"

MEET_HOST="${PUBLIC_URL#https://}"
MEET_HOST="${MEET_HOST#http://}"
MEET_HOST="${MEET_HOST%%/*}"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

cd "$JITSI_INSTALL_DIR"

CONFIG="${CONFIG:-$HOME/.jitsi-meet-cfg}"
if grep -q '^CONFIG=' .env; then
  CONFIG="$(grep '^CONFIG=' .env | cut -d= -f2- | tr -d '"' | tr -d "'")"
fi

echo "==> Stopping web (free ports 80/443 for certbot standalone)..."
docker compose stop web || true

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y certbot

echo "==> certbot certonly --standalone -d ${MEET_HOST}"
certbot certonly --standalone \
  -d "$MEET_HOST" \
  --email "$LETSENCRYPT_EMAIL" \
  --agree-tos \
  --non-interactive \
  --keep-until-expiring

LIVE="/etc/letsencrypt/live/${MEET_HOST}"
test -f "$LIVE/fullchain.pem" || { echo "Missing $LIVE/fullchain.pem"; exit 1; }
test -f "$LIVE/privkey.pem" || { echo "Missing $LIVE/privkey.pem"; exit 1; }

mkdir -p "$CONFIG/web/keys"
cp -f "$LIVE/fullchain.pem" "$CONFIG/web/keys/cert.crt"
cp -f "$LIVE/privkey.pem" "$CONFIG/web/keys/cert.key"
chmod 644 "$CONFIG/web/keys/cert.crt"
chmod 600 "$CONFIG/web/keys/cert.key"

set_kv() {
  local key="$1" val="$2"
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${val}|" .env
  else
    echo "${key}=${val}" >> .env
  fi
}

set_kv ENABLE_LETSENCRYPT 0
set_kv HTTP_PORT 80
set_kv HTTPS_PORT 443
set_kv PUBLIC_URL "$PUBLIC_URL"

echo "==> Restarting stack..."
docker compose up -d
sleep 5
docker compose ps
curl -Ik "https://${MEET_HOST}" || true

echo "Done. Certs in ${CONFIG}/web/keys/ (ENABLE_LETSENCRYPT=0)."
echo "Renewal: re-run this script after certbot renew, or add a cron that copies keys + restarts web."
