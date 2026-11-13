#!/bin/zsh
export ZDOTDIR=$HOME/.config/zsh

# Bail out early for dumb terminals (Emacs TRAMP, etc.) — skip all plugin
# loading and interactive setup so startup is instant in those contexts.
if [[ "$TERM" == "dumb" ]]; then
  unset zle_bracketed_paste
  unset zle
  PS1='$ '
  return
fi

# ---------------------------------------------------------------------------
# Terminal capability helpers
#
# Ambient COLORTERM=truecolor is often set session-wide (environment.d, DE
# session) even when the actual emulator is limited (CDE dtterm, classic
# vt*, linux console). Prefer TERM + terminfo colors over COLORTERM alone.
# Features that emit modern CSI/OSC (cursor shape, truecolor OSC, starship)
# must consult these helpers so low-capability terminals degrade cleanly.
# ---------------------------------------------------------------------------
zmodload zsh/terminfo 2>/dev/null

# Known-bad / legacy TERM values that mishandle modern CSI (esp. DECSCUSR
# cursor-shape `\e[N q`, which leaks as literal `q` on dtterm).
_term_is_legacy() {
  case ${TERM:-dumb} in
    dumb|dtterm|cde*|vt[0-9]*|ansi|linux) return 0 ;;
  esac
  return 1
}

# 256-color-capable terminal that is not on the legacy deny list.
# Safe baseline for cursor-shape sequences and 256-color prompts.
_term_has_256color() {
  _term_is_legacy && return 1
  local ncolors=${terminfo[colors]:--1}
  if (( ncolors < 0 )); then
    ncolors=$(tput colors 2>/dev/null) || return 1
  fi
  (( ncolors >= 256 ))
}

# Truecolor when the emulator can actually render 24-bit SGR *and* is not
# legacy. COLORTERM alone is not enough (session managers often export
# COLORTERM=truecolor even inside CDE dtterm), but neither is requiring it:
# OpenSSH only forwards TERM by default, so COLORTERM is empty over SSH even
# when the client terminal is kitty/cosmic-term/alacritty/….
_term_has_truecolor() {
  _term_has_256color || return 1

  # Explicit advertisement (common in local GUI sessions).
  [[ "$COLORTERM" == (truecolor|24bit) ]] && return 0

  # Direct-color terminfo entries (e.g. xterm-direct → colors#16777216).
  local ncolors=${terminfo[colors]:--1}
  if (( ncolors < 0 )); then
    ncolors=$(tput colors 2>/dev/null) || ncolors=-1
  fi
  (( ncolors >= 16777216 )) && return 0

  # Emulators whose TERM name implies truecolor (what SSH actually forwards).
  case ${TERM:-} in
    (*kitty*|*alacritty*|*wezterm*|*foot*|*ghostty*|*contour* \
    |*direct*|*truecolor*|vscode)
      return 0
      ;;
  esac

  # Over SSH, COLORTERM is almost never AcceptEnv'd. If we already passed the
  # 256-color + non-legacy gates, trust the client — truecolor SGR is ignored
  # or approximated on the rare 256-only emulator, and is required for starship
  # themes to load instead of falling back to the 8-color zsh-prompt.
  [[ -n ${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-} ]] && return 0

  return 1
}

# When truecolor is inferred without COLORTERM (typical over SSH — OpenSSH
# only forwards TERM), export it so child tools that only check COLORTERM
# (starship, bat, lazygit, …) behave the same as a local session.
if [[ -z "$COLORTERM" ]] && _term_has_truecolor; then
  export COLORTERM=truecolor
fi

HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"
setopt appendhistory
# sharehistory is omitted: atuin is the history backend; letting zsh also
# re-read the flat history file on every prompt wastes I/O and causes
# interleaving between the two stores.
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# some useful options (man zshoptions)
setopt autocd extendedglob nomatch menucomplete
setopt interactive_comments
# Warn on stopped jobs (Ctrl-Z) before exit, but not on short-lived
# background helpers (atuin history end, wallust). Those would make the
# first ^D refuse to leave and look like a hang.
unsetopt check_running_jobs
# Disable ctrl-s to freeze terminal. Guard on a real tty: tools that spawn
# `zsh -i` without a pty would otherwise print an "Inappropriate ioctl"
# error on every start.
[[ -t 0 ]] && stty stop undef 2>/dev/null
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

# LS_COLORS drives zsh completion colours (and fzf-tab's file tinting).
# dircolors uses the ANSI palette, so it follows the Omarchy/wallust theme.
if [[ -z ${LS_COLORS:-} ]] && (( $+commands[dircolors] )); then
  eval "$(dircolors -b 2>/dev/null)"
fi

