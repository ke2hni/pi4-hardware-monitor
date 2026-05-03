#!/usr/bin/env bash
set -Eeuo pipefail

# Pi 4 Hardware Monitor uninstaller
# Removes the Cockpit plugin install, history collector units/script, and optional history data.

SCRIPT_NAME=$(basename "$0")
SCRIPT_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_PLUGIN_ID="pi-monitor"
DEFAULT_INSTALL_ROOT="/usr/local/share/cockpit"
DEFAULT_HISTORY_DIR="/var/lib/pi-monitor"
DEFAULT_HISTORY_PATH="$DEFAULT_HISTORY_DIR/history.ndjson"
HISTORY_SERVICE="pi-monitor-history.service"
HISTORY_TIMER="pi-monitor-history.timer"
HISTORY_SCRIPT="/usr/local/bin/pi-monitor-history"
INSTALL_DEGRADED=0
INTERACTIVE=0
[[ -t 0 && -t 1 ]] && INTERACTIVE=1

REAL_USER="${SUDO_USER:-}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  REAL_USER=$(logname 2>/dev/null || true)
fi
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  REAL_USER=""
fi

declare -a SUMMARY_REMOVED=()
declare -a SUMMARY_SKIPPED=()
declare -a SUMMARY_WARNINGS=()
declare -a SUMMARY_ACTIONS=()

declare -a PLUGIN_IDS=()

action_added=0

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

warn() {
  printf '[%s] WARNING: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  SUMMARY_WARNINGS+=("$*")
  INSTALL_DEGRADED=1
}

add_summary_unique() {
  local array_name="$1"
  local value="$2"
  local -n arr_ref="$array_name"
  local item
  for item in "${arr_ref[@]:-}"; do
    [[ "$item" == "$value" ]] && return 0
  done
  arr_ref+=("$value")
}

ask_yes_no() {
  local prompt="$1"
  local default_answer="${2:-N}"
  local answer=""

  if [[ "$INTERACTIVE" -ne 1 ]]; then
    [[ "$default_answer" =~ ^[Yy]$ ]]
    return
  fi

  while true; do
    read -r -p "$prompt " answer || true
    answer=${answer:-$default_answer}
    case "$answer" in
      Y|y|Yes|yes) return 0 ;;
      N|n|No|no) return 1 ;;
      *) printf 'Please answer y or n.\n' ;;
    esac
  done
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    printf '[%s] ERROR: Run this uninstaller as root, usually with sudo.\n' "$(date '+%Y-%m-%d %H:%M:%S')" >&2
    exit 1
  fi
}

print_startup_context() {
  log "Uninstaller path: $SCRIPT_PATH"
  log "Project root: $PROJECT_ROOT"
  log "Interactive mode: $INTERACTIVE"
  if [[ -n "$REAL_USER" ]]; then
    log "Detected non-root user: $REAL_USER"
  else
    log "Detected non-root user: none"
  fi
}

resolve_plugin_ids() {
  local manifest=""
  local parsed=""

  if [[ -f "./src/manifest.json" ]]; then
    manifest="./src/manifest.json"
  elif [[ -f "./manifest.json" ]]; then
    manifest="./manifest.json"
  fi

  if [[ -n "$manifest" ]]; then
    parsed=$(python3 - <<'PY' "$manifest" 2>/dev/null || true
import json, sys
path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
    for key in ('id', 'package'):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            print(value.strip())
            break
except Exception:
    pass
PY
)
  fi

  PLUGIN_IDS+=("${parsed:-$DEFAULT_PLUGIN_ID}")
  [[ " ${PLUGIN_IDS[*]} " == *" $DEFAULT_PLUGIN_ID "* ]] || PLUGIN_IDS+=("$DEFAULT_PLUGIN_ID")

  # Safety cleanup for earlier dev/source naming seen during testing.
  [[ " ${PLUGIN_IDS[*]} " == *" pi4-monitor "* ]] || PLUGIN_IDS+=("pi4-monitor")
}

