#!/bin/bash
# Script de desinstalação do Redragon Volume Sync

set -e

INSTALL_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
GNOME_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
CINNAMON_APPLET_DIR="$HOME/.local/share/cinnamon/applets"
LOG_DIR="$HOME/.local/share/h878-fixer"

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

echo "Desinstalando Redragon Volume Sync..."
echo

# Para e desabilita o serviço
if systemctl --user is-active redragon-volume-sync.service &> /dev/null; then
    systemctl --user stop redragon-volume-sync.service
    print_success "Serviço parado"
fi

if systemctl --user is-enabled redragon-volume-sync.service &> /dev/null; then
    systemctl --user disable redragon-volume-sync.service
    print_success "Serviço desabilitado"
fi

# Remove arquivos
rm -f "$INSTALL_DIR/redragon_volume_sync.py"
rm -f "$INSTALL_DIR/redragon_daemon.py"
rm -f "$INSTALL_DIR/redragon_event_monitor.py"
rm -f "$INSTALL_DIR/redragon-sync"
rm -f "$INSTALL_DIR/redragon-volume"
print_success "Scripts removidos"

rm -f "$SYSTEMD_DIR/redragon-volume-sync.service"
systemctl --user daemon-reload
print_success "Serviço systemd removido"

rm -rf "$GNOME_EXT_DIR/redragon-volume-sync@cristiano"
print_success "Extensão GNOME removida"

rm -rf "$CINNAMON_APPLET_DIR/redragon-volume-sync@cristiano"
print_success "Applet Cinnamon removido"

# Pergunta sobre logs
echo
read -p "Remover logs também? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    rm -rf "$LOG_DIR"
    print_success "Logs removidos"
fi

echo
echo -e "${GREEN}Redragon Volume Sync desinstalado com sucesso!${NC}"
