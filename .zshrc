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

# atuin — prefer a system-wide binary; fall back to cargo-dist in ~/.atuin/bin.
# Never source ~/.atuin/bin/env when a package exists: that prepends ~/.atuin/bin
# to PATH, shadows /usr/bin/atuin, and previously delayed every command by ~4s
# while waiting on a dead daemon socket.
#
# Disable default key bindings so we can wire them manually below (avoids
# conflicts with zsh-vi-mode and fzf).
_atuin_cmd=
for _c in /usr/bin/atuin /bin/atuin /usr/local/bin/atuin; do
  if [[ -x $_c ]]; then
    _atuin_cmd=$_c
    break
  fi
done
if [[ -z $_atuin_cmd ]]; then
  # Non-home atuin already on PATH (Homebrew, Nix, asdf, etc.)
  if (( $+commands[atuin] )) && [[ ${commands[atuin]} != $HOME/* ]]; then
    _atuin_cmd=${commands[atuin]}
  elif [[ -x $HOME/.atuin/bin/atuin ]]; then
    _atuin_cmd=$HOME/.atuin/bin/atuin
    # Only put the home install on PATH when it is the only option
    path=($HOME/.atuin/bin $path)
  elif (( $+commands[atuin] )); then
    _atuin_cmd=${commands[atuin]}
  fi
fi

if [[ -n $_atuin_cmd ]]; then
  export ATUIN_NOBIND="true"
  eval "$("$_atuin_cmd" init zsh)"

  # atuin init prepends an "atuin" autosuggest strategy that shells out
  # (and talks to the daemon) on every keystroke. That can block on a
  # sqlite/daemon lock while `history end` is still running.
  ZSH_AUTOSUGGEST_STRATEGY=(history)

  # `history end` is launched with `&`, so zsh tracks it as a job. Disown
  # so a slow write cannot intercept ^D / CHECK_JOBS.
  # functions[] pretty-prints as `2>&1 &\n)` rather than `2>&1 &)`, and
  # canonicalises `&!` to `&|` after the assignment.
  if (( $+functions[_atuin_precmd] )) && [[ ${functions[_atuin_precmd]} != *'&|'* && ${functions[_atuin_precmd]} != *'&!'* ]]; then
    functions[_atuin_precmd]="${functions[_atuin_precmd]//2>&1 &/2>&1 &!}"
  fi
  if (( $+functions[_atuin_zshaddhistory] )) && [[ ${functions[_atuin_zshaddhistory]} != *'&|'* && ${functions[_atuin_zshaddhistory]} != *'&!'* ]]; then
    functions[_atuin_zshaddhistory]="${functions[_atuin_zshaddhistory]//2>&1 &/2>&1 &!}"
  fi

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

  # zvm_after_init_commands is an array, not a function.
  if (( ${+zvm_after_init_commands} )); then
    zvm_after_init_commands+=(_atuin_bind)
  else
    _atuin_bind
  fi
fi
unset _atuin_cmd _c

# viins default for ^D is list-choices. With fzf-tab + carapace that can
# stall for a long time on an empty line (looks like a hang). Use emacs
# EOF behaviour: delete a char, or exit the shell on an empty buffer.
_bind_ctrl_d_eof() {
  bindkey '^D' delete-char-or-list
  bindkey -M emacs '^D' delete-char-or-list 2>/dev/null
  bindkey -M viins '^D' delete-char-or-list 2>/dev/null
  bindkey -M vicmd '^D' delete-char-or-list 2>/dev/null
  if (( $+functions[zvm_bindkey] )); then
    zvm_bindkey emacs '^D' delete-char-or-list
    zvm_bindkey viins '^D' delete-char-or-list
    zvm_bindkey vicmd '^D' delete-char-or-list
  fi
}
if (( ${+zvm_after_init_commands} )); then
  zvm_after_init_commands+=(_bind_ctrl_d_eof)
else
  _bind_ctrl_d_eof
fi

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<

# Added by ProtonUp-Qt on 19-08-2026 23:30:11
if [ -d "/home/andrath/stl/prefix" ]; then export PATH="$PATH:/home/andrath/stl/prefix"; fi
