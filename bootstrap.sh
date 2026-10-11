#!/usr/bin/env bash
# =============================================================================
#  bootstrap.sh — Idempotent macOS dev environment setup
#
#  Usage:
#    bash bootstrap.sh            # full setup (safe to re-run any time)
#    bash bootstrap.sh --dry-run  # preview what would be done
#
#  Layers:
#    1. Homebrew + Brewfile   — apps and CLI tools         (this script)
#    2. chezmoi (home/)       — dotfiles, plugins, secrets file, macOS defaults,
#                               editor extensions, completions
#    3. mise                  — python, terraform, opentofu… (run by chezmoi)
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
# Packages that were replaced in the Brewfile; removed first because they
# conflict with (or shadow) their successors.
REPLACED_FORMULAE=(
  tfenv     # → mise
  opentofu  # → mise
  tenv      # → mise
)
REPLACED_CASKS=(
  terraform-linters/tap/tflint   # → mise
)

brew_packages() {
  run brew update --quiet || warn "brew update failed — continuing with current formulae"

  local f
  for f in "${REPLACED_FORMULAE[@]}"; do
    if brew list --formula "$f" &>/dev/null; then
      info "Removing ${f} (replaced in Brewfile)..."
      run brew uninstall --formula "$f" || warn "Could not remove ${f}"
    fi
  done
  for f in "${REPLACED_CASKS[@]}"; do
    if brew list --cask "${f##*/}" &>/dev/null; then
      info "Removing ${f} (replaced in Brewfile)..."
      run brew uninstall --cask "${f##*/}" || warn "Could not remove ${f}"
    fi
  done

  # Skip casks whose app was installed outside Homebrew (manual download, App
  # Store). Homebrew would try to "adopt" it, which macOS App Management
  # protection blocks even with sudo — and such apps self-update anyway.
  local skip=() cask app
  local installed_casks; installed_casks="$(brew list --cask 2>/dev/null || true)"
  while IFS= read -r cask; do
    [[ -z "$cask" ]] && continue
    grep -qx "${cask##*/}" <<<"$installed_casks" && continue
    while IFS= read -r app; do
      if [[ -n "$app" && -e "/Applications/${app}" ]]; then
        info "${cask}: /Applications/${app} already installed outside Homebrew — skipping"
        skip+=("$cask")
        break
      fi
    done < <(brew info --cask --json=v2 "$cask" 2>/dev/null \
               | jq -r '.casks[].artifacts[] | .app? // empty | .[] | strings' || true)
  done < <(brew bundle list --cask --file="${DOTFILES_DIR}/Brewfile" 2>/dev/null || true)
  export HOMEBREW_BUNDLE_CASK_SKIP="${skip[*]+"${skip[*]}"}"

  info "Installing from Brewfile (already-installed packages are skipped)..."
  # Retry once: most bundle failures on a fresh machine are transient downloads
  retry 2 run brew bundle --file="${DOTFILES_DIR}/Brewfile"
}
step "Homebrew packages (Brewfile)" brew_packages

# ── 2. Dotfiles + setup scripts (chezmoi) ─────────────────────────────────────
# Existing files that differ from the repo are copied to a timestamped backup
# directory before chezmoi overwrites them, so nothing is lost on a used Mac.
backup_conflicts() {
  local backup_dir="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)" n=0 line path
  while IFS= read -r line; do
    # status columns: [last-written vs actual][actual vs target]; 'M' in the
    # second column = an existing file that apply would change
    [[ "${line:1:1}" == "M" ]] || continue
    path="${line:3}"
    [[ -e "${HOME}/${path}" || -L "${HOME}/${path}" ]] || continue
    mkdir -p "${backup_dir}/$(dirname "$path")"
    cp -PR "${HOME}/${path}" "${backup_dir}/${path}"
    n=$((n + 1))
  done < <(chezmoi --source "$DOTFILES_DIR" status --exclude=scripts,externals 2>/dev/null || true)
  (( n > 0 )) && warn "Backed up ${n} existing file(s) to ${backup_dir}" || true
}

dotfiles() {
  command -v chezmoi &>/dev/null || { warn "chezmoi not installed — is it in the Brewfile?"; return 1; }

  # Generates ~/.config/chezmoi/chezmoi.toml (git email etc.) once
  if [[ ! -f "${HOME}/.config/chezmoi/chezmoi.toml" ]] && ! $DRY_RUN; then
    chezmoi init --source "$DOTFILES_DIR"
  fi

  if $DRY_RUN; then
    chezmoi --source "$DOTFILES_DIR" apply --dry-run --verbose || true
    return 0
  fi

  backup_conflicts
  # GitHub token (if gh is logged in) avoids API rate limits for mise downloads
  if [[ -z "${MISE_GITHUB_TOKEN:-}" ]] && gh auth token &>/dev/null; then
    export MISE_GITHUB_TOKEN="$(gh auth token)"
  fi
  chezmoi --source "$DOTFILES_DIR" apply --verbose
}
step "Dotfiles, plugins, tools (chezmoi + mise)" dotfiles

# ── 3. Verify ─────────────────────────────────────────────────────────────────
verify() {
  export PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${PATH}"
  local missing=() tool version
  for tool in git gh jq rg fd bat fzf zoxide starship tmux tmuxp sesh chezmoi mise uv \
              python terraform tofu tflint ruff http terraform-docs tilt kubectl \
              colima docker trufflehog pre-commit op claude; do
    if command -v "$tool" &>/dev/null; then
      case "$tool" in
        tmux)    version="$(tmux -V 2>&1 || true)" ;;
        kubectl) version="$(kubectl version --client 2>&1 || true)" ;;
        *)       version="$("$tool" --version 2>&1 || true)" ;;
      esac
      version="${version%%$'\n'*}"
      info "${tool}: ${version}"
    else
      warn "${tool}: NOT FOUND"
      missing+=("$tool")
    fi
  done
  (( ${#missing[@]} == 0 ))
}
$DRY_RUN || step "Verify tools" verify

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
info "  Edit dotfiles: chezmoi edit ~/.zshrc  ·  preview: chezmoi diff  ·  apply: chezmoi apply"
echo ""

if (( ${#FAILED[@]} > 0 )); then
  printf "${RED}${BOLD}Bootstrap finished with ${#FAILED[@]} failed step(s).${RESET} Fix the issue above and re-run — completed work is skipped.\n"
  exit 1
fi
printf "${GREEN}${BOLD}Bootstrap complete!${RESET}\n"
