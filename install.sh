#!/usr/bin/env zsh
#
# ZSH Configuration Installer
# Idempotent installation and update script
#

setopt ERR_EXIT

SCRIPT_DIR="${0:A:h}"
ZDOTDIR="$HOME/.config/zsh"
BACKUP_DIR="$HOME/.config/zsh-backups/$(date +%Y%m%d-%H%M%S)"
ZSHRC_FILE="$HOME/.zshrc"

# Colors for output
autoload -U colors && colors

# Print functions
print_info() {
    print -P "%F{blue}ℹ%f $1"
}

print_success() {
    print -P "%F{green}✓%f $1"
}

print_warning() {
    print -P "%F{yellow}⚠%f $1"
}

print_error() {
    print -P "%F{red}✗%f $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing=0
    
    # Check for git
    if ! command -v git &>/dev/null; then
        print_error "git is not installed (required for plugin management)"
        missing=1
    else
        print_success "git found"
    fi
    
    # zsh is obviously available if we're running this
    print_success "zsh found: $ZSH_VERSION"
    
    # Check for fzf (warn only)
    if ! command -v fzf &>/dev/null; then
        print_warning "fzf not found - install for fuzzy completion features"
    else
        print_success "fzf found: $(fzf --version)"
    fi
    
    if (( missing )); then
        print_error "Missing required dependencies. Please install them first."
        exit 1
    fi
}

# Create backup of existing config
backup_existing() {
    local needs_backup=0
    
    # Check if we need to backup anything
    if [[ -f "$ZSHRC_FILE" ]] && ! grep -q "ZDOTDIR.*/.config/zsh" "$ZSHRC_FILE" 2>/dev/null; then
        needs_backup=1
    fi
    
    if [[ -d "$ZDOTDIR" && "$SCRIPT_DIR" != "$ZDOTDIR" ]]; then
        needs_backup=1
    fi
    
    if (( needs_backup )); then
        print_info "Creating backup..."
        mkdir -p "$BACKUP_DIR"
        
        if [[ -f "$ZSHRC_FILE" ]]; then
            cp "$ZSHRC_FILE" "$BACKUP_DIR/.zshrc"
            print_success "Backed up ~/.zshrc to $BACKUP_DIR"
        fi
        
        if [[ -d "$ZDOTDIR" && "$SCRIPT_DIR" != "$ZDOTDIR" ]]; then
            cp -r "$ZDOTDIR" "$BACKUP_DIR/zsh-config"
            print_success "Backed up $ZDOTDIR to $BACKUP_DIR"
        fi
    else
        print_info "No backup needed (config already installed or no existing config)"
    fi
}

# Install/update config files
install_config() {
    print_info "Installing/updating configuration files..."
    
    # Create ZDOTDIR if needed
    mkdir -p "$ZDOTDIR"
    
    # If script is not already in ZDOTDIR, copy files
    if [[ "$SCRIPT_DIR" != "$ZDOTDIR" ]]; then
        print_info "Copying configuration files to $ZDOTDIR"
        cp "$SCRIPT_DIR"/{zshrc,zsh-prompt,zsh-local,README.md} "$ZDOTDIR/" 2>/dev/null || true
        cp "$SCRIPT_DIR/install.sh" "$ZDOTDIR/" 2>/dev/null || true
        chmod +x "$ZDOTDIR/install.sh"
        print_success "Configuration files copied"
    else
        print_success "Configuration files already in place"
    fi
    
    # Create/update ~/.zshrc
    if [[ ! -f "$ZSHRC_FILE" ]] || ! grep -q "ZDOTDIR.*/.config/zsh" "$ZSHRC_FILE" 2>/dev/null; then
        print_info "Creating/updating ~/.zshrc"
        cat > "$ZSHRC_FILE" << 'EOF'
# ZSH Configuration
# Managed by ~/.config/zsh/install.sh

export ZDOTDIR=$HOME/.config/zsh
source "$HOME/.config/zsh/zshrc"
EOF
        print_success "~/.zshrc configured"
    else
        print_success "~/.zshrc already configured"
    fi
}

# Install zinit if needed
install_zinit() {
    local ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    
    if [[ ! -d "$ZINIT_HOME" ]]; then
        print_info "Installing zinit plugin manager..."
        mkdir -p "${ZINIT_HOME:h}"
        git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
        print_success "zinit installed"
    else
        print_success "zinit already installed"
    fi
}

# Check optional tools
check_optional_tools() {
    print_info "Checking optional tools..."
    
    local -A tools=(
        bat "Syntax highlighting in previews"
        eza "Modern directory listings"
        fd "Fast file finder"
        rg "ripgrep for fast text search"
        chafa "Image previews in terminal"
        starship "Modern prompt"
        mise "Runtime version manager"
    )
    
    for tool desc in ${(kv)tools}; do
        if command -v "$tool" &>/dev/null; then
            print_success "$tool installed - $desc"
        else
            print_warning "$tool not found - $desc (optional)"
        fi
    done
}

# Set zsh as default shell
set_default_shell() {
    if [[ "$SHELL" != "$(whence -p zsh)" ]]; then
        print_warning "Current shell is not zsh"
        read -q "REPLY?Would you like to set zsh as your default shell? (y/N) "
        print
        if [[ $REPLY == "y" ]]; then
            chsh -s "$(whence -p zsh)"
            print_success "Default shell changed to zsh (will take effect on next login)"
        fi
    else
        print_success "zsh is already the default shell"
    fi
}

# Main installation flow
main() {
    print
    print "╔════════════════════════════════════════════╗"
    print "║   ZSH Configuration Installer/Updater      ║"
    print "╚════════════════════════════════════════════╝"
    print
    
    check_prerequisites
    print
    
    backup_existing
    print
    
    install_config
    print
    
    install_zinit
    print
    
    check_optional_tools
    print
    
    set_default_shell
    print
    
    print_success "Installation/update complete!"
    print
    print_info "Next steps:"
    print "  1. Reload your shell: exec zsh"
    print "  2. Plugins will auto-install on first launch"
    print "  3. See ~/.config/zsh/README.md for documentation"
    print
    
    if [[ -d "$BACKUP_DIR" ]]; then
        print_info "Backup saved to: $BACKUP_DIR"
        print
    fi
}

# Run main function
main "$@"
