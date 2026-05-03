#!/usr/bin/env bash
set -Eeuo pipefail

# Prefer disk-backed temp space on systems with tiny /tmp tmpfs
export TMPDIR=/var/tmp

if [ "$(df --output=avail /tmp | tail -1)" -lt 102400 ]; then
    echo "[INFO] Low /tmp space detected, cleaning..."
    rm -rf /tmp/*
fi

SCRIPT_NAME=$(basename "$0")
SCRIPT_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

DEFAULT_PLUGIN_ID="pi-monitor"
DEFAULT_INSTALL_ROOT="/usr/local/share/cockpit"
DEFAULT_HISTORY_DIR="/var/lib/pi-monitor"
DEFAULT_HISTORY_PATH="$DEFAULT_HISTORY_DIR/history.ndjson"

APT_UPDATED=0
INTERACTIVE=0
HISTORY_COMPONENTS_INSTALLED=0
INSTALL_DEGRADED=0
VIDEO_GROUP_CHANGED=0
SMART_SUDO_CHANGED=0

[[ -t 0 && -t 1 ]] && INTERACTIVE=1

REAL_USER="${SUDO_USER:-}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  REAL_USER=$(logname 2>/dev/null || true)
fi
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  REAL_USER=""
fi

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

warn() {
  printf '[%s] WARNING: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  INSTALL_DEGRADED=1
}

fail() {
  echo "[ERROR] $1"
  exit 1
}

require_root() {
  [[ "$EUID" -eq 0 ]] || fail "Run this installer as root"
}

ensure_project_root() {
  cd "$PROJECT_ROOT"
}

check_cockpit_presence() {
  command -v cockpit-bridge >/dev/null 2>&1 || fail "cockpit-bridge missing"
  cockpit-bridge --packages >/dev/null 2>&1 || fail "cockpit-bridge not working"
}

build_and_install_plugin() {
  log "Building plugin"
  make || fail "build failed"

  log "Installing plugin"
  make install || fail "install failed"
}

install_history_components() {
  log "Installing history collector"

  install -d -m 0755 /usr/local/bin /etc/systemd/system "$DEFAULT_HISTORY_DIR"

  install -m 0755 ./pi-monitor-history /usr/local/bin/pi-monitor-history
  install -m 0644 ./pi-monitor-history.service /etc/systemd/system/
  install -m 0644 ./pi-monitor-history.timer /etc/systemd/system/

  systemctl daemon-reload
  systemctl enable --now pi-monitor-history.timer
  systemctl start pi-monitor-history.service

  HISTORY_COMPONENTS_INSTALLED=1
}

validate_history() {
  /usr/local/bin/pi-monitor-history || fail "history script failed"

  if [[ ! -s "$DEFAULT_HISTORY_PATH" ]]; then
    fail "history file missing"
  fi

  log "History validated"
}

validate_vcgencmd() {
  if command -v vcgencmd >/dev/null 2>&1; then
    vcgencmd measure_temp || warn "vcgencmd failed"
  else
    warn "vcgencmd missing"
  fi
}

post_install_validation() {
  cockpit-bridge --packages | grep -q "$DEFAULT_PLUGIN_ID" \
    && log "Cockpit registration OK" \
    || warn "Plugin not visible in Cockpit"

  if [[ "$HISTORY_COMPONENTS_INSTALLED" -eq 1 ]]; then
    validate_history
  fi
}

main() {
  require_root
  ensure_project_root

  log "Starting Pi 4 installer"

  apt-get update
  apt-get install -y make nodejs npm python3 cockpit-bridge

  check_cockpit_presence
  validate_vcgencmd

  build_and_install_plugin
  install_history_components
  post_install_validation

  log "Install complete"
}

trap 'fail "Installer aborted unexpectedly"' ERR
main "$@"
```
