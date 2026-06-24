#!/usr/bin/env bash
# desktop-file-helper — Manage custom .desktop files on Bazzite
# Usage:
#   desktop-file-helper create [APP_DIR]
#   desktop-file-helper update [APP_DIR]

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
DESKTOP_INSTALL_DIR="${HOME}/.local/share/applications"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}::${RESET} $*"; }
success() { echo -e "${GREEN}✔${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✘${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

header() {
  echo ""
  echo -e "${BOLD}${CYAN}━━━ $* ━━━${RESET}"
  echo ""
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Prompt with a default value; prints result to stdout
prompt() {
  local label="$1" default="$2"
  local display_default=""
  [[ -n "$default" ]] && display_default=" ${YELLOW}[${default}]${RESET}"
  echo -ne "${BOLD}${label}${RESET}${display_default}: " >&2
  local value
  read -r value
  echo "${value:-$default}"
}

# Prompt yes/no — returns 0 for yes, 1 for no
confirm() {
  local label="$1" default="${2:-y}"
  local hint="[Y/n]"
  [[ "$default" == "n" ]] && hint="[y/N]"
  echo -ne "${BOLD}${label}${RESET} ${hint}: " >&2
  local value
  read -r value
  value="${value:-$default}"
  [[ "$value" =~ ^[Yy] ]]
}

# Find the first AppImage in a directory
find_appimage() {
  local dir="$1"
  find "$dir" -maxdepth 1 -name "*.AppImage" -o -name "*.appimage" 2>/dev/null | head -1
}

# Find the desktop-icon file (png, jpg, or jpeg)
find_icon() {
  local dir="$1"
  find "$dir" -maxdepth 1 -name "desktop-icon.*" 2>/dev/null \
    | grep -Ei '\.(png|jpg|jpeg)$' | head -1
}

# Derive a sane app name from a filename
# e.g. "SoH-8.0.3-Linux.AppImage" → "SoH"
derive_name() {
  local filename
  filename="$(basename "$1")"
  # Strip extension
  filename="${filename%%.AppImage}"
  filename="${filename%%.appimage}"
  # Take everything before the first digit/dash/underscore separator
  echo "$filename" | sed -E 's/[-_]?[0-9].*//'
}

# Sanitise into a valid desktop file Name= key (no slashes)
sanitise_name() {
  echo "$1" | tr -d '/'
}

# ── Resolve app directory ─────────────────────────────────────────────────────
resolve_app_dir() {
  local app_dir="${1:-}"
  if [[ -z "$app_dir" ]]; then
    app_dir="$(prompt "App directory" "$(pwd)")"
  fi
  app_dir="${app_dir%/}"  # strip trailing slash
  [[ -d "$app_dir" ]] || die "Directory not found: $app_dir"
  echo "$app_dir"
}

# ── Write .desktop file ───────────────────────────────────────────────────────
write_desktop_file() {
  local desktop_path="$1"
  shift
  local name="$1" exec_path="$2" path_dir="$3" icon="$4" comment="$5" categories="$6"

  mkdir -p "$(dirname "$desktop_path")"
  cat > "$desktop_path" << EOF
[Desktop Entry]
Name=${name}
Comment=${comment}
# Keep quotes here for exec
Exec="${exec_path}"
# Remove quotes here for path
Path=${path_dir}
Icon=${icon}
Terminal=false
Type=Application
Categories=${categories}
EOF
  success "Wrote: $desktop_path"
}

# ── CREATE ────────────────────────────────────────────────────────────────────
cmd_create() {
  local app_dir
  app_dir="$(resolve_app_dir "${1:-}")"

  header "Create .desktop file"
  info "App directory: $app_dir"
  echo ""

  # ── Detect AppImage ────────────────────────────────────────────────────────
  local appimage
  appimage="$(find_appimage "$app_dir")"
  if [[ -n "$appimage" ]]; then
    info "Found AppImage: $(basename "$appimage")"
  else
    warn "No AppImage found in directory."
    appimage="$(prompt "Path to executable" "")"
    [[ -f "$appimage" ]] || die "Executable not found: $appimage"
  fi

  # ── chmod AppImage ─────────────────────────────────────────────────────────
  if [[ ! -x "$appimage" ]]; then
    info "AppImage is not executable — fixing..."
    chmod +x "$appimage"
    success "chmod +x applied to $(basename "$appimage")"
  else
    success "AppImage is already executable"
  fi

  # ── Detect icon ────────────────────────────────────────────────────────────
  local icon_path
  icon_path="$(find_icon "$app_dir")"
  if [[ -n "$icon_path" ]]; then
    info "Found icon: $(basename "$icon_path")"
  else
    warn "No 'desktop-icon.png/jpg/jpeg' found."
    icon_path="$(prompt "Path to icon file (leave blank to skip)" "")"
  fi

  # ── Gather details ─────────────────────────────────────────────────────────
  echo ""
  info "Fill in the .desktop entry details:"
  echo ""

  local default_name
  default_name="$(derive_name "$appimage")"

  local name
  name="$(prompt "App name" "$default_name")"
  name="$(sanitise_name "$name")"

  local desktop_filename
  desktop_filename="$(prompt "Desktop filename (without .desktop)" "$name")"
  desktop_filename="${desktop_filename%.desktop}"

  local comment
  comment="$(prompt "Comment / description" "$name")"

  local categories
  categories="$(prompt "Categories" "Game;Emulator;")"

  # ── Confirm & write ────────────────────────────────────────────────────────
  local desktop_path="${app_dir}/${desktop_filename}.desktop"
  local symlink_path="${DESKTOP_INSTALL_DIR}/${desktop_filename}.desktop"

  echo ""
  info "Summary:"
  echo -e "  Name:       ${BOLD}${name}${RESET}"
  echo -e "  Exec:       \"${appimage}\""
  echo -e "  Path:       ${app_dir}"
  echo -e "  Icon:       ${icon_path}"
  echo -e "  Comment:    ${comment}"
  echo -e "  Categories: ${categories}"
  echo -e "  Output:     ${desktop_path}"
  echo -e "  Symlink:    ${symlink_path}"
  echo ""

  confirm "Write .desktop file?" "y" || { info "Aborted."; exit 0; }

  write_desktop_file "$desktop_path" "$name" "$appimage" "$app_dir" "$icon_path" "$comment" "$categories"
  mkdir -p "$DESKTOP_INSTALL_DIR"
  ln -sf "$desktop_path" "$symlink_path"
  success "Symlinked: $symlink_path → $desktop_path"

  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_INSTALL_DIR" 2>/dev/null || true
  fi

  echo ""
  success "Done! '$name' should now appear in your application launcher."
}

# ── UPDATE ────────────────────────────────────────────────────────────────────
cmd_update() {
  local app_dir
  app_dir="$(resolve_app_dir "${1:-}")"

  header "Update .desktop file"
  info "App directory: $app_dir"
  echo ""

  # ── Find existing .desktop file ────────────────────────────────────────────
  local existing_desktop all_count
  all_count="$(find "$app_dir" -maxdepth 1 -name "*.desktop" 2>/dev/null | wc -l | tr -d ' ')"
  existing_desktop="$(find "$app_dir" -maxdepth 1 -name "*.desktop" 2>/dev/null | head -20 || true)"

  if [[ -z "$existing_desktop" ]]; then
    die "No .desktop files found in $app_dir"
  fi

  if (( all_count > 20 )); then
    warn "Found ${all_count} .desktop files in $app_dir — only showing the first 20."
  fi

  info "Available .desktop files in $app_dir:"
  local i=1
  local -a desktop_files=()
  while IFS= read -r f; do
    local display_name
    display_name="$(grep -m1 '^Name=' "$f" 2>/dev/null | cut -d= -f2 || basename "$f")"
    echo -e "  ${YELLOW}${i}${RESET}) ${display_name}  ${CYAN}($(basename "$f"))${RESET}"
    desktop_files+=("$f")
    ((i++))
  done <<< "$existing_desktop"

  echo ""
  local choice
  choice="$(prompt "Select file number" "1")"
  local desktop_path="${desktop_files[$((choice - 1))]}"
  [[ -f "$desktop_path" ]] || die "Invalid selection"

  info "Selected: $(basename "$desktop_path")"
  echo ""

  # ── Read existing values as defaults ──────────────────────────────────────
  local old_exec old_icon old_name old_comment old_categories old_path
  old_name="$(grep -m1 '^Name=' "$desktop_path" | cut -d= -f2 || echo "")"
  # Strip surrounding quotes from Exec= so we don't double-quote on re-write
  old_exec="$(grep -m1 '^Exec=' "$desktop_path" | cut -d= -f2- | tr -d '"' || echo "")"
  old_path="$(grep -m1 '^Path=' "$desktop_path" | cut -d= -f2 || echo "")"
  old_icon="$(grep -m1 '^Icon=' "$desktop_path" | cut -d= -f2 || echo "")"
  old_comment="$(grep -m1 '^Comment=' "$desktop_path" | cut -d= -f2 || echo "")"
  old_categories="$(grep -m1 '^Categories=' "$desktop_path" | cut -d= -f2 || echo "")"

  # ── Detect new AppImage ────────────────────────────────────────────────────
  local new_appimage
  new_appimage="$(find_appimage "$app_dir")"

  if [[ -n "$new_appimage" ]]; then
    info "Found AppImage: $(basename "$new_appimage")"
    info "Current Exec:  $old_exec"
    if confirm "Use new AppImage as Exec?" "y"; then
      old_exec="$new_appimage"
      old_path="$app_dir"
    fi
  fi

  # ── chmod AppImage ─────────────────────────────────────────────────────────
  if [[ -f "$old_exec" && ! -x "$old_exec" ]]; then
    info "AppImage is not executable — fixing..."
    chmod +x "$old_exec"
    success "chmod +x applied"
  elif [[ -f "$old_exec" ]]; then
    success "AppImage is already executable"
  fi

  # ── Detect icon ────────────────────────────────────────────────────────────
  local new_icon_src
  new_icon_src="$(find_icon "$app_dir")"
  if [[ -n "$new_icon_src" ]]; then
    info "Found icon in app dir: $(basename "$new_icon_src")"
    if confirm "Use this as the icon?" "y"; then
      old_icon="$new_icon_src"
    fi
  fi

  # ── Confirm fields ─────────────────────────────────────────────────────────
  echo ""
  info "Review / edit fields (press Enter to keep current value):"
  echo ""

  local name comment categories exec_path path_dir icon
  name="$(prompt "Name" "$old_name")"
  comment="$(prompt "Comment" "$old_comment")"
  categories="$(prompt "Categories" "$old_categories")"
  exec_path="$(prompt "Exec" "$old_exec")"
  path_dir="$(prompt "Path" "$old_path")"
  icon="$(prompt "Icon" "$old_icon")"

  # ── Summary & write ────────────────────────────────────────────────────────
  echo ""
  info "Summary:"
  echo -e "  Name:       ${BOLD}${name}${RESET}"
  echo -e "  Exec:       \"${exec_path}\""
  echo -e "  Path:       ${path_dir}"
  echo -e "  Icon:       ${icon}"
  echo -e "  Comment:    ${comment}"
  echo -e "  Categories: ${categories}"
  echo -e "  Output:     ${desktop_path}"
  echo ""

  confirm "Overwrite ${desktop_path}?" "y" || { info "Aborted."; exit 0; }

  write_desktop_file "$desktop_path" "$name" "$exec_path" "$path_dir" "$icon" "$comment" "$categories"

  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_INSTALL_DIR" 2>/dev/null || true
  fi

  echo ""
  success "Done! Desktop entry updated."
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  local bin
  bin="$(basename "$0")"
  cat << EOF

desktop-file-helper — Manage custom .desktop files on Bazzite

Usage:
  ${bin} create [APP_DIR]   Create a new .desktop file
  ${bin} update [APP_DIR]   Update an existing .desktop file

Options:
  -h, --help    Show this help message

If APP_DIR is omitted you will be prompted, defaulting to the current directory.

The script will:
  - Auto-detect an AppImage and desktop-icon.png/jpg/jpeg in APP_DIR
  - chmod +x the AppImage if needed
  - Write the .desktop file to ~/.local/share/applications/
EOF
}

# ── Entrypoint ────────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    create) cmd_create "$@" ;;
    update) cmd_update "$@" ;;
    help|--help|-h) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
