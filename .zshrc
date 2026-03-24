# This is my zshrc. There are many like it, but this one is mine.

# plugins et al
export ZDOTDIR=$HOME/.config/zsh
source "$HOME/.config/zsh/zshrc"

# You *can* add stuff after this, but it wouldn't be nice.

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
