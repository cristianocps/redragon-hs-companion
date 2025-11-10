#!/bin/bash
# Script de instalação do Redragon HS Companion
# Instala scripts, daemon e extensão/applet
# Suporta múltiplas distribuições e package managers

set -e

show_help() {
    echo "Redragon HS Companion - Installation Script"
    echo
    echo "Usage: ./install.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo
    echo "Supported distributions and package managers:"
    echo "  • Ubuntu / Debian / Mint          (apt)"
    echo "  • Fedora / RHEL / CentOS         (dnf / yum)"
    echo "  • Arch Linux / Manjaro           (pacman)"
    echo "  • openSUSE                       (zypper)"
    echo "  • Alpine Linux                   (apk)"
    echo "  • Gentoo                         (emerge)"
    echo
    echo "The script will automatically:"
    echo "  1. Detect your distribution and package manager"
    echo "  2. Install missing dependencies (python3, alsa-utils, etc.)"
    echo "  3. Install scripts to ~/.local/bin"
    echo "  4. Configure systemd services (if available)"
    echo "  5. Install extension/applet/widget for your desktop environment"
    echo
    echo "Note: This script requires sudo privileges to install dependencies."
    echo
    echo "For more information, visit:"
    echo "  https://github.com/cristianocps/redragon-hs-companion"
    echo
    exit 0
}

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --help|-h)
            show_help
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
GNOME_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
CINNAMON_APPLET_DIR="$HOME/.local/share/cinnamon/applets"
PLASMA_WIDGET_DIR="$HOME/.local/share/plasma/plasmoids"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$NAME"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        echo "$DISTRIB_ID"
    else
        echo "Unknown Linux"
    fi
}

print_header() {
    local distro=$(detect_distro)
    local pkg_mgr=$(detect_package_manager)
    
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Redragon HS Companion - Installer        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}System Information:${NC}"
    echo "  Distribution: $distro"
    echo "  Package Manager: $pkg_mgr"
    echo
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    elif command -v apk &> /dev/null; then
        echo "apk"
    elif command -v emerge &> /dev/null; then
        echo "emerge"
    else
        echo "unknown"
    fi
}

get_package_name() {
    local dep=$1
    local pkg_mgr=$2
    
    case "$dep" in
        python3)
            case "$pkg_mgr" in
                apt|dnf|yum|zypper) echo "python3" ;;
                pacman) echo "python" ;;
                apk) echo "python3" ;;
                emerge) echo "dev-lang/python" ;;
                *) echo "python3" ;;
            esac
            ;;
        alsa-utils)
            case "$pkg_mgr" in
                apt|dnf|yum|pacman|zypper) echo "alsa-utils" ;;
                apk) echo "alsa-utils" ;;
                emerge) echo "media-sound/alsa-utils" ;;
                *) echo "alsa-utils" ;;
            esac
            ;;
        *)
            echo "$dep"
            ;;
    esac
}

get_install_command() {
    local pkg_mgr=$1
    shift
    local packages=("$@")
    
    case "$pkg_mgr" in
        apt)
            echo "sudo apt update && sudo apt install -y ${packages[*]}"
            ;;
        dnf)
            echo "sudo dnf install -y ${packages[*]}"
            ;;
        yum)
            echo "sudo yum install -y ${packages[*]}"
            ;;
        pacman)
            echo "sudo pacman -S --noconfirm ${packages[*]}"
            ;;
        zypper)
            echo "sudo zypper install -y ${packages[*]}"
            ;;
        apk)
            echo "sudo apk add ${packages[*]}"
            ;;
        emerge)
            echo "sudo emerge ${packages[*]}"
            ;;
        *)
            echo "# Unknown package manager - install manually: ${packages[*]}"
            ;;
    esac
}

get_optional_package_name() {
    local dep=$1
    local pkg_mgr=$2
    
    case "$dep" in
        glib-compile-schemas)
            case "$pkg_mgr" in
                apt) echo "libglib2.0-dev-bin" ;;
                dnf|yum) echo "glib2-devel" ;;
                pacman) echo "glib2" ;;
                zypper) echo "glib2-devel" ;;
                apk) echo "glib-dev" ;;
                emerge) echo "dev-libs/glib" ;;
                *) echo "glib2" ;;
            esac
            ;;
        systemctl)
            case "$pkg_mgr" in
                apt|dnf|yum|zypper) echo "systemd" ;;
                pacman) echo "systemd" ;;
                apk) echo "openrc" ;;
                emerge) echo "sys-apps/systemd" ;;
                *) echo "systemd" ;;
            esac
            ;;
        *)
            echo "$dep"
            ;;
    esac
}

