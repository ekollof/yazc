# ZSH Configuration

A modular, plugin-based ZSH configuration with FZF integration, custom prompt, and automatic plugin management.

## Installation

### Automatic Installation

Run the install script (idempotent - safe to run multiple times):

```bash
cd ~/.config/zsh
./install.sh
```

The installer will:
- Check prerequisites (git, zsh, fzf)
- Backup existing configuration if present
- Install/update configuration files
- Set up zinit plugin manager
- Optionally set zsh as default shell

**Note:** Backups are saved to `~/.config/zsh-backups/YYYYMMDD-HHMMSS/`

### Manual Installation

1. **Clone or copy this configuration to `~/.config/zsh/`**

2. **Create/update your `~/.zshrc`:**
   ```bash
   export ZDOTDIR=$HOME/.config/zsh
   source "$HOME/.config/zsh/zshrc"
   ```

3. **Reload your shell:**
   ```bash
   exec zsh
   ```

Plugins will be automatically cloned on first launch.

## Structure

```
~/.config/zsh/
├── zshrc           # Main configuration file
├── zsh-prompt      # Custom prompt with git integration
├── zsh-local       # Local settings, aliases, PATH, etc.
└── README.md       # This file
```

Plugins are managed by zinit in `~/.local/share/zinit/`

## Features

### History Management
- 5000 command history with deduplication
- Shared history across sessions
- Ignores duplicate and space-prefixed commands

### Plugin Manager
Uses [zinit](https://github.com/zdharma-continuum/zinit) for fast, efficient plugin management with lazy loading support.

**Installed Plugins:**
- **zsh-autosuggestions** - Command suggestions based on history
- **zsh-autopair** - Auto-close brackets, quotes, etc.
- **zsh-fzf-history-search** - Enhanced history search with FZF
- **fzf-tab** - FZF-powered tab completion
- **zsh-completions** - Additional completion definitions (1000+ commands)
- **fast-syntax-highlighting** - Real-time syntax highlighting
- **zsh-you-should-use** - Reminds you of existing aliases
- **git** (OMZ) - Git aliases and functions
- **sudo** (OMZ) - Press ESC ESC to add sudo to command
- **extract** (OMZ) - Universal archive extractor

Zinit auto-installs on first launch to `~/.local/share/zinit/`.

### FZF Integration
Requires [fzf](https://github.com/junegunn/fzf) to be installed.

**Keybindings:**
- `Ctrl+R` - Search command history
- `Ctrl+T` - Find and paste files/directories
- `Alt+C` - Change directory interactively
- `Ctrl+/` - Toggle preview window
- `Ctrl+A` - Select all results
- `Ctrl+Y` - Copy selection to clipboard

**Optional tools for enhanced previews:**
- `bat` - Syntax highlighting in file previews
- `eza` - Modern `ls` replacement for directory previews
- `fd` - Fast file finder (replaces `find`)
- `rg` (ripgrep) - Fast content search

### Git Prompt
Custom prompt shows:
- Username, hostname, and current directory
- Git repository and branch
- Git status indicators:
  - `!` - Untracked files
  - `+` - Staged changes
  - `*` - Modified files

**Note:** Can be overridden by Starship if installed.

### Smart Tool Loading
The following tools are conditionally loaded if available:
- **mise** - Runtime version manager
- **carapace** - Multi-shell completion generator
- **starship** - Cross-shell prompt (overrides default prompt)
- **keychain** - SSH key manager (auto-loads all `~/.ssh/id_*` keys)

### GPG/SSH Integration
- Configures GPG agent for SSH authentication
- Auto-loads SSH keys via keychain
- Updates GPG TTY for proper pinentry

## Updating

To update the configuration after pulling changes:

```bash
cd ~/.config/zsh
./install.sh  # Idempotent - safe to run anytime
```

To update plugins:

```bash
zinit update --all
```

### Local Configuration
Edit `zsh-local` for personal settings:
- Aliases
- Environment variables
- Additional PATH entries
- Machine-specific configuration

### Adding Plugins
Add to `zshrc` using zinit:
```bash
# Fast loading
zinit light user/repo-name

# With lazy loading (defer until after prompt)
zinit ice wait lucid
zinit light user/repo-name

# Oh-My-Zsh plugins/snippets
zinit snippet OMZP::plugin-name
```

### Updating Plugins
```bash
zinit update --all        # Update all plugins
zinit update plugin-name  # Update specific plugin
```

### Managing Plugins
```bash
zinit list               # List installed plugins
zinit delete plugin-name # Remove a plugin
zinit self-update        # Update zinit itself
```

## Keybindings

### History Search
- `↑` / `Ctrl+P` - Search backward in history (matching current input)
- `↓` / `Ctrl+N` - Search forward in history (matching current input)
- `Ctrl+S` - Enabled (not used for terminal freeze)

### fzf-tab Completion
- `↑` / `↓` or `Tab` / `Shift+Tab` - Navigate through completion list
- `Enter` - Accept selection and exit completion
- `→` (Right Arrow) - Continuous completion (drill into selected directory)
- `Ctrl+Space` - Multi-select items
- `<` / `>` - Switch between completion groups
- `Ctrl+/` - Toggle preview window

### sudo Plugin
- `ESC ESC` - Prepend sudo to current or previous command

### Syntax Highlighting
Commands are highlighted as you type:
- **Green** - Valid command
- **Red** - Invalid/not found
- **Blue** - Builtin command

## Performance

### Fast Startup Optimizations
- Cached completion dump (regenerates once per 24 hours)
- Background loading of wallust/fortune
- Conditional loading of optional tools
- Efficient plugin management

### Clearing Completion Cache
If completions break after updates:
```bash
rm ~/.config/zsh/.zcompdump*
exec zsh
```

## Dependencies

**Required:**
- zsh (5.0+)
- git (for plugin management)

**Optional (Enhanced Features):**
- fzf - Fuzzy finder integration
- bat - Syntax highlighting in file previews
- eza - Modern `ls` replacement for directory previews
- fd - Fast file finder (replaces `find`)
- ripgrep - Fast text search
- starship - Modern prompt
- mise - Runtime manager
- keychain - SSH key management
- fortune - Random quotes on startup
- **chafa** - Image previews in terminal (sixel support)
- **viu** - Alternative image viewer
- **kitty/ghostty** - Terminal with graphics protocol support for image previews
- **zoxide** - Smarter directory jumping (better than cd)

## Troubleshooting

### Plugins not loading
Reinstall zinit and plugins:
```bash
rm -rf ~/.local/share/zinit
exec zsh
```

### Update all plugins
```bash
zinit update --all
```

### Slow startup
Check for network delays in plugin loading. Ensure all plugins are already cloned.

### Completion issues
Regenerate completions:
```bash
rm ~/.config/zsh/.zcompdump*
autoload -Uz compinit && compinit
```

## Terminal Compatibility

Tested with:
- kitty (with SSH kitten support)
- xterm
- rxvt/urxvt
- termite
- dumb terminals (Emacs support)

## License

Personal configuration - use and modify as needed.