stop_history_units() {
  log "Stopping Pi Monitor history units"

  if systemctl list-unit-files "$HISTORY_TIMER" >/dev/null 2>&1 || systemctl list-units "$HISTORY_TIMER" >/dev/null 2>&1; then
    if systemctl disable --now "$HISTORY_TIMER" >/dev/null 2>&1; then
      add_summary_unique SUMMARY_REMOVED "Disabled/stopped $HISTORY_TIMER"
    else
      warn "Could not disable/stop $HISTORY_TIMER"
    fi
  else
    add_summary_unique SUMMARY_SKIPPED "$HISTORY_TIMER not registered"
  fi

  if systemctl list-unit-files "$HISTORY_SERVICE" >/dev/null 2>&1 || systemctl list-units "$HISTORY_SERVICE" >/dev/null 2>&1; then
    if systemctl stop "$HISTORY_SERVICE" >/dev/null 2>&1 || true; then
      add_summary_unique SUMMARY_REMOVED "Stopped $HISTORY_SERVICE if active"
    else
      warn "Could not stop $HISTORY_SERVICE"
    fi
  else
    add_summary_unique SUMMARY_SKIPPED "$HISTORY_SERVICE not registered"
  fi
}

remove_history_files() {
  log "Removing Pi Monitor history service files"

  local path
  for path in "/etc/systemd/system/$HISTORY_SERVICE" "/etc/systemd/system/$HISTORY_TIMER" "$HISTORY_SCRIPT"; do
    if [[ -e "$path" || -L "$path" ]]; then
      rm -f -- "$path"
      add_summary_unique SUMMARY_REMOVED "$path"
    else
      add_summary_unique SUMMARY_SKIPPED "$path not present"
    fi
  done

  systemctl daemon-reload || warn "systemctl daemon-reload failed"
  systemctl reset-failed "$HISTORY_SERVICE" "$HISTORY_TIMER" >/dev/null 2>&1 || true
}

remove_plugin_dirs() {
  local plugin_id install_dir user_dir root_dir system_dir

  for plugin_id in "${PLUGIN_IDS[@]}"; do
    install_dir="$DEFAULT_INSTALL_ROOT/$plugin_id"
    system_dir="/usr/share/cockpit/$plugin_id"
    root_dir="/root/.local/share/cockpit/$plugin_id"

    for path in "$install_dir" "$system_dir" "$root_dir"; do
      if [[ -d "$path" || -L "$path" ]]; then
        log "Removing Cockpit plugin path: $path"
        rm -rf -- "$path"
        add_summary_unique SUMMARY_REMOVED "$path"
      else
        add_summary_unique SUMMARY_SKIPPED "$path not present"
      fi
    done

    if [[ -n "$REAL_USER" && -d "/home/$REAL_USER/.local/share/cockpit/$plugin_id" ]]; then
      user_dir="/home/$REAL_USER/.local/share/cockpit/$plugin_id"
      log "Removing user-local Cockpit plugin path: $user_dir"
      rm -rf -- "$user_dir"
      add_summary_unique SUMMARY_REMOVED "$user_dir"
    fi
  done
}

remove_history_data() {
  if [[ ! -e "$DEFAULT_HISTORY_DIR" ]]; then
    add_summary_unique SUMMARY_SKIPPED "$DEFAULT_HISTORY_DIR not present"
    return 0
  fi

  if ask_yes_no "Remove Pi Monitor history data at $DEFAULT_HISTORY_DIR? This enables a fully fresh history state. [Y/n]" "Y"; then
    rm -rf -- "$DEFAULT_HISTORY_DIR"
    add_summary_unique SUMMARY_REMOVED "$DEFAULT_HISTORY_DIR"
  else
    add_summary_unique SUMMARY_SKIPPED "$DEFAULT_HISTORY_DIR kept by user choice"
    add_summary_unique SUMMARY_ACTIONS "Remove $DEFAULT_HISTORY_DIR manually before reinstall if you want a completely fresh history file."
  fi
}

