#!/usr/bin/env bash
# Pasteur Meet — install docker-jitsi-meet on Ubuntu VPS (run as root or sudo).
# Prereqs: DNS A record for meet.pasteur.plus → this server; ports 80/443/10000/udp open.
#
# From your laptop:
#   scp -r scripts config env.pasteur.example user@vps:/tmp/pasteur-meet/
#   ssh user@vps 'sudo bash /tmp/pasteur-meet/scripts/install-vps.sh'
#
# Or clone this repo on the VPS and run:
#   sudo bash scripts/install-vps.sh

set -euo pipefail

JITSI_INSTALL_DIR="${JITSI_INSTALL_DIR:-/opt/jitsi}"
JITSI_GIT_TAG="${JITSI_GIT_TAG:-stable-9646}"
PUBLIC_URL="${PUBLIC_URL:-https://meet.pasteur.plus}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo."
  exit 1
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
  echo "Set LETSENCRYPT_EMAIL (e.g. export LETSENCRYPT_EMAIL=admin@pasteur.plus)"
  exit 1
fi

echo "==> Installing Docker (if missing)..."
if ! command -v docker >/dev/null 2>&1; then
  apt-get update
  apt-get install -y ca-certificates curl git
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${VERSION_CODENAME:-$VERSION_ID}") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

echo "==> Cloning docker-jitsi-meet @ ${JITSI_GIT_TAG}..."
if [[ ! -d "$JITSI_INSTALL_DIR/.git" ]]; then
  git clone https://github.com/jitsi/docker-jitsi-meet.git "$JITSI_INSTALL_DIR"
fi
cd "$JITSI_INSTALL_DIR"
git fetch --tags
git checkout "$JITSI_GIT_TAG"

if [[ ! -f .env ]]; then
  cp env.example .env
fi

JWT_APP_SECRET="${JWT_APP_SECRET:-$(openssl rand -hex 32)}"
SECRET_FILE="/root/pasteur-meet-jwt-secret.txt"
echo "$JWT_APP_SECRET" > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"

echo "==> Applying Pasteur .env overrides..."
grep -q '^PUBLIC_URL=' .env && sed -i "s|^PUBLIC_URL=.*|PUBLIC_URL=${PUBLIC_URL}|" .env || echo "PUBLIC_URL=${PUBLIC_URL}" >> .env

set_kv() {
  local key="$1" val="$2"
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${val}|" .env
  else
    echo "${key}=${val}" >> .env
  fi
}

set_kv ENABLE_AUTH 1
set_kv ENABLE_GUESTS 0
set_kv AUTH_TYPE jwt
set_kv JWT_APP_ID pasteur_plus
set_kv JWT_APP_SECRET "$JWT_APP_SECRET"
set_kv JWT_ACCEPTED_ISSUERS pasteur_plus
set_kv JWT_ACCEPTED_AUDIENCES pasteur_plus
set_kv TZ Asia/Tehran
set_kv ENABLE_LETSENCRYPT 1
set_kv LETSENCRYPT_DOMAIN "${PUBLIC_URL#https://}"
set_kv LETSENCRYPT_EMAIL "$LETSENCRYPT_EMAIL"
set_kv ENABLE_HTTP_REDIRECT 1

if [[ -f ./gen-passwords.sh ]]; then
  echo "==> gen-passwords.sh..."
  ./gen-passwords.sh
fi

CONFIG="${CONFIG:-$HOME/.jitsi-meet-cfg}"
if grep -q '^CONFIG=' .env; then
  CONFIG="$(grep '^CONFIG=' .env | cut -d= -f2- | tr -d '"')"
fi
mkdir -p "$CONFIG/web"
cp "$REPO_ROOT/config/custom-config.js" "$CONFIG/web/custom-config.js"
cp "$REPO_ROOT/config/custom-interface_config.js" "$CONFIG/web/custom-interface_config.js"

echo "==> docker compose up -d..."
docker compose up -d

echo ""
echo "=============================================="
echo "Pasteur Meet stack started."
echo "JWT_APP_SECRET saved on server: $SECRET_FILE"
echo "Copy the SAME value to Runflare as JITSI_APP_SECRET (never commit to git)."
echo "Public URL: $PUBLIC_URL"
echo "Next: open firewall (443/tcp, JVB UDP, Coturn), test JWT with mint-test-jwt.js"
echo "See OPERATIONS.md and fill INTEGRATION-HANDOFF.md"
echo "=============================================="

docker compose ps
