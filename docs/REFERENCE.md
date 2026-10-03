# Dev Setup Reference

Personal developer environment cheat sheet. Keep this open on a second monitor while getting used to the setup.

**Official docs** (bookmark these):
- [Kitty](https://sw.kovidgoyal.net/kitty/) · [Kitty keyboard shortcuts](https://sw.kovidgoyal.net/kitty/overview/#keyboard-shortcuts)
- [Neovim](https://neovim.io/doc/) · [Vim cheat sheet](https://vim.rtorr.com/)
- [Starship](https://starship.rs/config/) · [zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode)
- [fzf](https://github.com/junegunn/fzf) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [uv](https://docs.astral.sh/uv/)
- [tfenv](https://github.com/tfutils/tfenv) · [pre-commit](https://pre-commit.com/)
- [tmux](https://github.com/tmux/tmux/wiki) · [Oh my tmux!](https://github.com/gpakosz/.tmux) · [sesh](https://github.com/joshmedeski/sesh) · [tmuxp](https://tmuxp.git-pull.com/)

---

## Terminal — Kitty

### What's configured
| Setting | Value |
|---------|-------|
| Font | JetBrainsMono Nerd Font 13pt |
| Theme | Idle Toes (dark) |
| Prompt | Starship (git branch, python version, terraform workspace, k8s context) |
| Option key | Acts as Alt (word navigation works) |

### Splits & tabs
| Key | Action |
|-----|--------|
| `Cmd+D` | Split vertically (new pane right) |
| `Cmd+Shift+D` | Split horizontally (new pane below) |
| `Cmd+T` | New tab |
| `Cmd+W` | Close tab |
| `Cmd+1`–`5` | Switch to tab 1–5 |
| `Cmd+Shift+]` / `[` | Next / previous pane |
| `Ctrl+H/J/K/L` | Move between panes (vim-kitty-navigator) |

### Font size
| Key | Action |
|-----|--------|
| `Cmd+=` | Increase font size |
| `Cmd+-` | Decrease font size |
| `Cmd+0` | Reset font size |

### Scrollback
| Key | Action |
|-----|--------|
| `Cmd+↑` / `↓` | Scroll page up / down |
| `Cmd+Home` / `End` | Scroll to top / bottom |

> **Official docs:** https://sw.kovidgoyal.net/kitty/overview/#keyboard-shortcuts

---

## tmux — sessions on top of kitty

tmux here is scoped to one job: **sessions that survive**. Kitty still owns pane splits
(`Cmd+D`), pane navigation (`Ctrl+HJKL`) and tabs (`Cmd+T`, `Cmd+1`-`5`) — don't look for
tmux equivalents of those, they'd just be a second system to remember. What tmux adds is
a session you can detach from and reattach to later (even after closing the kitty window,
restarting your laptop, or a kitty crash), with tmux-resurrect/continuum auto-saving so
your panes and working directories come back.

The config is [Oh my tmux!](https://github.com/gpakosz/.tmux); customizations live in
`.tmux.conf.local` (never edit `.tmux.conf` directly — see its comment at the top).

### Starting out
| Command | Action |
|---------|--------|
| `tmux` | Start a new (unnamed) session |
| `tmux new -s work` | Start a new session named "work" |
| `tmux ls` or `tls` | List sessions |
| `tmux attach` or `tma` | Attach to the last session (creates "main" if none exist) |
| `tm` | Open the sesh fzf picker — works even before any tmux session exists |
| `exit` or `Ctrl+D` | Kill the current pane (kills the session if it's the last pane) |

### The prefix key
Every tmux command (except the few bound outside the prefix table) starts with the
**prefix**, here set to **`Ctrl+a`**. Press it, release, then press the command key —
it's not held together. `send-keys` note: because `Ctrl+a` is also zsh/readline's
"jump to start of line", that specific binding is shadowed while tmux is focused; use
NORMAL-mode `0` (zsh-vi-mode) instead, or press prefix then `a` to send a literal `Ctrl+a`
to the shell.

### Session management (the part worth learning first)
| Key | Action |
|-----|--------|
| `prefix d` | Detach from the session (keeps running in the background) |
| `prefix T` | Open the [sesh](https://github.com/joshmedeski/sesh) picker — fuzzy-switch between tmux sessions, zoxide dirs, and `sesh.toml` project configs |
| `prefix L` | Jump back to the previously-attached session |
| `prefix $` | Rename the current session |
| `prefix s` | List and switch sessions (built-in tmux picker, no fzf) |
| `prefix (` / `)` | Previous / next session |

### Windows (tmux's own "tabs" — independent of kitty's)
| Key | Action |
|-----|--------|
| `prefix c` | New window |
| `prefix ,` | Rename current window |
| `prefix Ctrl+h` / `Ctrl+l` | Previous / next window (repeatable — hold `Ctrl`, tap `h`/`l`) |
| `prefix 0`-`9` | Jump to window by number |
| `prefix w` | List and switch windows (tree view) |
| `prefix &` | Kill current window (asks to confirm) |

### Copy mode (vi keys, since `mode-keys vi` is set)
| Key | Action |
|-----|--------|
| `prefix [` | Enter copy mode (scroll + select) |
| `h j k l` | Move (same as vim) |
| `v` | Start selection |
| `y` | Yank selection and exit copy mode |
| `q` or `Esc` | Exit copy mode without copying |
| `prefix ]` | Paste what you last yanked |

### Session persistence (tmux-resurrect + tmux-continuum)
Continuum auto-saves every 15 minutes and auto-restores on tmux launch — this is the
part that matters for "I closed my laptop and want everything back."
| Key | Action |
|-----|--------|
| `prefix Ctrl+s` | Manually save now (resurrect) |
| `prefix Ctrl+r` | Manually restore the last save |

### Plugins (TPM)
| Key | Action |
|-----|--------|
| `prefix I` | Install any new `@plugin` lines added to `.tmux.conf.local` |
| `prefix u` | Update installed plugins |

### sesh and tmuxp — the two session tools, and when to use which
- **sesh** — fast, zoxide-aware *switching*. No config needed; `prefix T` or `tm` gets
  you from "a directory I visited recently" to "an attached tmux session" in one fuzzy
  search. Optionally define a `sesh.toml` in a project for startup commands/window
  layout: see https://github.com/joshmedeski/sesh#readme.
- **tmuxp** — declarative *layouts* from a YAML file (which windows, which panes, which
  command runs in each, checked into a repo so a teammate gets the same layout). Use it
  when a project's dev setup is "always these 3 panes running these 3 things":
  ```bash
  tmuxp freeze work        # capture your current session's layout to YAML
  tmuxp load work.yaml     # recreate it later, anywhere
  ```
  Docs: https://tmuxp.git-pull.com/

> **Official docs:** https://github.com/tmux/tmux/wiki · https://github.com/gpakosz/.tmux#readme

---

## Shell — Zsh vi mode

Your shell has full vim keybindings via `zsh-vi-mode`. Every prompt starts in **INSERT mode** (normal typing). Press `Esc` or `jk` quickly to enter **NORMAL mode**.

The cursor shape tells you which mode you're in: **beam** = insert, **block** = normal.

### INSERT mode (default — just type)
| Key | Action |
|-----|--------|
| `Option+←` / `→` | Jump word backward / forward |
| `Option+Backspace` | Delete word backward |
| `Option+Delete` | Delete word forward |
| `Cmd+←` / `→` | Jump to start / end of line |
| `Cmd+Backspace` | Delete to start of line |
| `Ctrl+A` / `E` | Start / end of line |
| `Ctrl+W` | Delete word backward |
| `Ctrl+R` | Fuzzy search history (fzf) |
| `Esc` or `jk` | → NORMAL mode |

### NORMAL mode (press Esc or jk)
| Key | Action |
|-----|--------|
| `w` / `b` | Jump word forward / backward |
| `0` / `$` | Start / end of line |
| `i` / `a` | → INSERT mode (before / after cursor) |
| `A` | → INSERT mode at end of line |
| `I` | → INSERT mode at start of line |
| `x` | Delete character under cursor |
| `dw` / `db` | Delete word forward / backward |
| `dd` | Delete entire line |
| `D` | Delete to end of line |
| `cw` | Change word (delete + insert) |
| `cc` | Change entire line |
| `u` | Undo |
| `Ctrl+R` | Redo |
| `v` | Open current command in `$EDITOR` (cursor) |
| `/` | Search command history forward |
| `n` / `N` | Next / previous history match |
| `Enter` | Execute command |

### VISUAL mode (press `v` in normal mode)
| Key | Action |
|-----|--------|
| `w` / `b` | Extend selection word forward / backward |
| `d` | Delete selection |
| `y` | Yank (copy) selection |
| `c` | Change selection (delete + insert) |

> **Tip:** The most used workflow: type command → `Esc` → navigate/edit → `Enter`
> **Official docs:** https://github.com/jeffreytse/zsh-vi-mode#-usage

---

## Shell — Aliases & functions

### Navigation
| Alias | Expands to |
|-------|-----------|
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `dotfiles` | `cd ~/github/dev_setup` |
| `reload` | `source ~/.zshrc` |

### Smart tools (replacements)
| Alias | What it does |
|-------|-------------|
| `cat` | `bat` — syntax-highlighted cat |
| `fcat` | real `/bin/cat` (escape hatch) |

### Git
| Alias | Command |
|-------|---------|
| `g` | `git` |
| `gs` | `git status -sb` |
| `gl` | `git log --oneline --graph -20` |
| `gd` / `gds` | `git diff` / `git diff --staged` |
| `ga` | `git add` |
| `gc` | `git commit` |
| `gp` | `git push` |
| `gpr` | `git pull --rebase` |
| `gco` | `git checkout` |

### Git config aliases (use with `git`)
| Alias | Command |
|-------|---------|
| `git st` | `git status -sb` |
| `git lg` | log graph (all branches) |
| `git new <branch>` | `git switch -c <branch>` |
| `git unstage <file>` | `git restore --staged <file>` |
| `git undo` | undo last commit (keep changes) |

### Python / uv
| Alias / function | What it does |
|-----------------|-------------|
| `py` | `python3` |
| `venv` | `uv venv` — create virtual environment |
| `pipi <pkg>` | `uv pip install <pkg>` |
| `uvinit <name>` | Create new uv project with ruff/mypy/pytest |

### Terraform
| Alias | Command |
|-------|---------|
| `tf` | `terraform` |
| `tfi` / `tfp` / `tfa` | init / plan / apply |
| `tff` | `terraform fmt -recursive` |
| `tfws` | fuzzy-switch terraform workspace |

### Kubernetes
| Alias | Command |
|-------|---------|
| `k` | `kubectl` |
| `kgp` / `kgs` / `kgn` | get pods / services / nodes |
| `kctx` | current context |
| `kns <ns>` | set namespace for current context |

### Functions
| Function | Usage |
|----------|-------|
| `mkcd <dir>` | Create directory and cd into it |
| `fcd` | Fuzzy-find a directory and cd into it |
| `ffile` | Fuzzy-find a file and open in editor |
| `gignore <pattern>` | Append pattern to nearest `.gitignore` |
| `tfws` | Fuzzy-select terraform workspace |
| `uvinit <name>` | Scaffold new Python project with uv |

---

## fzf — Fuzzy finder

fzf is wired into your shell. Anywhere you'd type a path or command, you can fuzz instead.

| Key | Action |
|-----|--------|
| `Ctrl+R` | Fuzzy search shell history |
| `Ctrl+T` | Fuzzy insert file path at cursor |
| `Alt+C` | Fuzzy cd into a directory |
| In fzf: `Ctrl+/` | Toggle preview pane |
| In fzf: `↑`/`↓` | Navigate results |
| In fzf: `Enter` | Select |
| In fzf: `Esc` | Cancel |

Preview pane shows file contents with syntax highlighting (bat).

> **Official docs:** https://github.com/junegunn/fzf#key-bindings-for-shell

---

## zoxide — Smart cd

`zoxide` learns which directories you visit and lets you jump to them by partial name.

| Command | Action |
|---------|--------|
| `cd projects/myapp` | Normal cd (also teaches zoxide) |
| `z myapp` | Jump to most-frecent dir matching "myapp" |
| `z my app` | Match multiple terms |
| `zi` | Interactive fuzzy selection (uses fzf) |

> **Official docs:** https://github.com/ajeetdsouza/zoxide#usage

---

## Python — uv workflow

`uv` replaces pip + venv + pip-tools. All projects use `pyproject.toml`.

### Starting a new project
```bash
uvinit my-service          # scaffold with ruff/mypy/pytest already added
cd my-service
uv add fastapi uvicorn     # add dependencies
uv add --dev pytest-asyncio  # add dev dependency
uv sync                    # install everything
uv run python src/main.py  # run without activating venv
```

### Day-to-day
| Command | Action |
|---------|--------|
| `uv sync` | Install all deps from uv.lock |
| `uv add <pkg>` | Add dependency |
| `uv add --dev <pkg>` | Add dev dependency |
| `uv run <cmd>` | Run command in project venv |
| `uv run pytest` | Run tests |
| `uv run ruff check .` | Lint |
| `uv run ruff format .` | Format |
| `uv run mypy` | Type check |
| `uv tool list` | Show globally installed tools |

### Copying templates for new projects
```bash
cp ~/github/dev_setup/python/pyproject.toml.template ./pyproject.toml
cp ~/github/dev_setup/python/.pre-commit-config.yaml.template ./.pre-commit-config.yaml
# Replace PROJECT_NAME and PACKAGE_NAME, then:
uv sync
pre-commit install
```

> **Official docs:** https://docs.astral.sh/uv/

---

## Terraform — tfenv

`tfenv` manages multiple terraform versions. Use a `.terraform-version` file per project.

| Command | Action |
|---------|--------|
| `tfenv list` | Show installed versions |
| `tfenv list-remote` | Show available versions |
| `tfenv install 1.9.0` | Install specific version |
| `tfenv install latest` | Install latest stable |
| `tfenv use 1.9.0` | Switch active version |
| `echo "1.9.0" > .terraform-version` | Pin version for this project |

> **Tip:** Drop a `.terraform-version` file in each project root. tfenv picks it up automatically.

---

## Git config highlights

Your `.gitconfig` has these non-obvious settings active:

| Setting | Effect |
|---------|--------|
| `pull.rebase = true` | `git pull` always rebases instead of merging |
| `push.autoSetupRemote = true` | First push sets upstream automatically (no `--set-upstream` needed) |
| `fetch.prune = true` | Remote-deleted branches disappear locally after fetch |
| `diff.algorithm = histogram` | Better diffs for code (fewer spurious hunks) |
| `merge.conflictstyle = zdiff3` | Conflict markers show the common ancestor (easier to resolve) |
| SSH rewrite | All `https://github.com/` URLs automatically use SSH |

---

## Starship prompt — what it shows

```
~/github/my-project  main !2 +1   v3.13.1   1 dev  ❯
│                    │     │   │  │          │       │
│                    │     │   │  │          │       └─ prompt char (green=ok, red=error)
│                    │     │   │  │          └─ terraform workspace (in .tf dirs)
│                    │     │   │  └─ python version (in python projects)
│                    │     │   └─ staged files
│                    │     └─ modified files
│                    └─ git branch
└─ directory (truncated to 3 levels, repo-aware)
```

Command duration shows for anything over 2 seconds. Kubernetes context appears when KUBECONFIG is set.

> **Official docs:** https://starship.rs/config/

---

## vim-kitty-navigator

Seamless navigation between kitty panes and nvim splits with the same keys.

| Key | Action |
|-----|--------|
| `Ctrl+H` | Move focus left |
| `Ctrl+J` | Move focus down |
| `Ctrl+K` | Move focus up |
| `Ctrl+L` | Move focus right |

Works transparently: if you're in a plain shell pane, kitty handles it. If you're in nvim, the nvim plugin handles it and jumps to the kitty pane when you hit the edge.

**To enable in nvim** (when you get there):
```lua
-- lazy.nvim
{ "knubie/vim-kitty-navigator" }
```

> **Plugin:** https://github.com/knubie/vim-kitty-navigator

---

## Neovim — getting started

> nvim runs inside kitty. Open a file with `nvim somefile.py`.
> Your `zsh-vi-mode` training transfers directly — same keys.

### Essential vim motions (start here)
| Key | Action |
|-----|--------|
| `h` `j` `k` `l` | ← ↓ ↑ → |
| `w` / `b` | Word forward / backward |
| `e` | End of word |
| `0` / `$` | Start / end of line |
| `gg` / `G` | Top / bottom of file |
| `Ctrl+D` / `U` | Half page down / up |

### Editing
| Key | Action |
|-----|--------|
| `i` / `a` | Insert before / after cursor |
| `o` / `O` | New line below / above |
| `dd` | Delete line |
| `yy` | Yank (copy) line |
| `p` / `P` | Paste below / above |
| `u` / `Ctrl+R` | Undo / redo |
| `.` | Repeat last change |
| `ci"` | Change inside quotes |
| `da(` | Delete including parentheses |

### Files & buffers
| Key | Action |
|-----|--------|
| `:w` | Save |
| `:q` | Quit |
| `:wq` or `ZZ` | Save and quit |
| `:q!` | Quit without saving |
| `:e <file>` | Open file |

### Search
| Key | Action |
|-----|--------|
| `/pattern` | Search forward |
| `?pattern` | Search backward |
| `n` / `N` | Next / previous match |
| `*` | Search word under cursor |
| `:%s/old/new/g` | Replace all in file |

> **Interactive tutorial:** run `vimtutor` in your terminal (30 min, highly recommended)
> **Reference:** https://vim.rtorr.com/
> **Official docs:** https://neovim.io/doc/

---

## Secrets & API keys

Your API keys live in `~/.secrets` (gitignored, sourced by `.zshrc`).

```bash
# Edit keys
cursor ~/.secrets

# Template is at:
cat ~/github/dev_setup/.secrets.example
```

Never commit `.secrets`. The `.gitignore_global` blocks it globally across all repos.