remove_repo_build_artifacts() {
  local path
  local -a repo_artifacts=(
    "$PROJECT_ROOT/dist"
    "$PROJECT_ROOT/node_modules"
    "$PROJECT_ROOT/package-lock.json"
  )

  local found=0
  for path in "${repo_artifacts[@]}"; do
    if [[ -e "$path" || -L "$path" ]]; then
      found=1
      break
    fi
  done

  if [[ "$found" -ne 1 ]]; then
    add_summary_unique SUMMARY_SKIPPED "Local repo build artifacts not present"
    return 0
  fi

  if ask_yes_no "Remove local repo build artifacts in $PROJECT_ROOT (dist, node_modules, package-lock.json)? This enables a clean rebuild. [y/N]" "N"; then
    for path in "${repo_artifacts[@]}"; do
      if [[ -e "$path" || -L "$path" ]]; then
        rm -rf -- "$path"
        add_summary_unique SUMMARY_REMOVED "$path"
      else
        add_summary_unique SUMMARY_SKIPPED "$path not present"
      fi
    done
  else
    add_summary_unique SUMMARY_SKIPPED "Local repo build artifacts kept by user choice"
    add_summary_unique SUMMARY_ACTIONS "For a fully clean rebuild later, remove: $PROJECT_ROOT/dist $PROJECT_ROOT/node_modules $PROJECT_ROOT/package-lock.json"
  fi
}

refresh_cockpit() {
  if command -v cockpit-bridge >/dev/null 2>&1; then
    local packages_output=""
    packages_output=$(cockpit-bridge --packages 2>/dev/null || true)
    if grep -Eq 'pi-monitor|pi4-monitor' <<<"$packages_output"; then
      warn "cockpit-bridge still lists a Pi Monitor package after removal. Check for another stale Cockpit plugin copy."
      add_summary_unique SUMMARY_ACTIONS "Run: cockpit-bridge --packages | grep -E 'pi-monitor|pi4-monitor'"
    else
      add_summary_unique SUMMARY_REMOVED "Cockpit package registration cleared for Pi Monitor"
    fi
  else
    add_summary_unique SUMMARY_SKIPPED "cockpit-bridge not available for registration check"
  fi

  add_summary_unique SUMMARY_ACTIONS "Refresh Cockpit with Ctrl+F5 after reinstall, or log out/in if the old page remains cached."
}

print_summary() {
  printf '%s\n' '========== Pi 4 Hardware Monitor uninstall summary =========='

  if ((${#SUMMARY_REMOVED[@]})); then
    printf '\nRemoved/stopped:\n'
    printf '  - %s\n' "${SUMMARY_REMOVED[@]}"
  fi

  if ((${#SUMMARY_SKIPPED[@]})); then
    printf '\nSkipped/not present:\n'
    printf '  - %s\n' "${SUMMARY_SKIPPED[@]}"
  fi

  if ((${#SUMMARY_WARNINGS[@]})); then
    printf '\nWarnings:\n'
    printf '  - %s\n' "${SUMMARY_WARNINGS[@]}"
  fi

  if ((${#SUMMARY_ACTIONS[@]})); then
    printf '\nManual follow-up:\n'
    printf '  - %s\n' "${SUMMARY_ACTIONS[@]}"
  fi

  if [[ "$INSTALL_DEGRADED" -eq 1 ]]; then
    printf '\nResult: uninstall completed with warnings. Review the items above.\n'
  else
    printf '\nResult: uninstall completed.\n'
  fi
}

main() {
  require_root
  print_startup_context
  resolve_plugin_ids
  stop_history_units
  remove_history_files
  remove_plugin_dirs
  remove_history_data
  remove_repo_build_artifacts
  refresh_cockpit
  print_summary
}

trap 'printf "[%s] ERROR: Uninstaller aborted unexpectedly at line %s.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "$LINENO" >&2' ERR
main "$@"
