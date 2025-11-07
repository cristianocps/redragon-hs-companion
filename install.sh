#!/bin/bash
# Script de instalação do H878 Volume Sync
# Instala scripts, daemon e extensão/applet

set -e

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

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Redragon HS Companion - Installer        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
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

check_dependencies() {
    echo "Checking dependencies..."

    local missing_deps=()

    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi

    if ! command -v amixer &> /dev/null; then
        missing_deps+=("alsa-utils")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo
        echo "Install with:"
        echo "  sudo apt install ${missing_deps[*]}"
        exit 1
    fi

    print_success "All dependencies installed"
}

install_scripts() {
    echo
    echo "Installing scripts..."

    mkdir -p "$INSTALL_DIR"

    # Install base library (used by daemons)
    cp "$SCRIPT_DIR/redragon_volume_sync.py" "$INSTALL_DIR/"
    print_success "Library installed at $INSTALL_DIR/redragon_volume_sync.py"

    # Install fast bash client (20ms via socket)
    cp "$SCRIPT_DIR/redragon-volume" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon-volume"
    print_success "Fast client installed: redragon-volume"

    # Install PCM sync daemon
    cp "$SCRIPT_DIR/redragon_daemon.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon_daemon.py"
    print_success "Sync daemon installed at $INSTALL_DIR/redragon_daemon.py"

    # Install fast control daemon
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
Description=Redragon Control Daemon - Fast Volume Control Server
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
    cp "$SCRIPT_DIR/gnome-extension/schemas/org.gnome.shell.extensions.redragon-volume-sync.gschema.xml" "$ext_dir/schemas/"

    # Compile schemas
    if [ -d "$ext_dir/schemas" ]; then
        glib-compile-schemas "$ext_dir/schemas/"
        print_success "Schemas compiled"
    fi

    print_success "GNOME extension installed"
    print_info "Enable the extension at: Extensions → Redragon HS Companion"
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
    print_info "Add the applet to your panel at: Settings → Applets → Redragon HS Companion"
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
    print_info "Add the widget to your panel: Right-click panel → Add Widgets → Redragon HS Companion"

    # Try to reload Plasma if possible
    if command -v kquitapp6 &> /dev/null && command -v plasmashell &> /dev/null; then
        print_info "To apply changes, run: kquitapp6 plasmashell && plasmashell &"
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
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       Installation Complete! 🎉            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo
    echo "Available commands:"
    echo "  redragon-volume status  - Show headset status"
    echo "  redragon-volume get     - Get current volume"
    echo "  redragon-volume 75      - Set volume to 75%"
    echo "  redragon-volume +10     - Increase volume by 10%"
    echo "  redragon-volume -5      - Decrease volume by 5%"
    echo "  redragon-volume mute    - Mute/unmute"
    echo
    echo "Systemd services:"
    echo "  systemctl --user status redragon-volume-sync    - View status"
    echo "  systemctl --user start redragon-volume-sync     - Start"
    echo "  systemctl --user stop redragon-volume-sync      - Stop"
    echo "  systemctl --user enable redragon-volume-sync    - Enable on startup"
    echo
    echo "Logs:"
    echo "  journalctl --user -u redragon-volume-sync -f    - View daemon logs"
    echo "  tail -f ~/.local/share/redragon-hs-companion/daemon.log - View local logs"
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
