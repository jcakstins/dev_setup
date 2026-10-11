#!/usr/bin/env bash
# Generate zsh completions for tools that don't ship them. Runs on every apply
# but only creates missing files; delete ~/.zsh/completions/_<tool> to refresh.
set -euo pipefail
log()  { printf "\033[0;32m==>\033[0m %s\n" "$*"; }
info() { printf "\033[0;34m   →\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }

export PATH="/opt/homebrew/bin:$HOME/.local/share/mise/shims:$PATH"
DIR="$HOME/.zsh/completions"
mkdir -p "$DIR"

gen() {
  local name="$1"; shift
  [[ -f "$DIR/_$name" ]] && return 0
  command -v "$name" &>/dev/null || return 0
  info "Generating $name completions"
  "$@" > "$DIR/_$name.tmp" 2>/dev/null && mv "$DIR/_$name.tmp" "$DIR/_$name" \
    || { rm -f "$DIR/_$name.tmp"; warn "Could not generate $name completions"; }
}

gen kubectl kubectl completion zsh
gen gh      gh completion -s zsh
gen docker  docker completion zsh
gen colima  colima completion zsh
gen uv      uv generate-shell-completion zsh
gen mise    mise completion zsh
gen chezmoi chezmoi completion zsh
