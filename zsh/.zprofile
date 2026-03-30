# =============================================================================
#  ~/.zprofile — login shell configuration (sources once per login session)
#  Applies to: login shells (new terminal windows, SSH sessions)
#  Does NOT apply to: sub-shells, scripts, tmux panes (those get .zshrc only)
# =============================================================================

# ── Homebrew ──────────────────────────────────────────────────────────────────
# Must be first — sets HOMEBREW_PREFIX and adjusts PATH/MANPATH/INFOPATH
eval "$(/opt/homebrew/bin/brew shellenv)"

# ── Python ────────────────────────────────────────────────────────────────────
# Expose unversioned python/pip/pydoc symlinks from Homebrew Python 3.13
# This means `python` and `pip` point to 3.13 without needing pyenv or aliases.
export PATH="$(brew --prefix)/opt/python@3.13/libexec/bin:$PATH"

# uv installs tools into ~/.local/bin (e.g. `uv tool install ruff`)
export PATH="${HOME}/.local/bin:${HOME}/bin:$PATH"

# ── PATH deduplication ────────────────────────────────────────────────────────
# Zsh-native deduplication — removes duplicate entries from PATH silently
typeset -U PATH

# ── OrbStack ──────────────────────────────────────────────────────────────────
# OrbStack shell integration: adds docker, kubectl, and Linux VM tools to PATH.
# This file is created automatically when you first open OrbStack.app.
# Silently ignored if OrbStack is not yet installed.
source "${HOME}/.orbstack/shell/init.zsh" 2>/dev/null || true
