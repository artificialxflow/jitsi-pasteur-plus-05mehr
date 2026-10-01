#!/usr/bin/env bash
# =============================================================================
# Pasteur Meet — one-shot bootstrap for a fresh Ubuntu VPS
# Domain: https://meet.pasteur-plus.com
#
# On the VPS (as root):
#   1) Push this repo to GitHub from your laptop first.
#   2) Then either:
#
#      curl -fsSL https://raw.githubusercontent.com/artificialxflow/jitsi-pasteur-plus-05mehr/main/scripts/bootstrap-vps.sh \
#        -o /root/bootstrap-vps.sh && bash /root/bootstrap-vps.sh
#
#      OR: nano /root/bootstrap-vps.sh  → paste this file → bash /root/bootstrap-vps.sh
#
# Optional overrides before running:
#   export LETSENCRYPT_EMAIL=you@example.com
#   export PUBLIC_URL=https://meet.pasteur-plus.com
#   export REPO_URL=https://github.com/artificialxflow/jitsi-pasteur-plus-05mehr.git
#   export REPO_BRANCH=main
# =============================================================================

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/artificialxflow/jitsi-pasteur-plus-05mehr.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
REPO_DIR="${REPO_DIR:-/opt/pasteur-meet-repo}"
PUBLIC_URL="${PUBLIC_URL:-https://meet.pasteur-plus.com}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@pasteur-plus.com}"
JITSI_INSTALL_DIR="${JITSI_INSTALL_DIR:-/opt/jitsi}"
JITSI_GIT_TAG="${JITSI_GIT_TAG:-stable-9646}"
LOG_DIR="${LOG_DIR:-/var/log/pasteur-meet}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/bootstrap-$(date +%Y%m%d-%H%M%S).log}"
ENABLE_UFW="${ENABLE_UFW:-1}"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Tee all stdout/stderr to log + console
exec > >(tee -a "$LOG_FILE") 2>&1

