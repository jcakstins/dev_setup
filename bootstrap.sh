#!/usr/bin/env bash
# =============================================================================
#  bootstrap.sh — Idempotent macOS dev environment setup
#
#  Usage:
#    bash bootstrap.sh            # full setup
#    bash bootstrap.sh --dry-run  # preview what would be done
#
#  Requires: macOS 15+, Apple Silicon
#  Repo: https://github.com/jcakstins/dev_setup
# =============================================================================
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

log()  { printf "${GREEN}==>${RESET} ${BOLD}%s${RESET}\n" "$*"; }
info() { printf "${BLUE}   →${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}[warn]${RESET} %s\n" "$*"; }
die()  { printf "${RED}[error]${RESET} %s\n" "$*" >&2; exit 1; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true && warn "Dry-run mode: no changes will be made"

run() {
  if $DRY_RUN; then
    info "[dry-run] $*"
  else
    "$@"
  fi
}

# ── 0. Preflight ──────────────────────────────────────────────────────────────
log "Preflight checks"

[[ "$(uname -s)" == "Darwin" ]] || die "This script is macOS-only."
[[ "$(uname -m)" == "arm64"  ]] || warn "Not running on Apple Silicon — paths may differ."

# Ensure Xcode Command Line Tools (required for Homebrew and git)
if ! xcode-select -p &>/dev/null; then
  log "Installing Xcode Command Line Tools (follow the system prompt)..."
  run xcode-select --install
  until xcode-select -p &>/dev/null; do sleep 5; done
  info "Xcode CLT installed."
else
  info "Xcode CLT: $(xcode-select -p)"
fi

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
log "Homebrew"

if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  info "Homebrew $(brew --version | head -1) — running update..."
  run brew update --quiet
fi

# ── 2. Brew Bundle ────────────────────────────────────────────────────────────
log "Installing packages from Brewfile"
info "This may take a few minutes on a fresh machine..."

run brew bundle --file="${DOTFILES_DIR}/Brewfile"

# ── 3. Symlink dotfiles ───────────────────────────────────────────────────────
log "Symlinking dotfiles"

symlink() {
  local src="$1" dst="$2"
  run mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "Backing up existing $(basename "$dst") → ${dst}.bak"
    run mv "$dst" "${dst}.bak"
  fi
  run ln -sf "$src" "$dst"
  info "$(basename "$dst") → $src"
}

symlink "${DOTFILES_DIR}/zsh/.zshrc"            "${HOME}/.zshrc"
symlink "${DOTFILES_DIR}/zsh/.zprofile"          "${HOME}/.zprofile"
symlink "${DOTFILES_DIR}/git/.gitconfig"         "${HOME}/.gitconfig"
symlink "${DOTFILES_DIR}/git/.gitignore_global"  "${HOME}/.gitignore_global"
symlink "${DOTFILES_DIR}/kitty/kitty.conf"       "${HOME}/.config/kitty/kitty.conf"
symlink "${DOTFILES_DIR}/starship/starship.toml" "${HOME}/.config/starship.toml"

# Register global gitignore with git
run git config --global core.excludesfile "${HOME}/.gitignore_global"

# ── 4. Zsh plugins ────────────────────────────────────────────────────────────
log "Zsh plugins"

ZSH_PLUGINS_DIR="${HOME}/.zsh/plugins"
run mkdir -p "${ZSH_PLUGINS_DIR}"

if [[ ! -d "${ZSH_PLUGINS_DIR}/zsh-autosuggestions/.git" ]]; then
  info "Cloning zsh-autosuggestions..."
  run git clone --depth=1 \
    https://github.com/zsh-users/zsh-autosuggestions \
    "${ZSH_PLUGINS_DIR}/zsh-autosuggestions"
else
  info "zsh-autosuggestions present — pulling latest..."
  run git -C "${ZSH_PLUGINS_DIR}/zsh-autosuggestions" pull --ff-only --quiet
fi

if [[ ! -d "${ZSH_PLUGINS_DIR}/zsh-vi-mode/.git" ]]; then
  info "Cloning zsh-vi-mode..."
  run git clone --depth=1 \
    https://github.com/jeffreytse/zsh-vi-mode \
    "${ZSH_PLUGINS_DIR}/zsh-vi-mode"
else
  info "zsh-vi-mode present — pulling latest..."
  run git -C "${ZSH_PLUGINS_DIR}/zsh-vi-mode" pull --ff-only --quiet
fi

# ── 5. fzf shell integration ──────────────────────────────────────────────────
log "fzf shell integration"

FZF_INSTALL="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/install"
if [[ -f "$FZF_INSTALL" ]]; then
  run "$FZF_INSTALL" --key-bindings --completion --no-update-rc --no-bash --no-fish
  info "fzf key bindings and completions installed."
else
  warn "fzf install script not found at ${FZF_INSTALL} — skipping."
fi

# ── 6. Secrets file ───────────────────────────────────────────────────────────
log "Secrets"

if [[ ! -f "${HOME}/.secrets" ]]; then
  info "Creating ~/.secrets from template..."
  run cp "${DOTFILES_DIR}/.secrets.example" "${HOME}/.secrets"
  run chmod 600 "${HOME}/.secrets"
  warn "Edit ~/.secrets to add your API keys and tokens."
else
  info "~/.secrets already exists — not overwriting."
fi

# ── 7. macOS system defaults ──────────────────────────────────────────────────
log "macOS defaults"
run bash "${DOTFILES_DIR}/install/macos.sh"

# ── 8. Dev tooling ────────────────────────────────────────────────────────────
log "Dev tooling"
run bash "${DOTFILES_DIR}/install/dev.sh"

# ── 9. Editor extensions ──────────────────────────────────────────────────────
log "Editor extensions"
run bash "${DOTFILES_DIR}/install/apps.sh"

# ── 10. OrbStack notice ───────────────────────────────────────────────────────
echo ""
printf "${BOLD}${YELLOW}┌─────────────────────────────────────────────────────────────┐${RESET}\n"
printf "${BOLD}${YELLOW}│  MANUAL STEP: OrbStack (Docker + Linux VMs)                 │${RESET}\n"
printf "${BOLD}${YELLOW}├─────────────────────────────────────────────────────────────┤${RESET}\n"
printf "  ${BOLD}1.${RESET} Download from: ${BLUE}https://orbstack.dev${RESET}\n"
printf "  ${BOLD}2.${RESET} Open the app once to complete kernel extension setup.\n"
printf "  ${BOLD}3.${RESET} Shell integration is auto-created at ~/.orbstack/shell/init.zsh\n"
printf "  ${BOLD}4.${RESET} Your .zprofile already sources it (silently ignored until installed).\n"
printf "${BOLD}${YELLOW}└─────────────────────────────────────────────────────────────┘${RESET}\n"
echo ""

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}Bootstrap complete!${RESET}\n"
echo ""
info "Next steps:"
info "  1. Edit ~/.secrets with your API keys"
info "  2. Open a new terminal (or: source ~/.zshrc) to apply changes"
info "  3. Install OrbStack from https://orbstack.dev"
info "  4. For new Python projects: copy python/pyproject.toml.template"
info "  5. For pre-commit hooks: copy python/.pre-commit-config.yaml.template"
echo ""
