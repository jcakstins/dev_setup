# =============================================================================
#  ~/.zprofile — login shell configuration (sources once per login session)
#  Applies to: login shells (new terminal windows, SSH sessions)
#  Does NOT apply to: sub-shells, scripts, tmux panes (those get .zshrc only)
# =============================================================================

# ── Homebrew ──────────────────────────────────────────────────────────────────
# Must be first — sets HOMEBREW_PREFIX and adjusts PATH/MANPATH/INFOPATH
eval "$(/opt/homebrew/bin/brew shellenv)"

# ── Python ────────────────────────────────────────────────────────────────────
# Interpreters are managed by uv: `uv python install --default 3.13` puts
# python/python3 into ~/.local/bin, alongside uv tools (e.g. `uv tool install ruff`)
export PATH="${HOME}/.local/bin:${HOME}/bin:$PATH"

# ── PATH deduplication ────────────────────────────────────────────────────────
# Zsh-native deduplication — removes duplicate entries from PATH silently
typeset -U PATH
