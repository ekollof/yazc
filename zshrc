#!/bin/zsh
export ZDOTDIR=$HOME/.config/zsh

HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups


# some useful options (man zshoptions)
setopt autocd extendedglob nomatch menucomplete
setopt interactive_comments
stty stop undef		# Disable ctrl-s to freeze terminal.
zle_highlight=('paste:none')

# beeping is annoying
unsetopt BEEP

# Keep unique PATH entries
typeset -U path


# completions
autoload -Uz compinit
# Note: menu select is disabled to allow fzf-tab to work
# zstyle ':completion:*' menu select

zmodload zsh/complist
_comp_options+=(globdots)		# Include hidden files.

# History search keybindings — native zsh fallbacks.
# Atuin owns Ctrl-R and Up arrow (bound in .zshrc after atuin init).
# These provide prefix-search on Ctrl-P/Ctrl-N as a lightweight fallback
# in environments where atuin is absent.
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^N" down-line-or-beginning-search

# Colors
autoload -Uz colors && colors

# bat as MANPAGER (syntax-highlighted man pages) and LESSOPEN pipe
if command -v bat > /dev/null 2>&1; then
  export MANPAGER='sh -c "col -bx | bat -l man -p"'
  export MANROFFOPT='-c'
  export LESSOPEN='|bat --color=always --style=plain %s'
  export LESS='-R'
fi

# zsh-you-should-use: show alias reminder before the command runs
export YSU_MESSAGE_POSITION="before"

source "$ZDOTDIR/zsh-prompt"

