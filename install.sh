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

# Copy scripts to /usr/local/bin with proper permissions
if [ -d "$SCRIPT_DIR/scripts" ]; then
    script_count=$(find "$SCRIPT_DIR/scripts" -type f | wc -l)
    if [ "$script_count" -gt 0 ]; then
        print_info "Copying $script_count scripts to /usr/local/bin..."
        for script in "$SCRIPT_DIR/scripts"/*; do
            if [ -f "$script" ]; then
                script_name=$(basename "$script")
                if sudo cp "$script" /usr/local/bin/ 2>/dev/null; then
                    if sudo chmod +x "/usr/local/bin/$script_name" 2>/dev/null; then
                        print_status "Script installed: $script_name"
                        ((INSTALL_SUCCESS++))
                    else
                        print_error "Failed to make $script_name executable"
                        ((INSTALL_FAILED++))
                    fi
                else
                    print_error "Failed to copy $script_name (requires sudo)"
                    ((INSTALL_FAILED++))
                fi
            fi
        done
        echo ""
    else
        print_info "Scripts directory is empty (optional)"
        echo ""
    fi
else
    print_error "Scripts directory not found at $SCRIPT_DIR/scripts"
    echo ""
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$INSTALL_FAILED" -eq 0 ]; then
    print_status "Installation completed successfully!"
    print_info "Configuration files have been installed to your home directory."
else
    echo ""
    print_error "Installation completed with $INSTALL_FAILED error(s)"
    print_info "Please check the errors above and run the script again if needed."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Next steps:"
echo "  1. Start Hyprland: startx"
echo "  2. Reload Fish shell configuration: source ~/.config/fish/config.fish"
echo "  3. Customize Hyprland: ~/.config/hypr/hyprland.conf"
echo ""
