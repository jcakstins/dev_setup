# =============================================================================
#  ~/.zshrc — interactive shell configuration
#  Part of dev_setup dotfiles: https://github.com/jcakstins/dev_setup
# =============================================================================

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt SHARE_HISTORY          # share history across all sessions in real time
setopt HIST_IGNORE_DUPS       # skip consecutive duplicates
setopt HIST_IGNORE_ALL_DUPS   # remove older duplicate entries anywhere in history
setopt HIST_SAVE_NO_DUPS      # don't write duplicates to the history file
setopt HIST_REDUCE_BLANKS     # trim superfluous whitespace in history
setopt HIST_VERIFY            # show expanded history command before executing

# ── Navigation & behaviour ────────────────────────────────────────────────────
setopt AUTO_CD                # type a directory name to cd into it
setopt CORRECT                # suggest corrections for mistyped commands
setopt INTERACTIVE_COMMENTS   # allow # comments in interactive shell
unsetopt BEEP                 # silence terminal bell

# ── Completion ────────────────────────────────────────────────────────────────
autoload -Uz compinit

_comp_cache_dir="${HOME}/.cache/zsh"
[[ -d "$_comp_cache_dir" ]] || mkdir -p "$_comp_cache_dir"

# Rebuild compdump at most once per day (fast path uses -C to skip security check)
_zcompdump="${_comp_cache_dir}/zcompdump"
if [[ ! -f "$_zcompdump" || -n "$(find "$_zcompdump" -mtime +1 2>/dev/null)" ]]; then
  compinit -d "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi
unset _zcompdump _comp_cache_dir

# Load custom completions (kubectl, terraform, etc.)
fpath=("${HOME}/.zsh/completions" $fpath)

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' cache-path "${HOME}/.cache/zsh/zcompcache"
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}No matches: %d%f'
zstyle ':completion:*' use-cache yes

# ── Keybindings ───────────────────────────────────────────────────────────────
# zsh-vi-mode overrides all bindings when sourced — do NOT set bindkey -v here.
# Emacs fallbacks (Ctrl+A, Ctrl+E, Ctrl+W) are preserved by zsh-vi-mode in INSERT mode.
export KEYTIMEOUT=1    # 10ms delay after Esc — snappy normal-mode entry

# ── Aliases ───────────────────────────────────────────────────────────────────

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Better defaults
alias ll='ls -lAhF'
alias la='ls -lAhF'
alias grep='grep --color=auto'
alias cat='bat --paging=never'    # bat as drop-in cat replacement
alias fcat='/bin/cat'             # escape hatch to real cat

# Git shortcuts
alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gpr='git pull --rebase'
alias gco='git checkout'
alias gbr='git branch -vv'

# Python / uv
alias py='python3'
alias venv='uv venv'
alias pipi='uv pip install'
alias pipu='uv pip install --upgrade'

# Terraform / tfenv
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tff='terraform fmt -recursive'
alias tfv='terraform validate'

# OpenTofu (mirrors terraform aliases)
alias tofu='opentofu'
alias otfi='opentofu init'
alias otfp='opentofu plan'
alias otfa='opentofu apply'

# Kubernetes
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kctx='kubectl config current-context'
alias kns='kubectl config set-context --current --namespace'

# Misc
alias reload='source ~/.zshrc'
alias dotfiles='cd ${HOME}/github/dev_setup'

# ── Environment variables ─────────────────────────────────────────────────────
export EDITOR='cursor --wait'
export VISUAL="$EDITOR"
export PAGER='less'
export LESS='-RFX'              # -R: colour, -F: quit if fits screen, -X: no clear

# bat theme
export BAT_THEME='TwoDark'

# fzf: use fd for file listing, preview with bat
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --border=rounded
  --preview 'bat --style=numbers --color=always --line-range :300 {}'
  --preview-window=right:50%:wrap
  --bind='ctrl-/:toggle-preview'
"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# ripgrep config file
export RIPGREP_CONFIG_PATH="${HOME}/.ripgreprc"

# uv: prefer uv-managed pythons for new projects
export UV_PYTHON_PREFERENCE="managed"

# terraform / tofu
export TF_CLI_ARGS_plan="-compact-warnings"
export CHECKPOINT_DISABLE=1     # disable Terraform version check phone-home

