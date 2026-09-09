#!/usr/bin/env bash
# usb-controller-tray — KDE/Plasma system-tray indicator for usb-controller-toggle.
#
# Green controller = hub enabled (wired controllers present)
# Red controller   = hub disabled
# Amber controller = switching
# Grey controller  = hub could not be found
#
# Left-click toggles. Middle-click quits.
#
# Usage:
#   usb-controller-tray                    Run the tray indicator (foreground)
#   usb-controller-tray install-autostart  Add a ~/.config/autostart entry
#   usb-controller-tray uninstall-autostart

set -euo pipefail

POLL_SECONDS="${POLL_SECONDS:-0.5}"
BUSY_TIMEOUT="${BUSY_TIMEOUT:-8}"   # ignore a stale busy marker older than this

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; RESET='\033[0m'
info()    { echo -e "${CYAN}::${RESET} $*" >&2; }
success() { echo -e "${GREEN}✔${RESET} $*" >&2; }
error()   { echo -e "${RED}✘${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

SELF="$(readlink -f "$0" 2>/dev/null || echo "$0")"
BIN_DIR="$(dirname "$SELF")"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
BUSY_FILE="$RUNTIME_DIR/usb-controller-tray.busy"
CLICK_STAMP="$RUNTIME_DIR/usb-controller-tray.click"
CLICK_DEBOUNCE_MS="${CLICK_DEBOUNCE_MS:-1200}"

# usb-controller-toggle lives next to this script in the keg's bin/. Use the
# absolute path so the tray works even when PATH lacks Homebrew (Plasma autostart).
TOGGLE_BIN="$BIN_DIR/usb-controller-toggle"
[[ -x "$TOGGLE_BIN" ]] || TOGGLE_BIN="$(command -v usb-controller-toggle 2>/dev/null || echo usb-controller-toggle)"

# ── Locate shipped assets ─────────────────────────────────────────────────────
resolve_share_dir() {
  local candidate
  candidate="$BIN_DIR/../share/usb-controller-toggle"
  if [[ -d "$candidate" ]]; then
    ( cd "$candidate" && pwd )
    return
  fi
  candidate="$(brew --prefix 2>/dev/null)/share/usb-controller-toggle"
  [[ -d "$candidate" ]] && { echo "$candidate"; return; }
  die "Could not locate the usb-controller-toggle asset directory."
}

DESKTOP_FILENAME="usb-controller-toggle.desktop"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"

cmd_install_autostart() {
  local share_dir; share_dir="$(resolve_share_dir)"
  [[ -f "$share_dir/$DESKTOP_FILENAME" ]] || die "Missing $share_dir/$DESKTOP_FILENAME"
  mkdir -p "$AUTOSTART_DIR"
  # Rewrite Exec= to an absolute path — Homebrew may not be on PATH when the
  # autostart entry fires. Prefer the version-stable linked bin over $SELF
  # (which readlink-resolves to a versioned Cellar path).
  local exec_path
  exec_path="$(command -v usb-controller-tray 2>/dev/null || echo "$SELF")"
  sed "s|^Exec=.*|Exec=$exec_path|" "$share_dir/$DESKTOP_FILENAME" > "$AUTOSTART_DIR/$DESKTOP_FILENAME"
  success "Installed autostart entry: $AUTOSTART_DIR/$DESKTOP_FILENAME"
}

cmd_uninstall_autostart() {
  rm -f "$AUTOSTART_DIR/$DESKTOP_FILENAME"
  success "Removed autostart entry: $AUTOSTART_DIR/$DESKTOP_FILENAME"
}

# ── Left-click handler (invoked by yad) ───────────────────────────────────────
# Debounces rapid re-fires from the X11 tray bridge, marks the tray "busy" so
# the loop paints the amber icon, runs the toggle, then clears the marker.
cmd_click() {
  local now prev
  now="$(date +%s%3N)"
  prev="$(cat "$CLICK_STAMP" 2>/dev/null || echo 0)"
  [[ "$prev" =~ ^[0-9]+$ ]] || prev=0
  (( now - prev < CLICK_DEBOUNCE_MS )) && return 0
  echo "$now" > "$CLICK_STAMP" 2>/dev/null || true

  : > "$BUSY_FILE" 2>/dev/null || true
  "$TOGGLE_BIN" toggle >/dev/null 2>&1 || true
  rm -f "$BUSY_FILE" 2>/dev/null || true
}

# ── Tray loop ─────────────────────────────────────────────────────────────────
busy_active() {
  [[ -f "$BUSY_FILE" ]] || return 1
  local now mtime
  now="$(date +%s)"
  mtime="$(stat -c %Y "$BUSY_FILE" 2>/dev/null || echo 0)"
  if (( now - mtime > BUSY_TIMEOUT )); then
    rm -f "$BUSY_FILE" 2>/dev/null || true
    return 1
  fi
  return 0
}

cmd_tray() {
  command -v yad >/dev/null 2>&1 || {
    command -v notify-send >/dev/null 2>&1 && \
      notify-send "usb-controller-tray" "yad is not installed — run: rpm-ostree install yad"
    die "yad is not installed. On Bazzite: rpm-ostree install yad"
  }

  # yad's tray icon is a GtkStatusIcon, unsupported on a pure Wayland session —
  # force the X11 backend so it runs under XWayland and Plasma's xembedsniproxy
  # bridges it into the system tray.
  export GDK_BACKEND="${GDK_BACKEND:-x11}"

  local share_dir; share_dir="$(resolve_share_dir)"
  local icon_enabled="$share_dir/icon-enabled.svg"
  local icon_disabled="$share_dir/icon-disabled.svg"
  local icon_busy="$share_dir/icon-busy.svg"
  local icon_unknown="$share_dir/icon-unknown.svg"

  rm -f "$BUSY_FILE" "$CLICK_STAMP" 2>/dev/null || true

  # Start yad once; stream icon/tooltip updates to it on fd 3.
  # Left-click runs the toggle handler; middle-click quits.
  exec 3> >(yad --notification --listen \
    --image="$icon_unknown" \
    --text="USB controllers" \
    --command="$SELF __click")

  # yad gone (middle-click quit) → writing to fd 3 raises SIGPIPE → clean exit.
  trap 'exec 3>&- 2>/dev/null || true; rm -f "$BUSY_FILE" "$CLICK_STAMP" 2>/dev/null || true; exit 0' PIPE INT TERM

  sleep 1
  if ! pgrep -x yad >/dev/null 2>&1; then
    die "yad exited on start. A graphical session with X11 or XWayland is required."
  fi

  local paint_icon paint_tip state
  while :; do
    if busy_active; then
      paint_icon="$icon_busy"; paint_tip="Switching…"
    else
      state="$("$TOGGLE_BIN" status 2>/dev/null || echo unknown)"
      case "$state" in
        enabled)  paint_icon="$icon_enabled";  paint_tip="Wired controllers: enabled" ;;
        disabled) paint_icon="$icon_disabled"; paint_tip="Wired controllers: disabled" ;;
        *)        paint_icon="$icon_unknown";  paint_tip="Wired controllers: hub not found" ;;
      esac
    fi
    printf 'icon:%s\ntooltip:%s\n' "$paint_icon" "$paint_tip" >&3
    sleep "$POLL_SECONDS"
  done
}

usage() {
  local bin; bin="$(basename "$0")"
  cat << EOF

usb-controller-tray — Plasma tray indicator for usb-controller-toggle

Usage:
  ${bin}                       Run the tray indicator (foreground)
  ${bin} install-autostart     Add a ~/.config/autostart entry
  ${bin} uninstall-autostart   Remove that entry

Options:
  -h, --help    Show this help message

Needs 'yad' (ships with Bazzite). Controller icon: green = enabled,
red = disabled, amber = switching, grey = hub not found.
Left-click toggles; middle-click quits.
EOF
}

main() {
  case "${1:-}" in
    ""|tray|run)          cmd_tray ;;
    __click)              cmd_click ;;
    install-autostart)    cmd_install_autostart ;;
    uninstall-autostart)  cmd_uninstall_autostart ;;
    help|--help|-h)       usage ;;
    *)                    usage; exit 1 ;;
  esac
}

main "$@"