# Let bat follow the terminal palette (Omarchy, wallust, pywal) instead of a
# fixed colour scheme. bat 0.18+ ships the "ansi" theme; older versions fall
# back to their default when asked for an unknown theme, so probe the list.
if (( $+commands[bat] )) && bat --list-themes 2>/dev/null | grep -qx ansi; then
  export BAT_THEME="${BAT_THEME:-ansi}"
fi

# bat as man highlighter and LESSOPEN pipe.
# Do not set MANPAGER to: sh -c "col -bx | bat ..."
# mandoc (OpenBSD, some Linux) word-splits that value and execs it as
#   sh -c col -bx | bat ...
# so sh's $0 becomes -bx and the leftover quote errors as:
#   -bx: -c: line 1: unexpected EOF while looking for matching `"'
# A wrapper is portable: man-db (Linux), mandoc (OpenBSD), FreeBSD man.
# The pipeline itself is POSIX sh (OpenBSD ksh / FreeBSD ash / dash).
if command -v bat >/dev/null 2>&1; then
  man() {
    # Piped/captured `man` must stay plain text (no pager, no bat).
    if [ ! -t 1 ]; then
      command man "$@"
      return
    fi
    # MANPAGER=cat: man-db. PAGER=cat: mandoc / BSD. Both skip the system pager.
    # MANWIDTH: man sees a pipe, so without this it formats to ~80 columns.
    MANWIDTH="${MANWIDTH:-$(tput cols 2>/dev/null || echo 80)}" \
      MANPAGER=cat PAGER=cat command man "$@" |
      col -b |
      bat -l man -p
  }
  export LESSOPEN='|bat --color=always --style=plain %s'
  export LESS='-R'
fi

# zsh-you-should-use: show alias reminder before the command runs
export YSU_MESSAGE_POSITION="before"

source "$ZDOTDIR/zsh-prompt"

# Zinit installation and setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname "$ZINIT_HOME")"
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
# zsh-vi-mode emits DECSCUSR cursor-shape sequences (`\e[N q`). On terminals
# that ignore the CSI but print the final `q` (notably CDE's dtterm) the
# prompt ends with literal "qq". Gate on real terminal capability — not
# ambient COLORTERM, which is often truecolor even inside dtterm.
if _term_has_256color; then
  zinit light jeffreytse/zsh-vi-mode

  # FreeBSD libc ERE rejects the single-quoted pattern used upstream:
  #   [[ $old_style =~ '\e\][0-9]+;.+\a' ]]
  # with "failed to compile regex: trailing backslash (\)" — and that check
  # runs on every Enter when restoring the default cursor. Rewrite the
  # in-memory function to use ANSI-C quoting (real ESC/BEL bytes in the ERE).
  # https://github.com/jeffreytse/zsh-vi-mode (zvm_cursor_style)
  if [[ ${functions[zvm_cursor_style]} == *"=~ '\\e\\][0-9]+;.+\\a'"* ]]; then
    functions[zvm_cursor_style]=${functions[zvm_cursor_style]/"=~ '\\e\\][0-9]+;.+\\a'"/"=~ \$'\\e][0-9]+;.+\\a'"}
  fi
fi

# Additional completions
zinit light zsh-users/zsh-completions

# Useful OMZ plugins
# git omz plugin replaced with hand-picked aliases below (avoids loading ~300
# aliases and patching PATH/GIT_TERMINAL_PROMPT for ones we don't use)
zinit snippet OMZP::sudo
zinit snippet OMZP::extract

# Hand-picked git aliases (replaces OMZP::git)
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit --verbose'
alias gcm='git commit -m'
alias gca='git commit --verbose --all'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate'
alias gll='git log --oneline --graph --decorate --all'
alias gp='git push'
alias gpl='git pull'
alias grb='git rebase'
alias grs='git restore'
alias grss='git restore --staged'
alias gst='git status'
alias gsw='git switch'
alias gswc='git switch -c'

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
# Prefer fd. Fall back to rg's file-list mode (not `rg -l ""`, which scans
# every file's contents just to list names).
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
elif (( $+commands[rg] )); then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --no-ignore-vcs'
fi

# Clipboard: wl-copy on Wayland, xclip on X11. Only advertise the ctrl-y
# binding when a supported clipboard tool is actually installed.
_fzf_clip=
if [[ -n ${WAYLAND_DISPLAY:-} ]] && (( $+commands[wl-copy] )); then
  _fzf_clip=wl-copy
elif [[ -n ${DISPLAY:-} ]] && (( $+commands[xclip] )); then
  _fzf_clip='xclip -selection clipboard'
fi
_fzf_copy_bind=
[[ -n $_fzf_clip ]] && _fzf_copy_bind="--bind='ctrl-y:execute-silent(printf \"%s\\n\" {+} | ${_fzf_clip})'"

