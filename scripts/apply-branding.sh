#!/usr/bin/env bash
# Apply Pasteur branding (logo + FA UI strings) on an already-installed VPS.
#
#   cd /opt/pasteur-meet-repo && sudo bash scripts/apply-branding.sh
# Or after git pull on the server:
#   sudo bash /opt/pasteur-meet-repo/scripts/apply-branding.sh

set -euo pipefail

JITSI_INSTALL_DIR="${JITSI_INSTALL_DIR:-/opt/jitsi}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

cd "$JITSI_INSTALL_DIR"
CONFIG="${CONFIG:-$HOME/.jitsi-meet-cfg}"
if [[ -f .env ]] && grep -q '^CONFIG=' .env; then
  CONFIG="$(grep '^CONFIG=' .env | cut -d= -f2- | tr -d '"' | tr -d "'")"
fi
CONFIG="${CONFIG/#\~/$HOME}"

echo "==> CONFIG=$CONFIG"
mkdir -p "$CONFIG/web"

cp -v "$REPO_ROOT/config/custom-config.js" "$CONFIG/web/custom-config.js"
cp -v "$REPO_ROOT/config/custom-interface_config.js" "$CONFIG/web/custom-interface_config.js"

LOGO_SRC=""
for candidate in \
  "$REPO_ROOT/logo.png" \
  "$REPO_ROOT/config/branding/logo.png" \
  "$REPO_ROOT/config/branding-logo.png"
do
  if [[ -f "$candidate" ]]; then
    LOGO_SRC="$candidate"
    break
  fi
done
[[ -n "$LOGO_SRC" ]] || { echo "ERROR: logo.png missing in repo"; exit 1; }
cp -v "$LOGO_SRC" "$CONFIG/web/pasteur-logo.png"

cp -v "$REPO_ROOT/config/docker-compose.branding.yml" "$JITSI_INSTALL_DIR/docker-compose.override.yml"

# Ensure Compose can resolve ${CONFIG} in override (absolute path, no ~)
if grep -q '^CONFIG=' .env; then
  sed -i "s|^CONFIG=.*|CONFIG=${CONFIG}|" .env
else
  echo "CONFIG=${CONFIG}" >> .env
fi

echo "==> Restarting web..."
docker compose up -d web
sleep 3
docker compose ps web
echo "Done. Hard-refresh browser (Ctrl+Shift+R) on https://meet.pasteur-plus.com"
echo "Logo URL check: https://meet.pasteur-plus.com/images/pasteur-logo.png"
