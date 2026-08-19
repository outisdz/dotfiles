#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[•]${NC} $1"
}

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're in the dotfiles directory
if [ ! -d "$SCRIPT_DIR/config" ]; then
    print_error "config directory not found. Please run this script from the dotfiles directory."
    exit 1
fi

print_info "Starting dotfiles installation..."

# Create necessary directories if they don't exist
mkdir -p ~/.config
mkdir -p ~/.themes
mkdir -p ~/.icons
mkdir -p ~/wallpapers
mkdir -p ~/.images

# Copy config files
if [ -d "$SCRIPT_DIR/config" ]; then
    print_info "Copying config files..."
    cp -r "$SCRIPT_DIR/config"/* ~/.config/ 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status "Config files copied to ~/.config/"
    else
        print_error "Failed to copy config files"
    fi
else
    print_error "config directory not found"
fi

# Copy themes
if [ -d "$SCRIPT_DIR/themes" ]; then
    print_info "Copying themes..."
    cp -r "$SCRIPT_DIR/themes"/* ~/.themes/ 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status "Themes copied to ~/.themes/"
    else
        print_error "Failed to copy themes"
    fi
else
    print_error "themes directory not found"
fi

# Copy icons
if [ -d "$SCRIPT_DIR/icons" ]; then
    print_info "Copying icons..."
    cp -r "$SCRIPT_DIR/icons"/* ~/.icons/ 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status "Icons copied to ~/.icons/"
    else
        print_error "Failed to copy icons"
    fi
else
    print_error "icons directory not found"
fi

# Copy wallpapers
if [ -d "$SCRIPT_DIR/wallpapers" ]; then
    print_info "Copying wallpapers..."
    cp -r "$SCRIPT_DIR/wallpapers"/* ~/wallpapers/ 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status "Wallpapers copied to ~/wallpapers/"
    else
        print_error "Failed to copy wallpapers"
    fi
else
    print_error "wallpapers directory not found"
fi

# Copy images
if [ -d "$SCRIPT_DIR/images" ]; then
    print_info "Copying images..."
    cp -r "$SCRIPT_DIR/images"/* ~/.images/ 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status "Images copied to ~/.images/"
    else
        print_error "Failed to copy images"
    fi
else
    print_error "images directory not found (optional)"
fi

# Copy scripts to /usr/local/bin with proper permissions
if [ -d "$SCRIPT_DIR/scripts" ]; then
    print_info "Copying scripts to /usr/local/bin..."
    for script in "$SCRIPT_DIR/scripts"/*; do
        if [ -f "$script" ]; then
            sudo cp "$script" /usr/local/bin/ 2>/dev/null
            sudo chmod +x /usr/local/bin/$(basename "$script")
        fi
    done
    if [ $? -eq 0 ]; then
        print_status "Scripts copied and made executable in /usr/local/bin/"
    else
        print_error "Failed to copy scripts (requires sudo)"
    fi
else
    print_error "scripts directory not found"
fi

# Prompt to optionally install desktop packages
echo ""
DESKTOP_PKGS="hyprland waybar rofi kitty mako hyprlock hypridle fastfetch fish hyprpaper wlogout sddm thunar"
while true; do
    read -rp "$(echo -e "${YELLOW}Install desktop packages: ${DESKTOP_PKGS}? [Y/n]${NC}") " INSTALL_DESKTOP
    INSTALL_DESKTOP=${INSTALL_DESKTOP:-Y}
    case "$INSTALL_DESKTOP" in
        [Yy]* )
            print_info "Installing desktop packages..."
            PKGS="$DESKTOP_PKGS"
            if command -v apt-get >/dev/null 2>&1; then
                print_info "Detected apt — installing packages"
                sudo apt-get update && sudo apt-get install -y $PKGS || print_error "apt install failed"
            elif command -v pacman >/dev/null 2>&1; then
                print_info "Detected pacman — installing packages"
                sudo pacman -Syu --noconfirm --needed $PKGS || print_error "pacman install failed"
            elif command -v yay >/dev/null 2>&1; then
                print_info "Detected yay — installing packages"
                yay -S --noconfirm $PKGS || print_error "yay install failed"
            else
                print_error "No supported package manager found (apt, pacman, or yay). Skipping desktop package install."
            fi
            break
            ;;
        [Nn]* )
            print_info "Skipping desktop package installation."
            break
            ;;
        * )
            echo "Please answer Y or n."
            ;;
    esac
done

echo ""
print_status "Installation complete!"
print_info "Configuration files are now in place."
print_info "You may need to restart your session or reload configurations."
