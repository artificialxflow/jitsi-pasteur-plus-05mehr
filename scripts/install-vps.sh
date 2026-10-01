#!/usr/bin/env bash
# Pasteur Meet — install docker-jitsi-meet on Ubuntu VPS (run as root).
# Prefer: sudo bash scripts/bootstrap-vps.sh  (clones this repo + firewall + this script)
#
# Direct use (repo already on server):
#   export LETSENCRYPT_EMAIL=admin@pasteur-plus.com
#   sudo -E bash scripts/install-vps.sh

set -euo pipefail

JITSI_INSTALL_DIR="${JITSI_INSTALL_DIR:-/opt/jitsi}"
JITSI_GIT_TAG="${JITSI_GIT_TAG:-stable-9646}"
PUBLIC_URL="${PUBLIC_URL:-https://meet.pasteur-plus.com}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@pasteur-plus.com}"
JVB_ADVERTISE_IPS="${JVB_ADVERTISE_IPS:-}"
LOG_DIR="${LOG_DIR:-/var/log/pasteur-meet}"
PASTEUR_INSTALL_LOG="${PASTEUR_INSTALL_LOG:-${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$LOG_DIR"
touch "$PASTEUR_INSTALL_LOG"
chmod 600 "$PASTEUR_INSTALL_LOG"

# If not already tee'd by bootstrap, attach logging
if [[ -z "${PASTEUR_LOGGING_ATTACHED:-}" ]]; then
  exec > >(tee -a "$PASTEUR_INSTALL_LOG") 2>&1
  export PASTEUR_LOGGING_ATTACHED=1
fi

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [install] $*"; }
die() { log "ERROR: $*"; exit 1; }
section() {
  echo ""
  echo "----------------------------------------------------------------"
  log "$*"
  echo "----------------------------------------------------------------"
}