check_dependencies() {
    echo "Checking dependencies..."

    local missing_deps=()
    local optional_deps=()
    local pkg_mgr=$(detect_package_manager)

    # Check required dependencies
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi

    if ! command -v amixer &> /dev/null; then
        missing_deps+=("alsa-utils")
    fi

    # Check optional dependencies
    if ! command -v systemctl &> /dev/null; then
        optional_deps+=("systemctl")
        print_info "systemctl not found - systemd services will not be available"
    fi

    if command -v gnome-shell &> /dev/null && ! command -v glib-compile-schemas &> /dev/null; then
        optional_deps+=("glib-compile-schemas")
        print_info "glib-compile-schemas not found - GNOME extension will need it"
    fi

    # Install required dependencies
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_info "Missing required dependencies: ${missing_deps[*]}"
        echo
        
        # Convert dependency names to package names for this distro
        local pkg_names=()
        for dep in "${missing_deps[@]}"; do
            pkg_names+=("$(get_package_name "$dep" "$pkg_mgr")")
        done
        
        print_info "Installing dependencies using $pkg_mgr..."
        echo "  Command: $(get_install_command "$pkg_mgr" "${pkg_names[@]}")"
        echo
        
        # Install automatically
        eval "$(get_install_command "$pkg_mgr" "${pkg_names[@]}")"
        if [ $? -eq 0 ]; then
            print_success "Dependencies installed successfully"
        else
            print_error "Failed to install dependencies"
            echo
            print_info "Please install them manually:"
            echo "  $(get_install_command "$pkg_mgr" "${pkg_names[@]}")"
            exit 1
        fi
    else
        print_success "All required dependencies installed"
    fi

    # Install optional dependencies
    if [ ${#optional_deps[@]} -ne 0 ]; then
        echo
        print_info "Installing optional dependencies (recommended)..."
        
        local opt_pkg_names=()
        for dep in "${optional_deps[@]}"; do
            opt_pkg_names+=("$(get_optional_package_name "$dep" "$pkg_mgr")")
            echo "  - $dep"
        done
        
        echo
        echo "  Command: $(get_install_command "$pkg_mgr" "${opt_pkg_names[@]}")"
        echo
        
        # Install automatically (but don't fail if it doesn't work)
        eval "$(get_install_command "$pkg_mgr" "${opt_pkg_names[@]}")"
        if [ $? -eq 0 ]; then
            print_success "Optional dependencies installed"
        else
            print_info "Some optional dependencies couldn't be installed (continuing anyway)"
        fi
    fi
}

install_scripts() {
    echo
    echo "Installing scripts..."

    mkdir -p "$INSTALL_DIR"

    # Install base library (used by daemons)
    cp "$SCRIPT_DIR/redragon_volume_sync.py" "$INSTALL_DIR/"
    print_success "Library installed at $INSTALL_DIR/redragon_volume_sync.py"

    # Install CLI client (20ms via socket)
    cp "$SCRIPT_DIR/redragon-volume" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon-volume"
    print_success "CLI client installed: redragon-volume"

    # Install PCM sync daemon
    cp "$SCRIPT_DIR/redragon_daemon.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon_daemon.py"
    print_success "Sync daemon installed at $INSTALL_DIR/redragon_daemon.py"

    # Install control daemon
    cp "$SCRIPT_DIR/redragon_control_daemon.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon_control_daemon.py"
    print_success "Control daemon installed at $INSTALL_DIR/redragon_control_daemon.py"
}

install_systemd_service() {
    echo
    echo "Installing systemd services..."

    mkdir -p "$SYSTEMD_DIR"

    # Create service file with correct path
    # PCM sync service
    cat > "$SYSTEMD_DIR/redragon-volume-sync.service" <<EOF
[Unit]
Description=Redragon Wireless Headset Volume Synchronizer
After=sound.target pulseaudio.service
Wants=sound.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/redragon_daemon.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
EOF

    print_success "PCM sync service installed"

    # Fast control daemon service
    cat > "$SYSTEMD_DIR/redragon-control-daemon.service" <<EOF
[Unit]
Description=Redragon Control Daemon - Volume Control Server
After=sound.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/redragon_control_daemon.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
EOF

    print_success "Fast control daemon service installed"

    # Reload systemd
    systemctl --user daemon-reload
    print_success "Systemd reloaded"

    # Ask if should enable services
    echo
    read -p "Do you want to enable the services to start automatically? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        systemctl --user enable redragon-volume-sync.service
        systemctl --user enable redragon-control-daemon.service
        systemctl --user start redragon-volume-sync.service
        systemctl --user start redragon-control-daemon.service
        print_success "Services enabled and started"
    else
        print_info "You can start the services manually with:"
        print_info "  systemctl --user start redragon-volume-sync.service"
        print_info "  systemctl --user start redragon-control-daemon.service"
    fi
}

install_gnome_extension() {
    echo
    echo "Installing GNOME Shell extension..."

    if ! command -v gnome-shell &> /dev/null; then
        print_info "GNOME Shell not detected, skipping extension installation"
        return
    fi

    local ext_dir="$GNOME_EXT_DIR/redragon-volume-sync@cristiano"
    mkdir -p "$ext_dir"
    mkdir -p "$ext_dir/schemas"

    cp "$SCRIPT_DIR/gnome-extension/metadata.json" "$ext_dir/"
    cp "$SCRIPT_DIR/gnome-extension/extension.js" "$ext_dir/"
    cp "$SCRIPT_DIR/gnome-extension/translations.js" "$ext_dir/"
    cp "$SCRIPT_DIR/gnome-extension/schemas/org.gnome.shell.extensions.redragon-volume-sync.gschema.xml" "$ext_dir/schemas/"

    # Compile schemas
    if [ -d "$ext_dir/schemas" ]; then
        glib-compile-schemas "$ext_dir/schemas/"
        print_success "Schemas compiled"
    fi

    print_success "GNOME extension installed"
    
    # Try to enable extension automatically
    if command -v gnome-extensions &> /dev/null; then
        echo
        read -p "Do you want to enable the extension now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            gnome-extensions enable redragon-volume-sync@cristiano 2>/dev/null
            if [ $? -eq 0 ]; then
                print_success "Extension enabled successfully"
                print_info "The icon will appear in the top bar"
            else
                print_info "Please enable manually: Extensions → Redragon HS Companion"
            fi
        else
            print_info "Enable manually at: Extensions → Redragon HS Companion"
        fi
    else
        print_info "Enable the extension at: Extensions → Redragon HS Companion"
    fi
}

install_cinnamon_applet() {
    echo
    echo "Installing Cinnamon applet..."

    if [ "$XDG_CURRENT_DESKTOP" != "X-Cinnamon" ]; then
        print_info "Cinnamon not detected, skipping applet installation"
        return
    fi

    local applet_dir="$CINNAMON_APPLET_DIR/redragon-volume-sync@cristiano"
    mkdir -p "$applet_dir"

    cp "$SCRIPT_DIR/cinnamon-applet/metadata.json" "$applet_dir/"
    cp "$SCRIPT_DIR/cinnamon-applet/applet.js" "$applet_dir/"

    print_success "Cinnamon applet installed"
    
    # Try to add applet to panel automatically
    if command -v dconf &> /dev/null; then
        echo
        read -p "Do you want to add the applet to your panel now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            # Get current enabled applets
            local current_applets=$(dconf read /org/cinnamon/enabled-applets 2>/dev/null)
            
            if [ -n "$current_applets" ]; then
                # Check if applet is already added
                if [[ "$current_applets" == *"redragon-volume-sync@cristiano"* ]]; then
                    print_info "Applet already added to panel"
                else
                    # Add applet to the right side of the panel (position 'right')
                    local new_applet="'panel1:right:0:redragon-volume-sync@cristiano'"
                    local updated_applets="${current_applets:0:-1}, $new_applet]"
                    
                    dconf write /org/cinnamon/enabled-applets "$updated_applets" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        print_success "Applet added to panel"
                        print_info "Restarting Cinnamon to apply changes..."
                        nohup cinnamon --replace &>/dev/null &
                    else
                        print_info "Please add manually: Settings → Applets"
                    fi
                fi
            else
                print_info "Please add manually: Settings → Applets → Redragon HS Companion"
            fi
        else
            print_info "Add manually at: Settings → Applets → Redragon HS Companion"
        fi
    else
        print_info "Add the applet to your panel at: Settings → Applets → Redragon HS Companion"
    fi
}

install_plasma_widget() {
    echo
    echo "Installing KDE Plasma widget..."

    if ! command -v plasmashell &> /dev/null; then
        print_info "KDE Plasma not detected, skipping widget installation"
        return
    fi

    local widget_dir="$PLASMA_WIDGET_DIR/redragon-volume-sync@cristiano"
    mkdir -p "$widget_dir"

    cp -r "$SCRIPT_DIR/plasma-widget/"* "$widget_dir/"

    print_success "Plasma widget installed"
    
    # Try to add widget to panel automatically
    if command -v qdbus &> /dev/null || command -v qdbus-qt6 &> /dev/null; then
        echo
        read -p "Do you want to add the widget to your panel now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            # Create a script to add the widget
            local script=$(cat <<'PLASMASCRIPT'
var panel = panels()[0];
var widget = panel.addWidget("redragon-volume-sync@cristiano");
if (widget) {
    widget.currentConfigGroup = ["General"];
}
PLASMASCRIPT
)
            
            # Try to execute the script via plasmashell
            if command -v qdbus-qt6 &> /dev/null; then
                echo "$script" | qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>/dev/null
            elif command -v qdbus &> /dev/null; then
                echo "$script" | qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>/dev/null
            fi
            
            if [ $? -eq 0 ]; then
                print_success "Widget added to panel"
                print_info "The widget should appear in your system tray"
            else
                print_info "Please add manually: Right-click panel → Add Widgets"
            fi
            
            # Offer to reload Plasma
            if command -v kquitapp6 &> /dev/null; then
                echo
                read -p "Do you want to reload Plasma to apply changes? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[SsYy]$ ]]; then
                    print_info "Reloading Plasma..."
                    kquitapp6 plasmashell && nohup plasmashell &>/dev/null &
                    sleep 2
                    print_success "Plasma reloaded"
                fi
            fi
        else
            print_info "Add manually: Right-click panel → Add Widgets → Redragon HS Companion"
        fi
    else
        print_info "Add the widget to your panel: Right-click panel → Add Widgets → Redragon HS Companion"
    fi
}

test_installation() {
    echo
    echo "Testing installation..."

    if "$INSTALL_DIR/redragon_volume_sync.py" status &> /dev/null; then
        print_success "Script working correctly"
    else
        print_error "Error running script"
    fi

    echo
    echo "Checking event support..."
    if command -v alsactl &> /dev/null && command -v udevadm &> /dev/null; then
        print_success "EVENT monitoring available (zero latency)"
    else
        print_info "Using POLLING mode (checks every 2s)"
        if ! command -v alsactl &> /dev/null; then
            print_info "  For events: install alsa-utils"
        fi
        if ! command -v udevadm &> /dev/null; then
            print_info "  For events: systemd should already be installed"
        fi
    fi
}

print_usage_info() {
    local distro=$(detect_distro)
    local pkg_mgr=$(detect_package_manager)
    
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       Installation Complete! 🎉            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Installed on:${NC} $distro (using $pkg_mgr)"
    echo
    echo "Available commands:"
    echo "  redragon-volume status  - Show headset status"
    echo "  redragon-volume get     - Get current volume"
    echo "  redragon-volume 75      - Set volume to 75%"
    echo "  redragon-volume +10     - Increase volume by 10%"
    echo "  redragon-volume -5      - Decrease volume by 5%"
    echo "  redragon-volume mute    - Mute/unmute"
    echo
    
    if command -v systemctl &> /dev/null; then
        echo "Systemd services:"
        echo "  systemctl --user status redragon-volume-sync    - View status"
        echo "  systemctl --user start redragon-volume-sync     - Start"
        echo "  systemctl --user stop redragon-volume-sync      - Stop"
        echo "  systemctl --user enable redragon-volume-sync    - Enable on startup"
        echo
        echo "Logs:"
        echo "  journalctl --user -u redragon-volume-sync -f    - View daemon logs"
    else
        echo -e "${YELLOW}Note:${NC} systemd not available on this system"
        echo "You can run the daemon manually:"
        echo "  ~/.local/bin/redragon_daemon.py &"
    fi
    echo
}

# Main
main() {
    print_header

    check_dependencies
    install_scripts
    install_systemd_service

    # Try to install appropriate extension/applet/widget
    if command -v gnome-shell &> /dev/null; then
        install_gnome_extension
    fi

    if [ "$XDG_CURRENT_DESKTOP" = "X-Cinnamon" ]; then
        install_cinnamon_applet
    fi

    if command -v plasmashell &> /dev/null; then
        install_plasma_widget
    fi

    test_installation
    print_usage_info
}

main "$@"
