#!/bin/bash

# Define the source directory where the new config files are located
SOURCE_DIR="$HOME/dotfiles"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only."
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Homebrew if not present
install_homebrew() {
    if ! command_exists brew; then
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        print_success "Homebrew installed successfully"
    else
        print_status "Homebrew already installed"
    fi
}

# Function to install applications via Homebrew
install_apps() {
    print_status "Installing applications via Homebrew..."
    
    # Core applications
    local apps=(
        "neovim"
        "tmux"
        "git"
        "git-lfs"
        "delta"
        "ripgrep"
        "eza"
        "yazi"
        "asdf"
        "nvm"
        "pnpm"
        "bun"
        "yarn"
        "poetry"
        "koekeishiya/formulae/skhd"
        "nikitabobko/tap/aerospace"
        "ghostty"
        "wezterm"
        "font-jetbrains-mono-nerd-font"
    )
    
    for app in "${apps[@]}"; do
        if [[ $app == font-* ]]; then
            # Handle font installation
            if ! brew list --cask | grep -q "${app}"; then
                print_status "Installing ${app}..."
                brew install --cask "${app}"
            else
                print_status "${app} already installed"
            fi
        elif [[ $app == *"/"* ]]; then
            # Handle tap installations
            local tap_name=$(echo $app | cut -d'/' -f3)
            if ! brew list | grep -q "${tap_name}"; then
                print_status "Installing ${app}..."
                brew install "${app}"
            else
                print_status "${tap_name} already installed"
            fi
        else
            # Handle regular installations
            if ! brew list | grep -q "^${app}$"; then
                print_status "Installing ${app}..."
                brew install "${app}"
            else
                print_status "${app} already installed"
            fi
        fi
    done
    
    print_success "Applications installed successfully"
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        print_status "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        print_success "Oh My Zsh installed successfully"
    else
        print_status "Oh My Zsh already installed"
    fi
}

# Function to install Zsh plugins
install_zsh_plugins() {
    print_status "Installing Zsh plugins..."
    
    # Install zsh-syntax-highlighting
    local zsh_highlight_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    if [ ! -d "$zsh_highlight_dir" ]; then
        print_status "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_highlight_dir"
    else
        print_status "zsh-syntax-highlighting already installed"
    fi
    
    # Install zsh-autosuggestions
    local zsh_autosuggestions_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    if [ ! -d "$zsh_autosuggestions_dir" ]; then
        print_status "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$zsh_autosuggestions_dir"
    else
        print_status "zsh-autosuggestions already installed"
    fi
    
    # Install Powerlevel10k theme
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ ! -d "$p10k_dir" ]; then
        print_status "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    else
        print_status "Powerlevel10k already installed"
    fi
    
    print_success "Zsh plugins installed successfully"
}

# Function to install Tmux Plugin Manager
install_tmux_plugins() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [ ! -d "$tpm_dir" ]; then
        print_status "Installing Tmux Plugin Manager..."
        git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
        print_success "Tmux Plugin Manager installed successfully"
        print_warning "Run 'tmux source ~/.tmux.conf' and press 'prefix + I' to install tmux plugins"
    else
        print_status "Tmux Plugin Manager already installed"
    fi
}

# Function to start services
start_services() {
    print_status "Starting system services..."
    
    # Start skhd
    if command_exists skhd; then
        brew services start skhd
        print_success "skhd service started"
    fi
    
    # Start AeroSpace (it should auto-start, but we can check)
    if command_exists aerospace; then
        print_status "AeroSpace installed (will start automatically)"
    fi
}

# Main installation function
install_all() {
    print_status "Starting dotfiles setup and application installation..."
    
    install_homebrew
    install_apps
    install_oh_my_zsh
    install_zsh_plugins
    install_tmux_plugins
    start_services
    
    print_success "All applications installed successfully!"
    print_status "Now creating symbolic links for configuration files..."
}

# Run the installation process
install_all

# Define an associative array with the files to link.
# The keys are the source files in the SOURCE_DIR.
# The values are the names of the target files in the home directory.
declare -A files_to_link=(
    ["nvim/"]=".config/nvim"
    [".config/skhd"]=".config/skhd"
    [".config/aerospace"]=".config/aerospace"
    [".config/ghostty"]=".config/ghostty"
    [".config/linearmouse"]=".config/linearmouse"
    [".config/yazi"]=".config/yazi"
    [".tmux.conf"]=".tmux.conf"
    [".zshrc"]=".zshrc"
    [".p10k.zsh"]=".p10k.zsh"
    [".wezterm.lua"]=".wezterm.lua"
    [".gitconfig"]=".gitconfig"
    ["Application Support/org.pqrs"]="/Library/Application Support/"
)

# Iterate through the associative array
for source_file in "${!files_to_link[@]}"
do
    target_file="${files_to_link[$source_file]}"

    # Replace '_' with '.' in the source file name
    # source_file=${source_file//_/.}

    # Full path for source and target
    source_path="${SOURCE_DIR}/${source_file}"
    target_path="$HOME/${target_file}"

    # Remove the existing file in the home directory (if it exists)
    if [ -f "$target_path" ] || [ -L "$target_path" ]; then
        rm -f "$target_path"
        echo "Removed existing file: $target_path"
    fi

    # Create a symbolic link
    ln -s "$source_path" "$target_path"
    echo "Created symlink:  $source_path -> $target_path"
done

print_success "All done! Your dotfiles have been installed and configured."
print_status "Next steps:"
print_status "  1. Restart your terminal or run 'source ~/.zshrc'"
print_status "  2. Open tmux and press 'prefix + I' to install tmux plugins"
print_status "  3. Open Neovim - Mason will automatically install LSP servers"
print_status "  4. Configure AeroSpace and skhd according to your preferences"