set_kv() {
  local key="$1" val="$2"
  if grep -q "^${key}=" .env; then
    # Escape sed special chars in value minimally
    local escaped
    escaped="$(printf '%s' "$val" | sed -e 's/[\/&]/\\&/g')"
    sed -i "s|^${key}=.*|${key}=${escaped}|" .env
  else
    echo "${key}=${val}" >> .env
  fi
  log "env set: ${key}=${val}"
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  die "Run with sudo/root."
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
  die "Set LETSENCRYPT_EMAIL (e.g. export LETSENCRYPT_EMAIL=admin@pasteur-plus.com)"
fi

MEET_HOST="${PUBLIC_URL#https://}"
MEET_HOST="${MEET_HOST#http://}"
MEET_HOST="${MEET_HOST%%/*}"

section "Install settings"
log "REPO_ROOT=$REPO_ROOT"
log "JITSI_INSTALL_DIR=$JITSI_INSTALL_DIR"
log "JITSI_GIT_TAG=$JITSI_GIT_TAG"
log "PUBLIC_URL=$PUBLIC_URL"
log "LETSENCRYPT_DOMAIN=$MEET_HOST"
log "LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL"
log "LOG=$PASTEUR_INSTALL_LOG"

section "Installing Docker (if missing)"
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ca-certificates curl git openssl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  # shellcheck disable=SC1091
  . /etc/os-release
  CODENAME="${VERSION_CODENAME:-$VERSION_ID}"
  log "Adding Docker apt repo for Ubuntu codename=${CODENAME}"
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    ${CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
else
  log "Docker already installed: $(docker --version)"
fi

if ! docker compose version >/dev/null 2>&1; then
  die "docker compose plugin missing after install"
fi
log "docker compose: $(docker compose version)"

section "Cloning docker-jitsi-meet @ ${JITSI_GIT_TAG}"
if [[ ! -d "$JITSI_INSTALL_DIR/.git" ]]; then
  log "git clone https://github.com/jitsi/docker-jitsi-meet.git $JITSI_INSTALL_DIR"
  git clone https://github.com/jitsi/docker-jitsi-meet.git "$JITSI_INSTALL_DIR"
else
  log "Existing checkout at $JITSI_INSTALL_DIR"
fi
cd "$JITSI_INSTALL_DIR"
git fetch --tags --force
git checkout "$JITSI_GIT_TAG"
log "Jitsi HEAD: $(git rev-parse --short HEAD) tag/branch=$(git describe --tags --always)"

if [[ ! -f .env ]]; then
  log "Creating .env from env.example"
  cp env.example .env
else
  log ".env already present — applying overrides"
  cp -a .env ".env.backup.$(date +%Y%m%d-%H%M%S)"
fi

section "JWT secret"
JWT_APP_SECRET="${JWT_APP_SECRET:-}"
SECRET_FILE="/root/pasteur-meet-jwt-secret.txt"
if [[ -z "$JWT_APP_SECRET" && -f "$SECRET_FILE" ]]; then
  JWT_APP_SECRET="$(tr -d '\r\n' < "$SECRET_FILE")"
  log "Reusing JWT secret from $SECRET_FILE"
fi
if [[ -z "$JWT_APP_SECRET" ]]; then
  JWT_APP_SECRET="$(openssl rand -hex 32)"
  log "Generated new JWT_APP_SECRET"
fi
umask 077
echo "$JWT_APP_SECRET" > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"
log "JWT secret written to $SECRET_FILE"

if [[ -z "$JVB_ADVERTISE_IPS" ]]; then
  JVB_ADVERTISE_IPS="$(curl -4 -fsS --max-time 10 https://ifconfig.me/ip 2>/dev/null || curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"
fi
log "JVB_ADVERTISE_IPS=${JVB_ADVERTISE_IPS:-<unset>}"

section "Applying Pasteur .env overrides"
set_kv PUBLIC_URL "$PUBLIC_URL"
set_kv ENABLE_AUTH 1
set_kv ENABLE_GUESTS 0
set_kv AUTH_TYPE jwt
set_kv JWT_APP_ID pasteur_plus
set_kv JWT_APP_SECRET "$JWT_APP_SECRET"
set_kv JWT_ACCEPTED_ISSUERS pasteur_plus
set_kv JWT_ACCEPTED_AUDIENCES pasteur_plus
set_kv TZ Asia/Tehran
set_kv ENABLE_LETSENCRYPT 1
set_kv LETSENCRYPT_DOMAIN "$MEET_HOST"
set_kv LETSENCRYPT_EMAIL "$LETSENCRYPT_EMAIL"
set_kv ENABLE_HTTP_REDIRECT 1

# Help JVB advertise the correct public address for WebRTC / mobile
if [[ -n "$JVB_ADVERTISE_IPS" ]]; then
  set_kv JVB_ADVERTISE_IPS "$JVB_ADVERTISE_IPS"
fi

if [[ -f ./gen-passwords.sh ]]; then
  section "Running gen-passwords.sh"
  ./gen-passwords.sh
  log "gen-passwords.sh finished"
else
  log "WARNING: gen-passwords.sh not found — skipping"
fi

section "Custom Pasteur web config"
CONFIG="${CONFIG:-$HOME/.jitsi-meet-cfg}"
if grep -q '^CONFIG=' .env; then
  CONFIG="$(grep '^CONFIG=' .env | cut -d= -f2- | tr -d '"' | tr -d "'")"
fi
log "CONFIG dir=$CONFIG"
mkdir -p "$CONFIG/web"
if [[ -f "$REPO_ROOT/config/custom-config.js" ]]; then
  cp -v "$REPO_ROOT/config/custom-config.js" "$CONFIG/web/custom-config.js"
else
  log "WARNING: missing $REPO_ROOT/config/custom-config.js"
fi
if [[ -f "$REPO_ROOT/config/custom-interface_config.js" ]]; then
  cp -v "$REPO_ROOT/config/custom-interface_config.js" "$CONFIG/web/custom-interface_config.js"
else
  log "WARNING: missing $REPO_ROOT/config/custom-interface_config.js"
fi

section "docker compose pull + up -d"
docker compose pull
docker compose up -d
log "Waiting for containers to settle..."
sleep 8
docker compose ps

section "Install summary"
log "Public URL:       $PUBLIC_URL"
log "Jitsi dir:        $JITSI_INSTALL_DIR"
log "JWT secret file:  $SECRET_FILE"
log "Install log:      $PASTEUR_INSTALL_LOG"
log "Copy JWT secret to Runflare as JITSI_APP_SECRET (never commit)."
log "Next: test with mint-test-jwt.js ; see OPERATIONS.md"
log "Install finished successfully."
