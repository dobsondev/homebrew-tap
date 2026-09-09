#!/usr/bin/env bash
# usb-controller-toggle — enable/disable the USB hub that feeds the wired
# controllers on the Bazzite HTPC.
#
# It writes the `disable` knob of every downstream port on that hub. Unlike
# toggling the hub's `authorized` flag, disabling a port power-cycles it, so
# controllers that sleep on USB disconnect (e.g. the 8BitDo 64) cold-boot and
# re-enumerate on their own when re-enabled — no unplug/replug needed.
#
# Usage:
#   usb-controller-toggle status     Print "enabled" or "disabled"
#   usb-controller-toggle enable      Re-enable the hub's ports
#   usb-controller-toggle disable     Disable the hub's ports (drops the controllers)
#   usb-controller-toggle toggle      Flip whichever state it is in
#   usb-controller-toggle detect      Show how the hub and its ports are resolved

set -euo pipefail
shopt -s nullglob

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}::${RESET} $*" >&2; }
success() { echo -e "${GREEN}✔${RESET} $*" >&2; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*" >&2; }
error()   { echo -e "${RED}✘${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Config ────────────────────────────────────────────────────────────────────
# Defaults identify the nested Genesys Logic hub on Alex's bazzite-projector:
# a 05e3:0610 hub whose parent is also a 05e3:0610 hub. Override any of these
# (or set HUB_PATH outright) in the config file or the environment.
HUB_VENDOR="${HUB_VENDOR:-05e3}"
HUB_PRODUCT="${HUB_PRODUCT:-0610}"
PARENT_VENDOR="${PARENT_VENDOR:-05e3}"
PARENT_PRODUCT="${PARENT_PRODUCT:-0610}"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/usb-controller-toggle/config"
# shellcheck disable=SC1090
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

USB_DEVICES_DIR="${USB_DEVICES_DIR:-/sys/bus/usb/devices}"
TEE_BIN="${TEE_BIN:-/usr/bin/tee}"

# ── Hub resolution ────────────────────────────────────────────────────────────

# Read a sysfs attribute, empty string if absent.
attr() { cat "$1/$2" 2>/dev/null || true; }

# Print every device dir under $USB_DEVICES_DIR that looks like our hub:
# a USB hub (bDeviceClass 09) matching HUB_VENDOR:HUB_PRODUCT whose parent
# device matches PARENT_VENDOR:PARENT_PRODUCT.
find_hub_candidates() {
  local dev real parent
  for dev in "$USB_DEVICES_DIR"/*/; do
    [[ -e "$dev/bDeviceClass" ]] || continue
    [[ "$(attr "$dev" bDeviceClass)" == "09" ]] || continue
    [[ "$(attr "$dev" idVendor)"  == "$HUB_VENDOR"  ]] || continue
    [[ "$(attr "$dev" idProduct)" == "$HUB_PRODUCT" ]] || continue
    real="$(readlink -f "$dev")"
    parent="$(dirname "$real")"
    [[ "$(attr "$parent" idVendor)"  == "$PARENT_VENDOR"  ]] || continue
    [[ "$(attr "$parent" idProduct)" == "$PARENT_PRODUCT" ]] || continue
    # Emit the /sys/bus/usb/devices/<name> form (not the realpath) so the port
    # paths below match the sudoers rule.
    echo "$USB_DEVICES_DIR/$(basename "$real")"
  done
}

# Resolve $HUB_PATH: explicit override wins, otherwise auto-detect a single
# candidate. Dies with guidance on zero / multiple matches.
resolve_hub_path() {
  if [[ -n "${HUB_PATH:-}" ]]; then
    [[ -d "$HUB_PATH" ]] || die "HUB_PATH is set to '$HUB_PATH' but that directory does not exist."
    return
  fi

  local -a candidates=()
  mapfile -t candidates < <(find_hub_candidates)

  case "${#candidates[@]}" in
    1) HUB_PATH="${candidates[0]}" ;;
    0) die "Could not find the controller hub (${HUB_VENDOR}:${HUB_PRODUCT} under ${PARENT_VENDOR}:${PARENT_PRODUCT}).
   The device may be unplugged. If the hub moved ports, run 'usb-controller-toggle detect'
   and pin HUB_PATH in $CONFIG_FILE." ;;
    *) die "Found ${#candidates[@]} hubs matching ${HUB_VENDOR}:${HUB_PRODUCT}: ${candidates[*]}
   Pin the right one as HUB_PATH in $CONFIG_FILE." ;;
  esac
}

# Print the `disable` knob of every downstream port on $HUB_PATH, e.g.
# /sys/bus/usb/devices/1-2.1/1-2.1:1.0/1-2.1-port1/disable
hub_port_disable_files() {
  local f
  for f in "$HUB_PATH"/*:*/*-port*/disable; do
    [[ -w "$f" || -e "$f" ]] && echo "$f"
  done
}

# ── State ─────────────────────────────────────────────────────────────────────

# "disabled" if every port is disabled, "enabled" otherwise.
read_state() {
  local -a files=()
  mapfile -t files < <(hub_port_disable_files)
  (( ${#files[@]} > 0 )) || die "No port 'disable' knobs found under $HUB_PATH."
  local f all_disabled=1
  for f in "${files[@]}"; do
    [[ "$(cat "$f" 2>/dev/null)" == "1" ]] || all_disabled=0
  done
  (( all_disabled )) && echo disabled || echo enabled
}

write_state() {
  local target="$1" value f
  value=$([[ "$target" == disabled ]] && echo 1 || echo 0)
  local -a files=()
  mapfile -t files < <(hub_port_disable_files)
  (( ${#files[@]} > 0 )) || die "No port 'disable' knobs found under $HUB_PATH."
  for f in "${files[@]}"; do
    if ! printf '%s' "$value" | sudo -n "$TEE_BIN" "$f" >/dev/null 2>&1; then
      die "Failed to write $f
   This needs a passwordless sudo rule for tee. Run the command from:
     brew info usb-controller-toggle"
    fi
  done
}

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_status() {
  resolve_hub_path
  read_state
}

cmd_set() {
  local target="$1"
  resolve_hub_path
  local current
  current="$(read_state)"
  if [[ "$current" == "$target" ]]; then
    info "Hub already $target ($HUB_PATH)"
  else
    write_state "$target"
    success "Hub $target ($HUB_PATH)"
  fi
  echo "$target"
}

cmd_toggle() {
  resolve_hub_path
  local current target
  current="$(read_state)"
  target=$([[ "$current" == enabled ]] && echo disabled || echo enabled)
  write_state "$target"
  success "Hub $target ($HUB_PATH)"
  echo "$target"
}

cmd_detect() {
  echo -e "${BOLD}${CYAN}━━━ usb-controller-toggle detect ━━━${RESET}" >&2
  info "Config file:   $CONFIG_FILE $( [[ -f "$CONFIG_FILE" ]] && echo '(loaded)' || echo '(absent)' )"
  info "Match rule:    hub ${HUB_VENDOR}:${HUB_PRODUCT} whose parent is ${PARENT_VENDOR}:${PARENT_PRODUCT}"
  if [[ -n "${HUB_PATH:-}" ]]; then
    info "HUB_PATH override: $HUB_PATH"
  fi
  local -a candidates=()
  mapfile -t candidates < <(find_hub_candidates)
  if (( ${#candidates[@]} == 0 )); then
    warn "No matching hub found."
  else
    info "Candidates:"
    local c
    for c in "${candidates[@]}"; do
      echo "    $c  (product='$(attr "$c" product)')" >&2
    done
  fi
  resolve_hub_path
  success "Resolved HUB_PATH: $HUB_PATH"
  info "Port disable knobs:"
  local f
  for f in $(hub_port_disable_files); do
    echo "    $f  (disable=$(cat "$f" 2>/dev/null))" >&2
  done
  echo "$HUB_PATH"
}

usage() {
  local bin; bin="$(basename "$0")"
  cat << EOF

usb-controller-toggle — toggle the wired-controller USB hub on the Bazzite HTPC

Usage:
  ${bin} status      Print "enabled" or "disabled"
  ${bin} enable      Re-enable the hub's ports
  ${bin} disable     Disable the hub's ports (the wired controllers disappear)
  ${bin} toggle      Flip whichever state the hub is in
  ${bin} detect      Show how the hub and its ports are resolved

Options:
  -h, --help    Show this help message

Configuration ($CONFIG_FILE, shell syntax — all optional):
  HUB_PATH=/sys/bus/usb/devices/1-2.1   Pin the hub explicitly (skips auto-detect)
  HUB_VENDOR / HUB_PRODUCT              Override the hub USB id  (default 05e3:0610)
  PARENT_VENDOR / PARENT_PRODUCT        Override the parent id   (default 05e3:0610)

Toggling requires a passwordless sudo rule for tee — see:
  brew info usb-controller-toggle
EOF
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    status)          cmd_status ;;
    enable|on)       cmd_set enabled ;;
    disable|off)     cmd_set disabled ;;
    toggle)          cmd_toggle ;;
    detect)          cmd_detect ;;
    help|--help|-h)  usage ;;
    *)               usage; exit 1 ;;
  esac
}

main "$@"
