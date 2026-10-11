#!/usr/bin/env bash
# =============================================================================
#  bootstrap.sh — Idempotent macOS dev environment setup
#
#  Usage:
#    bash bootstrap.sh            # full setup (safe to re-run any time)
#    bash bootstrap.sh --dry-run  # preview what would be done
#
#  Every step runs independently: a failure is recorded and reported in the
#  summary at the end instead of aborting the rest of the setup. Re-running
#  only does what's still missing.
#
#  Requires: macOS 15+, Apple Silicon
#  Repo: https://github.com/jcakstins/dev_setup
# =============================================================================
set -euo pipefail

# ── Colours / logging ─────────────────────────────────────────────────────────
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
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Keep a full log of every run
if ! $DRY_RUN; then
  LOG_DIR="${HOME}/Library/Logs/dev_setup"
  mkdir -p "$LOG_DIR"
  LOG_FILE="${LOG_DIR}/bootstrap-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
fi
$DRY_RUN && warn "Dry-run mode: no changes will be made"

run() {
  if $DRY_RUN; then
    info "[dry-run] $*"
  else
    "$@"
  fi
}

# retry <attempts> <cmd...> — for network operations
retry() {
  local attempts="$1"; shift
  local n=1
  until "$@"; do
    (( n >= attempts )) && return 1
    warn "Attempt ${n}/${attempts} failed: $* — retrying in $((n * 5))s"
    sleep $((n * 5))
    n=$((n + 1))
  done
}

# ── Step runner ───────────────────────────────────────────────────────────────
# Each step runs in a subshell with errexit on; its failure is recorded and the
# bootstrap carries on with the next step.
PASSED=()
FAILED=()

step() {
  local name="$1"; shift
  log "$name"
  set +e
  ( set -e; "$@" )
  local rc=$?
  set -e
  if (( rc == 0 )); then
    PASSED+=("$name")
  else
    warn "Step failed (exit ${rc}): ${name} — continuing"
    FAILED+=("$name")
  fi
}

# ── 0. Preflight (hard requirements — these do abort) ─────────────────────────
log "Preflight checks"

[[ "$(uname -s)" == "Darwin" ]] || die "This script is macOS-only."
[[ "$(uname -m)" == "arm64"  ]] || warn "Not running on Apple Silicon — paths may differ."
[[ "$EUID" -ne 0 ]] || die "Don't run as root — run as your user; sudo is requested when needed."

# Ask for the sudo password once up front and keep the ticket alive, so casks
# that need sudo (e.g. 1Password) don't fail halfway through an unattended run.
if ! $DRY_RUN; then
  if sudo -n true 2>/dev/null; then
    info "sudo: already authorised"
  elif [[ -t 0 ]]; then
    info "Some installs need admin rights — enter your password once:"
    sudo -v || die "sudo authorisation failed."
  else
    warn "No terminal for a sudo prompt — casks that need sudo may fail. Run bootstrap.sh from a terminal."
  fi
  if sudo -n true 2>/dev/null; then
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
  fi
fi

# Xcode Command Line Tools (required for Homebrew and git)
if ! xcode-select -p &>/dev/null; then
  log "Installing Xcode Command Line Tools (follow the system prompt)..."
  run xcode-select --install || true
  $DRY_RUN || until xcode-select -p &>/dev/null; do sleep 5; done
  info "Xcode CLT installed."
else
  info "Xcode CLT: $(xcode-select -p)"
fi

# Homebrew — everything else depends on it, so a failure here aborts
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW=/opt/homebrew/bin/brew
elif [[ -x /usr/local/bin/brew ]]; then
  BREW=/usr/local/bin/brew
else
  log "Installing Homebrew..."
  if $DRY_RUN; then
    info "[dry-run] install Homebrew"
    BREW=/opt/homebrew/bin/brew
  else
    NONINTERACTIVE=1 retry 3 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew install failed."
    BREW=/opt/homebrew/bin/brew
  fi
fi
[[ -x "$BREW" ]] && eval "$("$BREW" shellenv)"
brew_version="$("$BREW" --version 2>/dev/null || echo 'not installed (dry-run)')"
info "Homebrew: ${brew_version%%$'\n'*}"

# ── 1. Homebrew packages ──────────────────────────────────────────────────────
# Formulae that were replaced in the Brewfile and conflict with their successor
REPLACED_FORMULAE=(
  tfenv     # → tenv
  opentofu  # → tenv (provides `tofu`)
)

brew_packages() {
  run brew update --quiet || warn "brew update failed — continuing with current formulae"

  for f in "${REPLACED_FORMULAE[@]}"; do
    if brew list --formula "$f" &>/dev/null; then
      info "Removing ${f} (replaced in Brewfile)..."
      run brew uninstall --formula "$f"
    fi
  done

  info "Installing from Brewfile (already-installed packages are skipped)..."
  # Retry once: most bundle failures on a fresh machine are transient downloads
  retry 2 run brew bundle --file="${DOTFILES_DIR}/Brewfile"
}
step "Homebrew packages (Brewfile)" brew_packages

# ── 2. Symlink dotfiles ───────────────────────────────────────────────────────
symlink() {
  local src="$1" dst="$2"
  run mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    info "$(basename "$dst") already linked"
    return 0
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    local backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    warn "Backing up existing $(basename "$dst") → ${backup}"
    run mv "$dst" "$backup"
  fi
  run ln -s "$src" "$dst"
  info "$(basename "$dst") → $src"
}

