#!/bin/bash
# Uninstallation script for Redragon HS Companion

set -e

INSTALL_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
GNOME_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
CINNAMON_APPLET_DIR="$HOME/.local/share/cinnamon/applets"
PLASMA_WIDGET_DIR="$HOME/.local/share/plasma/plasmoids"
LOG_DIR="$HOME/.local/share/redragon-hs-companion"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Redragon HS Companion - Uninstaller      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo
}

remove_gnome_extension() {
    if [ -d "$GNOME_EXT_DIR/redragon-volume-sync@cristiano" ]; then
        echo "Removing GNOME Shell extension..."
        
        # Disable extension if gnome-extensions is available
        if command -v gnome-extensions &> /dev/null; then
            if gnome-extensions list 2>/dev/null | grep -q "redragon-volume-sync@cristiano"; then
                gnome-extensions disable redragon-volume-sync@cristiano 2>/dev/null || true
                print_info "Extension disabled"
            fi
        fi
        
        rm -rf "$GNOME_EXT_DIR/redragon-volume-sync@cristiano"
        print_success "GNOME extension removed"
    fi
}

remove_cinnamon_applet() {
    if [ -d "$CINNAMON_APPLET_DIR/redragon-volume-sync@cristiano" ]; then
        echo "Removing Cinnamon applet..."
        
        # Remove from enabled applets list
        if command -v dconf &> /dev/null; then
            local current_applets=$(dconf read /org/cinnamon/enabled-applets 2>/dev/null)
            
            if [ -n "$current_applets" ] && [[ "$current_applets" == *"redragon-volume-sync@cristiano"* ]]; then
                # Remove the applet from the list
                local updated_applets=$(echo "$current_applets" | sed "s/, *'[^']*redragon-volume-sync@cristiano[^']*'//g" | sed "s/'[^']*redragon-volume-sync@cristiano[^']*', *//g")
                
                dconf write /org/cinnamon/enabled-applets "$updated_applets" 2>/dev/null || true
                print_info "Applet removed from panel"
                
                # Restart Cinnamon
                if [ "$XDG_CURRENT_DESKTOP" = "X-Cinnamon" ]; then
                    print_info "Restarting Cinnamon to apply changes..."
                    nohup cinnamon --replace &>/dev/null &
                fi
            fi
        fi
        
        rm -rf "$CINNAMON_APPLET_DIR/redragon-volume-sync@cristiano"
        print_success "Cinnamon applet removed"
    fi
}

remove_plasma_widget() {
    if [ -d "$PLASMA_WIDGET_DIR/redragon-volume-sync@cristiano" ]; then
        echo "Removing KDE Plasma widget..."
        
        # Try to remove widget from panel
        if command -v qdbus &> /dev/null || command -v qdbus-qt6 &> /dev/null; then
            local script='
var panels_list = panels();
for (var i = 0; i < panels_list.length; i++) {
    var panel = panels_list[i];
    var widgets = panel.widgets();
    for (var j = 0; j < widgets.length; j++) {
        if (widgets[j].type === "redragon-volume-sync@cristiano") {
            widgets[j].remove();
        }
    }
}
'
            
            if command -v qdbus-qt6 &> /dev/null; then
                qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>/dev/null || true
            elif command -v qdbus &> /dev/null; then
                qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>/dev/null || true
            fi
            
            print_info "Widget removed from panel"
        fi
        
        rm -rf "$PLASMA_WIDGET_DIR/redragon-volume-sync@cristiano"
        print_success "Plasma widget removed"
    fi
}

main() {
    print_header
    
    echo "This will remove Redragon HS Companion from your system."
    echo
    read -p "Continue? (y/n) " -n 1 -r
    echo
    echo
    
    if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    # Stop and disable services
    echo "Stopping services..."
    
    if systemctl --user is-active redragon-volume-sync.service &> /dev/null; then
        systemctl --user stop redragon-volume-sync.service
        print_success "Volume sync service stopped"
    fi
    
    if systemctl --user is-active redragon-control-daemon.service &> /dev/null; then
        systemctl --user stop redragon-control-daemon.service
        print_success "Control daemon stopped"
    fi
    
    if systemctl --user is-enabled redragon-volume-sync.service &> /dev/null; then
        systemctl --user disable redragon-volume-sync.service
        print_success "Volume sync service disabled"
    fi
    
    if systemctl --user is-enabled redragon-control-daemon.service &> /dev/null; then
        systemctl --user disable redragon-control-daemon.service
        print_success "Control daemon disabled"
    fi
    
    echo
    
    # Remove scripts
    echo "Removing scripts..."
    rm -f "$INSTALL_DIR/redragon_volume_sync.py"
    rm -f "$INSTALL_DIR/redragon_daemon.py"
    rm -f "$INSTALL_DIR/redragon_control_daemon.py"
    rm -f "$INSTALL_DIR/redragon-volume"
    print_success "Scripts removed"
    
    echo
    
    # Remove systemd services
    echo "Removing systemd services..."
    rm -f "$SYSTEMD_DIR/redragon-volume-sync.service"
    rm -f "$SYSTEMD_DIR/redragon-control-daemon.service"
    systemctl --user daemon-reload
    print_success "Systemd services removed"
    
    echo
    
    # Remove desktop widgets
    remove_gnome_extension
    echo
    remove_cinnamon_applet
    echo
    remove_plasma_widget
    
    # Ask about logs
    echo
    read -p "Also remove logs? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        rm -rf "$LOG_DIR"
        print_success "Logs removed"
    fi
    
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Uninstallation Complete!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo
    print_info "Redragon HS Companion has been removed from your system."
    echo
}

main "$@"
