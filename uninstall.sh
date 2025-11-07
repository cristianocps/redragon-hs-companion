#!/bin/bash
# Uninstallation script for Redragon Volume Sync

set -e

INSTALL_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
GNOME_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
CINNAMON_APPLET_DIR="$HOME/.local/share/cinnamon/applets"
LOG_DIR="$HOME/.local/share/redragon-hs-companion"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

echo "Uninstalling Redragon Volume Sync..."
echo

# Stop and disable the service
if systemctl --user is-active redragon-volume-sync.service &> /dev/null; then
    systemctl --user stop redragon-volume-sync.service
    print_success "Service stopped"
fi

if systemctl --user is-enabled redragon-volume-sync.service &> /dev/null; then
    systemctl --user disable redragon-volume-sync.service
    print_success "Service disabled"
fi

# Remove files
rm -f "$INSTALL_DIR/redragon_volume_sync.py"
rm -f "$INSTALL_DIR/redragon_daemon.py"
rm -f "$INSTALL_DIR/redragon_event_monitor.py"
rm -f "$INSTALL_DIR/redragon-sync"
rm -f "$INSTALL_DIR/redragon-volume"
print_success "Scripts removed"

rm -f "$SYSTEMD_DIR/redragon-volume-sync.service"
systemctl --user daemon-reload
print_success "Systemd service removed"

rm -rf "$GNOME_EXT_DIR/redragon-volume-sync@cristiano"
print_success "GNOME extension removed"

rm -rf "$CINNAMON_APPLET_DIR/redragon-volume-sync@cristiano"
print_success "Cinnamon applet removed"

# Ask about logs
echo
read -p "Also remove logs? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    rm -rf "$LOG_DIR"
    print_success "Logs removed"
fi

echo
echo -e "${GREEN}Redragon Volume Sync uninstalled successfully!${NC}"