# Colours use the terminal's ANSI palette (0-15), which Omarchy sets from the
# active theme. Hard-coded hex values would ignore the theme and stay stale
# after a theme switch.
export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --border
  --inline-info
  --preview-window=right:50%:wrap
  --color=fg:7,bg:0,hl:4
  --color=fg+:15,bg+:8,hl+:12
  --color=info:3,prompt:5,pointer:6
  --color=marker:2,spinner:5,header:4
  --bind='ctrl-/:toggle-preview'
  --bind='ctrl-a:select-all'
  ${_fzf_copy_bind}
"
unset _fzf_clip _fzf_copy_bind

# CTRL-T: Paste selected files/dirs — inherits FZF_DEFAULT_COMMAND (set above)
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

# Completion directories outside the plugin tree must be on fpath before
# compinit. The grok installer and omakit used to append them after the first
# compinit, forcing two extra compinit runs per shell (and re-running the
# security check after fzf-tab had already loaded). Register them here and run
# compinit once.
[[ -d $HOME/.grok/completions/zsh ]] && fpath=($HOME/.grok/completions/zsh $fpath)
[[ -d $ZDOTDIR/.zfunc ]] && fpath+=($ZDOTDIR/.zfunc)

# Run compinit once after all fpath modifications. A full run costs ~10 ms
# more than -C and, unlike -C, notices a newly added completion directory
# (e.g. ~/.zfunc or the grok installer's) without waiting for the daily dump
# refresh. The dump is only rewritten when fpath actually changed.
compinit

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
# Use Right arrow for continuous completion (via --expect, not a custom fzf binding)
zstyle ':fzf-tab:*' continuous-trigger 'right'
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
          if [[ -n "$KITTY_PID" && "$KITTY_WINDOW_ID" == <-> ]]; then
            # kitty graphics protocol via chafa: writes escape codes directly to
            # stdout, no /dev/tty handshake needed (works inside fzf preview panes).
            # Require a real Kitty window: cosmic-term advertises
            # KITTY_WINDOW_ID=cosmic-term only for the graphics protocol handshake.
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
# Preview window configuration with kitty protocol support.
# fzf-tab does not read FZF_DEFAULT_OPTS (use-fzf-default-opts is off), so
# give its picker the same ANSI palette colours to match the Omarchy theme.
zstyle ':fzf-tab:*' fzf-flags --preview-window=right:50%:wrap --height=40% \
  --color=fg:7,bg:0,hl:4 --color=fg+:15,bg+:8,hl+:12 \
  --color=info:3,prompt:5,pointer:6 --color=marker:2,spinner:5,header:4
# Switch between groups with < and >
zstyle ':fzf-tab:*' switch-group '<' '>'

# Syntax highlighting - MUST be loaded last for compatibility
zinit light zdharma-continuum/fast-syntax-highlighting

# fzf-tab's _fzf-tab-apply is intentionally NOT overridden here. Doing so
# used to fix a double-escaping bug in continuous completion, but fzf-tab now
# stores words with exactly one level of zsh quoting (e.g. "My\ Dir"). The old
# override ran ${(Q)word} on those already-correct words and handed the result
# to compadd -Q, so spaces and quotes were inserted unescaped:
#
#   mpv Misferlis fljóð - lyric video.mp4     # wrong: three arguments
#   mpv Misferlis\ fljóð\ -\ lyric\ video.mp4 # correct
#
# Leaving the upstream function alone keeps filenames with spaces, quotes, and
# other special characters quoted, including when continuing into a directory.
source "$ZDOTDIR/zsh-local"

# ---------------------------------------------------------------------------
# ls → eza/exa when installed (all platforms)
#
# Prefer the modern listing tool whenever it is on PATH. Do not gate on
# COLORTERM: OpenSSH rarely forwards it, and FreeBSD/OpenBSD sessions often
# have eza installed while still lacking COLORTERM. Personal ~/bin/aliases.sh
# may set a weaker ls alias first; re-apply here so yazc wins after zsh-local.
# ---------------------------------------------------------------------------
() {
  if (( $+commands[eza] )); then
    export EZA_ICONS_AUTO="${EZA_ICONS_AUTO:-yes}"
    alias ls=eza
  elif (( $+commands[exa] )); then
    alias ls=exa
  else
    case ${OSTYPE:-$(uname -s)} in
      openbsd*|OpenBSD)
        if (( $+commands[colorls] )); then
          alias ls='colorls -G'
        else
          alias ls='ls -G'
        fi
        ;;
      freebsd*|FreeBSD|darwin*|Darwin|netbsd*|NetBSD|dragonfly*|DragonFly)
        alias ls='ls -G'
        ;;
      *)
        # GNU coreutils (Linux, and most other non-BSD unames)
        alias ls='ls --color=auto'
        ;;
    esac
  fi
}