dotfiles() {
  symlink "${DOTFILES_DIR}/zsh/.zshrc"            "${HOME}/.zshrc"
  symlink "${DOTFILES_DIR}/zsh/.zprofile"          "${HOME}/.zprofile"
  symlink "${DOTFILES_DIR}/git/.gitconfig"         "${HOME}/.gitconfig"
  symlink "${DOTFILES_DIR}/git/.gitignore_global"  "${HOME}/.gitignore_global"
  symlink "${DOTFILES_DIR}/kitty/kitty.conf"       "${HOME}/.config/kitty/kitty.conf"
  symlink "${DOTFILES_DIR}/starship/starship.toml" "${HOME}/.config/starship.toml"
  symlink "${DOTFILES_DIR}/tmux/.tmux.conf"        "${HOME}/.tmux.conf"
  symlink "${DOTFILES_DIR}/tmux/.tmux.conf.local"  "${HOME}/.tmux.conf.local"
}
step "Symlink dotfiles" dotfiles

# ── 3. Shell + tmux plugins ───────────────────────────────────────────────────
# clone_or_update <url> <dir> [extra clone args...]
# A failed update of an existing checkout only warns — the old copy still works.
clone_or_update() {
  local url="$1" dir="$2"; shift 2
  local name; name="$(basename "$dir")"
  if [[ -d "${dir}/.git" ]]; then
    info "${name} present — pulling latest..."
    run git -C "$dir" pull --ff-only --quiet \
      || warn "Could not update ${name} — keeping existing copy"
  else
    [[ -e "$dir" ]] && run rm -rf "$dir"   # leftover from an interrupted clone
    info "Cloning ${name}..."
    retry 3 run git clone --depth 1 --quiet "$@" "$url" "$dir"
  fi
}

plugins() {
  local zsh_dir="${HOME}/.zsh/plugins" tmux_dir="${HOME}/.tmux/plugins"
  run mkdir -p "$zsh_dir" "$tmux_dir"

  clone_or_update https://github.com/zsh-users/zsh-autosuggestions "${zsh_dir}/zsh-autosuggestions"
  clone_or_update https://github.com/jeffreytse/zsh-vi-mode        "${zsh_dir}/zsh-vi-mode"

  # Clone tmux plugins directly rather than via tpm's install_plugins.sh: that
  # script discovers @plugin lines by querying a *running* tmux server, which
  # this bootstrap doesn't start. tmux picks up already-cloned plugins on launch.
  clone_or_update https://github.com/tmux-plugins/tpm "${tmux_dir}/tpm"
  for plugin in tmux-resurrect tmux-continuum; do
    clone_or_update "https://github.com/tmux-plugins/${plugin}" "${tmux_dir}/${plugin}" \
      --single-branch --recursive
  done
}
step "Shell + tmux plugins" plugins

# ── 4. fzf shell integration ──────────────────────────────────────────────────
fzf_integration() {
  local fzf_install="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/install"
  if [[ -f "$fzf_install" ]]; then
    run "$fzf_install" --key-bindings --completion --no-update-rc --no-bash --no-fish
  else
    warn "fzf install script not found at ${fzf_install} — is fzf installed?"
    return 1
  fi
}
step "fzf shell integration" fzf_integration

# ── 5. Secrets file ───────────────────────────────────────────────────────────
secrets() {
  if [[ ! -f "${HOME}/.secrets" ]]; then
    info "Creating ~/.secrets from template..."
    run cp "${DOTFILES_DIR}/.secrets.example" "${HOME}/.secrets"
    run chmod 600 "${HOME}/.secrets"
    warn "Edit ~/.secrets to add your API keys and tokens."
  else
    info "~/.secrets already exists — not overwriting."
  fi
}
step "Secrets file" secrets

# ── 6–8. Sub-scripts ──────────────────────────────────────────────────────────
step "macOS defaults"    run bash "${DOTFILES_DIR}/install/macos.sh"
step "Dev tooling"       run bash "${DOTFILES_DIR}/install/dev.sh"
step "Editor extensions" run bash "${DOTFILES_DIR}/install/apps.sh"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
log "Summary"
for s in "${PASSED[@]+"${PASSED[@]}"}"; do printf "  ${GREEN}✔${RESET} %s\n" "$s"; done
for s in "${FAILED[@]+"${FAILED[@]}"}"; do printf "  ${RED}✘${RESET} %s\n" "$s"; done
[[ -n "${LOG_FILE:-}" ]] && info "Full log: ${LOG_FILE}"
echo ""

info "Next steps:"
info "  1. Open a new terminal (or: exec zsh) to load the new shell config"
info "  2. Sign in once: gh auth login · op signin · claude"
info "  3. Start Docker when needed: colima start (or at login: brew services start colima)"
info "  4. Add API keys to ~/.secrets"
echo ""

if (( ${#FAILED[@]} > 0 )); then
  printf "${RED}${BOLD}Bootstrap finished with ${#FAILED[@]} failed step(s).${RESET} Fix the issue above and re-run — completed work is skipped.\n"
  exit 1
fi
printf "${GREEN}${BOLD}Bootstrap complete!${RESET}\n"
