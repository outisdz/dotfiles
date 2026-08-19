#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_info "Installation Script Directory: $SCRIPT_DIR"
echo ""

# Check if we're in the dotfiles directory
if [ ! -d "$SCRIPT_DIR/config" ]; then
    print_error "config directory not found at $SCRIPT_DIR/config"
    print_error "Please run this script from the dotfiles directory."
    exit 1
fi

print_info "Starting dotfiles installation..."
echo ""

# Track installation status
INSTALL_SUCCESS=0
INSTALL_FAILED=0

# Function to safe copy with error checking
safe_copy() {
    local source="$1"
    local dest="$2"
    local name="$3"

    if [ ! -d "$source" ]; then
        print_error "$name directory not found: $source"
        ((INSTALL_FAILED++))
        return 1
    fi

    # Count files in source
    local file_count=$(find "$source" -type f | wc -l)
    if [ "$file_count" -eq 0 ]; then
        print_error "$name directory is empty: $source"
        ((INSTALL_FAILED++))
        return 1
    fi

    # Create destination if it doesn't exist
    mkdir -p "$dest" || { print_error "Failed to create $dest"; ((INSTALL_FAILED++)); return 1; }

    # Copy files
    print_info "Copying $name ($file_count files)..."
    if cp -rv "$source"/* "$dest/" > /dev/null 2>&1; then
        print_status "$name copied to $dest"
        ((INSTALL_SUCCESS++))
        return 0
    else
        print_error "Failed to copy $name from $source to $dest"
        ((INSTALL_FAILED++))
        return 1
    fi
}

# Create necessary home directories
print_info "Creating user directories..."
mkdir -p ~/.config
mkdir -p ~/.themes
mkdir -p ~/.icons
mkdir -p ~/wallpapers
mkdir -p ~/.images
print_status "User directories created/verified"
echo ""

# Copy config files
safe_copy "$SCRIPT_DIR/config" "$HOME/.config" "Config files"
echo ""

# Copy themes
safe_copy "$SCRIPT_DIR/themes" "$HOME/.themes" "Themes"
echo ""

# Copy icons
safe_copy "$SCRIPT_DIR/icons" "$HOME/.icons" "Icons"
echo ""

# Copy wallpapers
safe_copy "$SCRIPT_DIR/wallpapers" "$HOME/wallpapers" "Wallpapers"
echo ""

# Copy images (optional)
if [ -d "$SCRIPT_DIR/images" ] && [ "$(find "$SCRIPT_DIR/images" -type f | wc -l)" -gt 0 ]; then
    safe_copy "$SCRIPT_DIR/images" "$HOME/.images" "Images"
    echo ""
else
    print_info "Images directory is empty or not found (optional)"
    echo ""
fi

# Install dependencies
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Dependency Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "The following packages need to be installed:"
echo "  • Official Repos: hyprland waybar rofi kitty mako hyprlock hypridle fastfetch fish hyprpaper sddm thunar"
echo "  • AUR: wlogout"
echo ""

# Ask user if they want to install dependencies
read -p "Do you want to install dependencies now? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Starting dependency installation..."
    echo ""

    # Install from official repos
    print_info "Installing packages from official repositories..."
    if sudo pacman -S --noconfirm hyprland waybar rofi kitty mako hyprlock hypridle fastfetch fish hyprpaper sddm thunar; then
        print_status "Official packages installed successfully"
    else
        print_error "Failed to install some official packages"
    fi
    echo ""

    # Check if paru or yay is installed
    if command -v paru &> /dev/null; then
        print_info "Found paru, installing wlogout from AUR..."
        if paru -S --noconfirm wlogout; then
            print_status "wlogout installed successfully from AUR"
        else
            print_error "Failed to install wlogout from AUR"
        fi
    elif command -v yay &> /dev/null; then
        print_info "Found yay, installing wlogout from AUR..."
        if yay -S --noconfirm wlogout; then
            print_status "wlogout installed successfully from AUR"
        else
            print_error "Failed to install wlogout from AUR"
        fi
    else
        echo ""
        print_error "Neither paru nor yay found. AUR helper is required to install wlogout."
        echo ""
        print_info "Install paru:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  git clone https://aur.archlinux.org/paru.git"
        echo "  cd paru"
        echo "  makepkg -si"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        print_info "After installing paru, run:"
        echo "  paru -S wlogout"
        echo ""
    fi
else
    print_info "Skipping dependency installation."
    echo ""
    print_info "To install dependencies manually, run:"
    echo "  sudo pacman -S hyprland waybar rofi kitty mako hyprlock hypridle fastfetch fish hyprpaper sddm thunar"
    echo ""
    print_info "For wlogout from AUR (requires paru or yay):"
    echo "  paru -S wlogout"
    echo "  # or"
    echo "  yay -S wlogout"
    echo ""
fi

# ─────────────────────────────────────────────────────────────────
# Additional packages for a fresh/minimal Arch installation
# ─────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Additional Packages (recommended for a fresh/minimal Arch install)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "If this is a clean/minimal Arch install, you likely need several"
print_info "extra packages for graphics, audio, fonts, theming, and utilities"
print_info "that a minimal install doesn't include by default."
echo ""

read -p "Is this a new/minimal Arch installation? Install additional packages now? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then

    # Category: System & Display
    SYSTEM_DISPLAY_PKGS="xorg-xwayland xorg-xrandr libxrandr mesa vulkan-tools"
    # Category: Audio & Media
    AUDIO_PKGS="pipewire pipewire-alsa pipewire-pulse alsa-utils pavucontrol"
    # Category: Fonts & Text Rendering
    FONT_PKGS="ttf-jetbrains-mono ttf-liberation noto-fonts fontconfig"
    # Category: GTK & Theme Dependencies
    THEME_PKGS="gtk3 gtk4 breeze breeze-icons xdg-desktop-portal-hyprland"
    # Category: File Management & Utilities
    FILE_PKGS="tumbler gvfs udisks2 ntfs-3g"
    # Category: Networking & Connectivity
    NET_PKGS="networkmanager nm-connection-editor bluez bluez-utils"
    # Category: Terminal & Shell Enhancements
    SHELL_PKGS="git curl wget base-devel openssh"
    # Category: Power Management
    POWER_PKGS="acpi acpid power-profiles-daemon"
    # Category: Additional Useful Tools
    EXTRA_PKGS="polkit polkit-kde-agent wofi swappy grim slurp wl-clipboard"

    install_category() {
        local label="$1"
        local pkgs="$2"

        echo ""
        read -p "Install $label? ($pkgs) (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installing $label..."
            if sudo pacman -S --noconfirm $pkgs; then
                print_status "$label installed successfully"
            else
                print_error "Failed to install some packages in: $label"
            fi
        else
            print_info "Skipped $label"
        fi
    }

    install_category "System & Display packages" "$SYSTEM_DISPLAY_PKGS"
    install_category "Audio & Media packages" "$AUDIO_PKGS"
    install_category "Fonts & Text Rendering packages" "$FONT_PKGS"
    install_category "GTK & Theme Dependencies" "$THEME_PKGS"
    install_category "File Management & Utilities" "$FILE_PKGS"
    install_category "Networking & Connectivity" "$NET_PKGS"
    install_category "Terminal & Shell Enhancements" "$SHELL_PKGS"
    install_category "Power Management" "$POWER_PKGS"
    install_category "Additional Useful Tools" "$EXTRA_PKGS"

    echo ""
    print_status "Additional package installation step complete."
else
    print_info "Skipping additional packages."
    print_info "You can install them later with:"
    echo "  sudo pacman -S xorg-xwayland xorg-xrandr libxrandr mesa vulkan-tools \\"
    echo "    pipewire pipewire-alsa pipewire-pulse alsa-utils pavucontrol \\"
    echo "    ttf-jetbrains-mono ttf-liberation noto-fonts fontconfig \\"
    echo "    gtk3 gtk4 breeze breeze-icons xdg-desktop-portal-hyprland \\"
    echo "    tumbler gvfs udisks2 ntfs-3g \\"
    echo "    networkmanager nm-connection-editor bluez bluez-utils \\"
    echo "    git curl wget base-devel openssh \\"
    echo "    acpi acpid power-profiles-daemon \\"
    echo "    polkit polkit-kde-agent wofi swappy grim slurp wl-clipboard"
fi
echo ""

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$INSTALL_FAILED" -eq 0 ]; then
    print_status "Configuration files installed successfully!"
    print_info "Dotfiles have been copied to your home directory."
else
    echo ""
    print_error "Installation completed with $INSTALL_FAILED error(s)"
    print_info "Please check the errors above and run the script again if needed."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Next steps:"
echo "  1. Make sure all dependencies are installed"
echo "  2. Start Hyprland: startx (or restart your session)"
echo "  3. Reload Fish shell configuration: source ~/.config/fish/config.fish"
echo "  4. Customize Hyprland: ~/.config/hypr/hyprland.conf"
echo ""