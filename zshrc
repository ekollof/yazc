#!/bin/zsh
export ZDOTDIR=$HOME/.config/zsh

HISTSIZE=5000
SAVEHIST=5000
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

# History search keybindings
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
bindkey "^P" up-line-or-beginning-search
bindkey "^N" down-line-or-beginning-search

# Colors
autoload -Uz colors && colors

source "$ZDOTDIR/zsh-prompt"

# Zinit installation and setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Load plugins with zinit
zinit light zsh-users/zsh-autosuggestions
zinit light hlissner/zsh-autopair
zinit light joshskidmore/zsh-fzf-history-search

# Additional completions
zinit light zsh-users/zsh-completions

# Useful OMZ plugins
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::extract

# Alias reminder
zinit light MichaelAquilina/zsh-you-should-use

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
  --preview 'tree -C {} | head -200'
  --preview-window right:50%:wrap
"

# CTRL-R: command history with preview
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window down:3:wrap
  --bind 'ctrl-y:execute-silent(echo -n {2..} | xclip -selection clipboard)+abort'
"

# Override zsh-fzf-history-search to never pre-fill the fzf query with $BUFFER
fzf_history_search() {
  setopt extendedglob

  FC_ARGS="-l"
  CANDIDATE_LEADING_FIELDS=2

  if (( ! $ZSH_FZF_HISTORY_SEARCH_EVENT_NUMBERS )); then
    FC_ARGS+=" -n"
    ((CANDIDATE_LEADING_FIELDS--))
  fi

  if (( $ZSH_FZF_HISTORY_SEARCH_DATES_IN_SEARCH )); then
    FC_ARGS+=" -i"
    ((CANDIDATE_LEADING_FIELDS+=2))
  fi

  local history_cmd="fc ${=FC_ARGS} -1 0"

  if [ -n "${ZSH_FZF_HISTORY_SEARCH_REMOVE_DUPLICATES}" ]; then
    if (( $+commands[awk] )); then
      history_cmd="$history_cmd | awk '!seen[\$0]++'"
    else
      history_cmd="$history_cmd | uniq"
    fi
  fi

  # Always start fzf with an empty query (ignore $BUFFER)
  candidates=(${(f)"$(eval $history_cmd | fzf ${=ZSH_FZF_HISTORY_SEARCH_FZF_ARGS} ${=ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS})"})

  local ret=$?
  if [ -n "$candidates" ]; then
    if (( $CANDIDATE_LEADING_FIELDS != 1 )); then
      BUFFER="${candidates[@]/(#m)[0-9 \-\:\*]##/$(
      printf '%s' "${${(As: :)MATCH}[${CANDIDATE_LEADING_FIELDS},-1]}" | sed 's/%/%%/g'
      )}"
    else
      BUFFER="${(j| && |)candidates}"
    fi
    zle vi-fetch-history -n $BUFFER
    if [ -n "${ZSH_FZF_HISTORY_SEARCH_END_OF_LINE}" ]; then
      zle end-of-line
    fi
  fi

  zle reset-prompt
  return $ret
}
zle -N fzf_history_search

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
  local file=${(Q)word}
  file=${file## }
  file=${file%% }
  
  if [[ -f $file ]]; then
    local mime=$(file --brief --mime-type "$file" 2>/dev/null)
    case $mime in
      image/*)
        # Detect sixel support and use appropriate method
        if [[ "$TERM_PROGRAM" == "ghostty" ]] || [[ "$TERM" == "xterm-kitty" ]]; then
          # Kitty graphics protocol
          kitty icat --clear --transfer-mode=memory --stdin=no "$file"
        elif command -v chafa > /dev/null 2>&1; then
          # Use sixel for terminals that support it (st, xterm, mlterm, etc)
          # Works in tmux 3.4+ with allow-passthrough and terminal-features configured
          chafa -f sixel -s "${FZF_PREVIEW_COLUMNS:-80}x${FZF_PREVIEW_LINES:-24}" --animate=off "$file"
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