# ── Tool integrations ─────────────────────────────────────────────────────────

# zoxide — smarter cd (replaces 'cd' with z + keeps cd working)
eval "$(zoxide init zsh)"

# fzf — completion only here; key-bindings are re-sourced inside zvm_after_init
# (zsh-vi-mode overrides Ctrl+R; the hook restores fzf's Ctrl+R/T/Alt+C after zvm loads)
[[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]] && source /opt/homebrew/opt/fzf/shell/completion.zsh

# zsh-autosuggestions — inline history suggestions
# NOTE: sourced before zsh-vi-mode so zvm can wrap it properly
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#8a8a8a'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
[[ -f "${HOME}/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] \
  && source "${HOME}/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# zsh-vi-mode — proper vim bindings for the command line
# Must be sourced AFTER autosuggestions and BEFORE starship.
# It rewires INSERT/NORMAL/VISUAL modes, cursor shapes, and text objects.
#
# INSERT mode (default, where you type):
#   Option+←/→         word backward/forward  (via kitty send_text mappings)
#   Ctrl+A / Ctrl+E    line start/end (preserved from emacs mode)
#   Ctrl+W             delete word backward
#
# NORMAL mode (press Esc):
#   w / b              jump word forward/backward
#   0 / $              jump to start/end of line
#   d w / d b          delete word forward/backward
#   c w                change word (delete + enter insert)
#   / followed by text forward search in command history
#   n / N              next/previous match
#   u                  undo
#   Ctrl+R             redo
#   v                  open command in $EDITOR (full vim, for long commands)
#
# VISUAL mode (press v in normal mode):
#   v w / v b          select word forward/backward
#   d / y / c          delete/yank/change selection
ZVM_VI_INSERT_ESCAPE_BINDKEY=jk   # type 'jk' quickly to exit insert mode (no hand movement)
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT  # always start in insert mode (normal shell behaviour)
ZVM_CURSOR_STYLE_ENABLED=true        # block cursor in normal, beam cursor in insert

# Re-bind fzf inside zvm's after-init hook so fzf Ctrl+R/Ctrl+T/Alt+C survive
zvm_after_init() {
  [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]] && source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
}

[[ -f "${HOME}/.zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]] \
  && source "${HOME}/.zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh"

# ── Functions ─────────────────────────────────────────────────────────────────

# mkcd: create directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# fcd: fuzzy-find and cd into a directory
fcd() {
  local dir
  dir=$(fd --type d --hidden --exclude .git | fzf --height=40% --reverse) && cd "$dir"
}

# ffile: fuzzy-find a file and open in editor
ffile() {
  local file
  file=$(fzf --height=40% --reverse) && ${EDITOR:-cursor} "$file"
}

# gignore: append a pattern to the nearest .gitignore
gignore() { printf '%s\n' "$@" >> "$(git rev-parse --show-toplevel 2>/dev/null || echo .)/.gitignore"; }

# tfws: switch terraform workspace via fzf
tfws() {
  local ws
  ws=$(terraform workspace list | sed 's/^[* ]*//' | fzf --height=20% --reverse --prompt="workspace> ")
  [[ -n "$ws" ]] && terraform workspace select "$ws"
}

# uvinit: start a new uv project with standard dev deps
uvinit() {
  local name="${1:?usage: uvinit <project-name>}"
  uv init "$name" && cd "$name"
  uv add --dev ruff mypy pytest pytest-asyncio pytest-cov pre-commit
  echo "Project '$name' created. Edit pyproject.toml, then: uv sync"
}

# ── Bun ───────────────────────────────────────────────────────────────────────
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"   # bun completions

# ── Terraform completions ─────────────────────────────────────────────────────
autoload -U +X bashcompinit && bashcompinit
[[ -x "$(command -v terraform)" ]] && complete -o nospace -C "$(command -v terraform)" terraform

# ── Secrets ───────────────────────────────────────────────────────────────────
# API keys and tokens live outside the repo. Never commit ~/.secrets.
# Template: ~/github/dev_setup/.secrets.example
[[ -f "${HOME}/.secrets" ]] && source "${HOME}/.secrets"

# ── Starship prompt ───────────────────────────────────────────────────────────
# Must be last — needs final PATH state to find binaries for prompt modules
eval "$(starship init zsh)"
