#!/bin/bash
# Flatpak setup script for Redragon HS Companion
# This script helps users set up the daemons and extensions after Flatpak installation

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

echo "================================================"
echo "  Redragon HS Companion - Flatpak Setup"
echo "================================================"
echo

print_info "Flatpak applications run in a sandbox with limited system access."
print_info "For full functionality, we need to install scripts to your system."
echo

# Check if running inside Flatpak
if [ -n "$FLATPAK_ID" ]; then
    SCRIPT_DIR="/app/bin"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

INSTALL_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$SYSTEMD_DIR"

echo "Installing scripts to $INSTALL_DIR..."

# Copy scripts from Flatpak to user directory
cp "$SCRIPT_DIR/redragon_volume_sync.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/redragon_daemon.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/redragon_control_daemon.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/redragon-volume" "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR/redragon_daemon.py"
chmod +x "$INSTALL_DIR/redragon_control_daemon.py"
chmod +x "$INSTALL_DIR/redragon-volume"

print_success "Scripts installed"

# Create systemd services
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

[Install]
WantedBy=default.target
EOF

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

[Install]
WantedBy=default.target
EOF

print_success "Systemd services created"

# Reload systemd
systemctl --user daemon-reload
print_success "Systemd reloaded"

echo
read -p "Do you want to enable and start the services now? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl --user enable redragon-volume-sync.service
    systemctl --user enable redragon-control-daemon.service
    systemctl --user start redragon-volume-sync.service
    systemctl --user start redragon-control-daemon.service
    print_success "Services enabled and started"
else
    print_info "You can start the services later with:"
    print_info "  systemctl --user start redragon-volume-sync.service"
    print_info "  systemctl --user start redragon-control-daemon.service"
fi

echo
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo
echo "Desktop Integration:"
echo

# Check for desktop environments
if command -v gnome-shell &> /dev/null; then
    print_info "GNOME Shell detected"
    print_info "Extension installed at: ~/.local/share/gnome-shell/extensions/"
    print_info "Enable it in: Extensions → Redragon HS Companion"

    # Try to copy extension from Flatpak
    if [ -d "/app/share/gnome-shell/extensions/redragon-volume-sync@cristiano" ]; then
        mkdir -p "$HOME/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano"
        cp -r /app/share/gnome-shell/extensions/redragon-volume-sync@cristiano/* \
             "$HOME/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano/"
        print_success "GNOME extension copied to user directory"
    fi
fi

if [ "$XDG_CURRENT_DESKTOP" = "X-Cinnamon" ]; then
    print_info "Cinnamon detected"
    print_info "Applet installed at: ~/.local/share/cinnamon/applets/"
    print_info "Add it in: Settings → Applets → Redragon HS Companion"

    # Try to copy applet from Flatpak
    if [ -d "/app/share/cinnamon/applets/redragon-volume-sync@cristiano" ]; then
        mkdir -p "$HOME/.local/share/cinnamon/applets/redragon-volume-sync@cristiano"
        cp -r /app/share/cinnamon/applets/redragon-volume-sync@cristiano/* \
             "$HOME/.local/share/cinnamon/applets/redragon-volume-sync@cristiano/"
        print_success "Cinnamon applet copied to user directory"
    fi
fi

if command -v plasmashell &> /dev/null; then
    print_info "KDE Plasma detected"
    print_info "Widget installed at: ~/.local/share/plasma/plasmoids/"
    print_info "Add it: Right-click panel → Add Widgets → Redragon HS Companion"

    # Try to copy widget from Flatpak
    if [ -d "/app/share/plasma/plasmoids/redragon-volume-sync@cristiano" ]; then
        mkdir -p "$HOME/.local/share/plasma/plasmoids/redragon-volume-sync@cristiano"
        cp -r /app/share/plasma/plasmoids/redragon-volume-sync@cristiano/* \
             "$HOME/.local/share/plasma/plasmoids/redragon-volume-sync@cristiano/"
        print_success "Plasma widget copied to user directory"
    fi
fi

echo
echo "Available commands:"
echo "  redragon-volume status  - Show headset status"
echo "  redragon-volume 75      - Set volume to 75%"
echo "  redragon-volume mute    - Mute/unmute"
echo