log()  { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }
die()  { log "ERROR: $*"; exit 1; }
section() {
  echo ""
  echo "================================================================"
  log "$*"
  echo "================================================================"
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  die "Run as root (or: sudo bash $0)"
fi

section "Pasteur Meet bootstrap starting"
log "LOG_FILE=$LOG_FILE"
log "REPO_URL=$REPO_URL"
log "REPO_BRANCH=$REPO_BRANCH"
log "REPO_DIR=$REPO_DIR"
log "PUBLIC_URL=$PUBLIC_URL"
log "LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL"
log "JITSI_INSTALL_DIR=$JITSI_INSTALL_DIR"
log "JITSI_GIT_TAG=$JITSI_GIT_TAG"
log "Hostname=$(hostname -f 2>/dev/null || hostname)"
log "Kernel=$(uname -r)"
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  log "OS=${PRETTY_NAME:-unknown}"
fi

section "1/7 apt packages (git, curl, ufw, openssl, ca-certificates)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl git openssl ufw dnsutils
log "git=$(git --version)"
log "curl=$(curl --version | head -1)"
log "openssl=$(openssl version)"

section "2/7 DNS check for meet domain"
MEET_HOST="${PUBLIC_URL#https://}"
MEET_HOST="${MEET_HOST#http://}"
MEET_HOST="${MEET_HOST%%/*}"
log "Resolving A record for ${MEET_HOST}..."
RESOLVED_IPS="$(dig +short A "$MEET_HOST" 2>/dev/null | tr '\n' ' ' || true)"
PUBLIC_IP="$(curl -4 -fsS --max-time 10 https://ifconfig.me/ip 2>/dev/null || curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"
LOCAL_IPS="$(hostname -I 2>/dev/null || true)"
log "Resolved DNS A: ${RESOLVED_IPS:-<none>}"
log "Detected public IP: ${PUBLIC_IP:-<unknown>}"
log "Local IPs: ${LOCAL_IPS:-<none>}"
if [[ -n "$PUBLIC_IP" && -n "$RESOLVED_IPS" && "$RESOLVED_IPS" != *"$PUBLIC_IP"* ]]; then
  log "WARNING: DNS for ${MEET_HOST} does not include public IP ${PUBLIC_IP}."
  log "WARNING: Let's Encrypt may fail until DNS points here. Continuing anyway..."
else
  log "DNS looks OK (or could not fully verify)."
fi

section "3/7 Clone / update this pasteur-meet repo"
if [[ -d "$REPO_DIR/.git" ]]; then
  log "Repo exists at $REPO_DIR — fetching ${REPO_BRANCH}..."
  git -C "$REPO_DIR" fetch --all --prune
  git -C "$REPO_DIR" checkout "$REPO_BRANCH"
  git -C "$REPO_DIR" pull --ff-only origin "$REPO_BRANCH" || log "WARNING: pull failed; using local checkout"
else
  log "Cloning $REPO_URL → $REPO_DIR"
  rm -rf "$REPO_DIR"
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi
log "Repo HEAD: $(git -C "$REPO_DIR" rev-parse --short HEAD) ($(git -C "$REPO_DIR" log -1 --pretty=%s))"
test -f "$REPO_DIR/scripts/install-vps.sh" || die "install-vps.sh missing after clone — did you push the latest commit?"

section "4/7 Firewall (ufw)"
if [[ "$ENABLE_UFW" == "1" ]]; then
  ufw allow OpenSSH comment 'SSH' || true
  ufw allow 80/tcp comment 'HTTP LE/redirect' || true
  ufw allow 443/tcp comment 'HTTPS Jitsi' || true
  ufw allow 10000/udp comment 'JVB media' || true
  ufw allow 3478/tcp comment 'Coturn' || true
  ufw allow 3478/udp comment 'Coturn' || true
  ufw allow 5349/tcp comment 'Coturn TLS' || true
  ufw --force enable
  ufw status verbose || true
  log "ufw enabled with Jitsi ports"
else
  log "ENABLE_UFW=${ENABLE_UFW} — skipping ufw (open ports in host panel manually)"
fi

section "5/7 Run install-vps.sh (Docker + docker-jitsi-meet + JWT + LE)"
export PUBLIC_URL
export LETSENCRYPT_EMAIL
export JITSI_INSTALL_DIR
export JITSI_GIT_TAG
export JVB_ADVERTISE_IPS="${JVB_ADVERTISE_IPS:-$PUBLIC_IP}"
export PASTEUR_INSTALL_LOG="${PASTEUR_INSTALL_LOG:-${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log}"
log "Calling install-vps.sh (install log: $PASTEUR_INSTALL_LOG)"
bash "$REPO_DIR/scripts/install-vps.sh"

section "6/7 Post-install health"
sleep 5
if [[ -d "$JITSI_INSTALL_DIR" ]]; then
  cd "$JITSI_INSTALL_DIR"
  docker compose ps || true
  log "Recent web/prosody/jvb logs (tail):"
  docker compose logs --tail=40 web prosody jicofo jvb 2>/dev/null || true
fi

SECRET_FILE="/root/pasteur-meet-jwt-secret.txt"
section "7/7 Done — next steps"
log "Public URL:      $PUBLIC_URL"
log "Repo on server:  $REPO_DIR"
log "Jitsi stack:     $JITSI_INSTALL_DIR"
log "Bootstrap log:   $LOG_FILE"
log "Install log:     ${PASTEUR_INSTALL_LOG:-n/a}"
if [[ -f "$SECRET_FILE" ]]; then
  log "JWT secret file: $SECRET_FILE (chmod 600)"
  log "Copy that value to Runflare as JITSI_APP_SECRET (never commit to git)."
else
  log "WARNING: secret file missing: $SECRET_FILE"
fi
cat <<EOF

--------------------------------------------------------------------
Smoke test (from laptop or this VPS if node is installed):
  JITSI_APP_SECRET="\$(cat /root/pasteur-meet-jwt-secret.txt)" \\
  JITSI_DOMAIN=${MEET_HOST} \\
  node ${REPO_DIR}/mint-test-jwt.js

Then open the printed URL in a browser.
Without JWT, private rooms must not open.
Fill INTEGRATION-HANDOFF.md after acceptance tests.
--------------------------------------------------------------------
EOF

log "Bootstrap finished successfully."
