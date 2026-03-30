#!/usr/bin/env bash
# =============================================================================
#  install/apps.sh — Install editor extensions for Cursor and VS Code
#  Called by bootstrap.sh; safe to re-run (idempotent)
# =============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTENSIONS_FILE="${DOTFILES_DIR}/cursor/extensions.txt"

log()  { printf '\033[0;32m==>\033[0m %s\n' "$*"; }
info() { printf '\033[0;34m   →\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

install_extensions() {
  local cli_cmd="$1"
  local label="$2"

  if ! command -v "$cli_cmd" &>/dev/null; then
    warn "${label} CLI '${cli_cmd}' not found — skipping."
    warn "Open ${label} manually and install extensions from: ${EXTENSIONS_FILE}"
    return 0
  fi

  log "Installing ${label} extensions..."

  # Get currently installed extensions (lowercase for comparison)
  local installed
  installed=$("$cli_cmd" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

  while IFS= read -r ext || [[ -n "$ext" ]]; do
    # Skip blank lines and comments
    [[ -z "$ext" || "$ext" =~ ^[[:space:]]*# ]] && continue

    local ext_lower
    ext_lower=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')

    if printf '%s\n' "$installed" | grep -qx "$ext_lower"; then
      info "${ext} (already installed)"
    else
      info "Installing ${ext}..."
      "$cli_cmd" --install-extension "$ext" --force 2>/dev/null \
        || warn "Failed to install ${ext} — may require manual install"
    fi
  done < <(grep -v '^#' "$EXTENSIONS_FILE" | grep -v '^[[:space:]]*$')

  log "${label} extensions done."
}

install_extensions "cursor" "Cursor"
install_extensions "code" "VS Code"

echo ""
info "Remember: OrbStack must be downloaded and opened manually."
info "  Download: https://orbstack.dev"
info "  Shell integration (~/.orbstack/shell/init.zsh) is auto-created on first launch."