# Zinit installation and setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Check for zinit updates once per day (non-blocking background fetch).
# The background job writes the upstream commit count to the stamp file.
# The notification is shown only in the same session that discovers updates,
# not in subsequent shells reading a potentially stale stamp.
() {
  local stamp="${XDG_CACHE_HOME:-$HOME/.cache}/zinit/update-check.stamp"
  command mkdir -p "${stamp:h}"
  # Kick off a background fetch if the stamp is older than 24 hours or missing
  if [[ ! -f $stamp ]] || [[ -n $stamp(#qN.mh+24) ]]; then
    (
      command git -C "$ZINIT_HOME" fetch --quiet 2>/dev/null
      local count
      count=$(command git -C "$ZINIT_HOME" rev-list --right-only --count HEAD...@'{u}' 2>/dev/null)
      # Only set the flag if there are actual updates; clear it otherwise
      if (( ${count:-0} > 0 )); then
        printf '%d' "$count" >| "$stamp"
      else
        printf '0' >| "$stamp"
      fi
    ) &!
  else
    # Stamp exists and is fresh — check if a previous fetch found updates
    local pending
    pending=$(<"$stamp" 2>/dev/null)
    if [[ "$pending" =~ ^[0-9]+$ ]] && (( pending > 0 )); then
      _zinit_update_precmd() {
        add-zsh-hook -d precmd _zinit_update_precmd
        unfunction _zinit_update_precmd
        print -P "\n%F{yellow}[zinit]%f updates available. Run %F{cyan}zinit-update%f to apply.\n"
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd _zinit_update_precmd
    fi
  fi
}

# Wrapper that updates zinit + plugins and marks the stamp as up to date.
# Writes 0 to the stamp immediately so no further sessions nag until the
# next daily fetch finds new commits.
zinit-update() {
  local stty_save
  stty_save=$(stty -g 2>/dev/null)
  zinit self-update && zinit update --all
  local ret=$?
  if [[ -n $stty_save ]]; then
    stty "$stty_save" 2>/dev/null
  else
    stty eof "^D" 2>/dev/null
  fi
  # Write 0 rather than deleting — avoids a race on next shell open where the
  # background fetch hasn't written the count yet and the shell reads empty/stale
  local stamp="${XDG_CACHE_HOME:-$HOME/.cache}/zinit/update-check.stamp"
  printf '0' >| "$stamp"
  print -P "\n%F{green}[zinit]%f up to date.\n"
  disown 2>/dev/null
  return $ret
}

# Load plugins with zinit
zinit light zsh-users/zsh-autosuggestions
zinit light hlissner/zsh-autopair

# vi mode with proper plugin (restores sane keybindings; must load before bindkey calls)
# zsh-vi-mode uses cursor-shape escape sequences that render as garbage on
# terminals without truecolor support (e.g. CDE's dtterm).
if [[ "$COLORTERM" == (truecolor|24bit) ]]; then
  zinit light jeffreytse/zsh-vi-mode
fi

# Additional completions
zinit light zsh-users/zsh-completions

# Useful OMZ plugins
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::extract

# Alias reminder
zinit light MichaelAquilina/zsh-you-should-use

# zsh-autosuggestions: Ctrl-F and End both accept the full suggestion
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(end-of-line vi-end-of-line autosuggest-accept)
ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=(forward-word vi-forward-word vi-forward-word-end vi-forward-blank-word vi-forward-blank-word-end forward-char vi-forward-char)
bindkey '^f' autosuggest-accept    # Ctrl-F: accept full suggestion
bindkey '^e' end-of-line           # Ctrl-E: move to end of line (standard)

# FZF must be loaded before fzf-tab 
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f $ZDOTDIR/completion/_fnm ] && fpath+="$ZDOTDIR/completion/"

# FZF configuration
export FZF_DEFAULT_COMMAND='rg --hidden --no-ignore-vcs -l ""'
export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --border
  --inline-info
  --preview-window=right:50%:wrap
  --color=fg:#d0d0d0,bg:#121212,hl:#5f87af
  --color=fg+:#d0d0d0,bg+:#262626,hl+:#5fd7ff
  --color=info:#afaf87,prompt:#d7005f,pointer:#af5fff
  --color=marker:#87ff00,spinner:#af5fff,header:#87afaf
  --bind='ctrl-/:toggle-preview'
  --bind='ctrl-a:select-all'
  --bind='ctrl-y:execute-silent(echo -n {+} | xclip -selection clipboard)'
"

# Use fd instead of find if available
command -v fd > /dev/null 2>&1 && export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# CTRL-T: Paste selected files/dirs
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="
  --preview '(bat --color=always --style=numbers --line-range=:500 {} 2> /dev/null || cat {} 2> /dev/null || tree -C {} 2> /dev/null) 2> /dev/null'
  --preview-window right:50%:wrap
"

# ALT-C: cd into selected directory
command -v fd > /dev/null 2>&1 && export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="
  --preview 'eza --tree --color=always --icons {} 2>/dev/null || tree -C {} | head -200'
  --preview-window right:50%:wrap
"

# Run compinit once after all fpath modifications
# Use cached dump file (re-generate once per day)
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# Load fzf-tab AFTER compinit
zinit light Aloxaf/fzf-tab

# fzf-tab configuration (must be set after fzf-tab is loaded)
# Make fzf-tab NOT follow FZF_DEFAULT_OPTS to avoid conflicts
zstyle ':fzf-tab:*' use-fzf-default-opts no
# Don't pre-fill fzf query with typed input or common prefix — always start empty
zstyle ':fzf-tab:*' query-string ''
# Disable sort for git checkout
zstyle ':completion:*:git-checkout:*' sort false
# Set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# Set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Configure keybindings for fzf-tab
# Use Right arrow for continuous completion instead of '/' (which conflicts with fzf filtering)
zstyle ':fzf-tab:*' continuous-trigger 'right'
zstyle ':fzf-tab:*' fzf-bindings 'right:execute-silent(echo {+})+abort'
# Make Enter accept selection and exit
zstyle ':fzf-tab:*' accept-line enter
# Enhanced preview with image support
zstyle ':fzf-tab:complete:*:*' fzf-preview '
  # fzf-tab sets $realpath = realdir + word for file completions (absolute path)
  # Fall back to $word (stripped) for non-file completions
  local file
  if [[ -n $realpath ]]; then
    file=$realpath
  else
    file=${(Q)word}
    file=${file## }
    file=${file%% }
  fi
  
  if [[ -f $file ]]; then
    local mime=$(file --brief --mime-type "$file" 2>/dev/null)
    case $mime in
      image/*)
        if command -v chafa > /dev/null 2>&1; then
          if [[ -n "$KITTY_WINDOW_ID" ]]; then
            # kitty graphics protocol via chafa: writes escape codes directly to
            # stdout, no /dev/tty handshake needed (works inside fzf preview panes)
            chafa -f kitty -s "${FZF_PREVIEW_COLUMNS:-80}x${FZF_PREVIEW_LINES:-24}" --animate=off "$file"
          else
            # Sixel fallback for other terminals (xterm, mlterm, etc.)
            chafa -f sixel -s "${FZF_PREVIEW_COLUMNS:-80}x${FZF_PREVIEW_LINES:-24}" --animate=off "$file"
          fi
        else
          echo "Image: $file"
          file --brief "$file"
        fi
        ;;
      *)
        if command -v bat > /dev/null 2>&1; then
          bat --color=always --style=numbers --line-range=:500 "$file"
        else
          cat "$file"
        fi
        ;;
    esac
  elif [[ -d $file ]]; then
    if command -v eza > /dev/null 2>&1; then
      eza -1 --color=always --icons "$file"
    else
      ls -1 --color=always "$file"
    fi
  else
    echo "$file"
  fi
'
# Preview window configuration with kitty protocol support
zstyle ':fzf-tab:*' fzf-flags --preview-window=right:50%:wrap --height=40%
# Switch between groups with < and >
zstyle ':fzf-tab:*' switch-group '<' '>'

# Syntax highlighting - MUST be loaded last for compatibility
zinit light zdharma-continuum/fast-syntax-highlighting

source "$ZDOTDIR/zsh-local"


