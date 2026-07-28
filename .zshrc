# This is my zshrc. There are many like it, but this one is mine.

# plugins et al
export ZDOTDIR=$HOME/.config/zsh
source "$HOME/.config/zsh/zshrc"

# You *can* add stuff after this, but it wouldn't be nice.

# kitten ssh needs a real Kitty window (KITTY_PID + numeric KITTY_WINDOW_ID).
# Drop the alias over SSH, or in any non-Kitty terminal (e.g. cosmic-term sets
# KITTY_WINDOW_ID=cosmic-term only for graphics protocol advertising).
if [[ -n "$SSH_CONNECTION" || -z "$KITTY_PID" || "$KITTY_WINDOW_ID" != <-> ]]; then
  unalias ssh 2>/dev/null
fi

# opencode
export PATH=$HOME/.opencode/bin:$PATH

. "$HOME/.atuin/bin/env"

# Disable atuin's default key bindings so we can wire them manually below.
# This avoids conflicts with zsh-vi-mode and fzf bindings.
export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"

# Bind atuin search manually.
# Use the vi-mode-aware widgets when zsh-vi-mode is active; otherwise use the
# plain emacs-style widgets that atuin registers unconditionally.
#
# atuin-search        — open full search UI (replaces Ctrl-R)
# atuin-up-search     — prefix-aware up-arrow search (replaces ↑ / Ctrl-P)
#
# zsh-vi-mode calls zvm_after_init hooks after it has set up its own bindings,
# so we register our atuin binds there when vi-mode is loaded; otherwise we
# bind immediately.
_atuin_bind() {
  bindkey '^r'    atuin-search
  bindkey '^[[A'  atuin-up-search   # Up arrow (normal mode escape seq)
  bindkey '^[OA'  atuin-up-search   # Up arrow (application mode escape seq)
  bindkey '^p'    atuin-up-search   # Ctrl-P (vi-mode safe alternative)
}

if (( ${+functions[zvm_after_init_commands]} )); then
  # zsh-vi-mode is present — defer binding until after it finishes
  zvm_after_init_commands+=(_atuin_bind)
else
  _atuin_bind
fi

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
