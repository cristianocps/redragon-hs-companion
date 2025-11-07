#!/bin/bash
# Script de instalação do H878 Volume Sync
# Instala scripts, daemon e extensão/applet

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
GNOME_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
CINNAMON_APPLET_DIR="$HOME/.local/share/cinnamon/applets"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Redragon Volume Sync - Instalador        ║${NC}"
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
    echo "Verificando dependências..."

    local missing_deps=()

    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi

    if ! command -v amixer &> /dev/null; then
        missing_deps+=("alsa-utils")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Dependências faltando: ${missing_deps[*]}"
        echo
        echo "Instale com:"
        echo "  sudo apt install ${missing_deps[*]}"
        exit 1
    fi

    print_success "Todas as dependências instaladas"
}

install_scripts() {
    echo
    echo "Instalando scripts..."

    mkdir -p "$INSTALL_DIR"

    # Instala script principal
    cp "$SCRIPT_DIR/redragon_volume_sync.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon_volume_sync.py"
    print_success "Script CLI instalado em $INSTALL_DIR/redragon_volume_sync.py"

    # Cria link simbólico
    if [ ! -L "$INSTALL_DIR/redragon-sync" ]; then
        ln -s "$INSTALL_DIR/redragon_volume_sync.py" "$INSTALL_DIR/redragon-sync"
        print_success "Link simbólico criado: redragon-sync"
    fi

    # Instala script de controle de volume
    cp "$SCRIPT_DIR/redragon-volume" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon-volume"
    print_success "Script de controle instalado em $INSTALL_DIR/redragon-volume"

    # Instala daemon
    cp "$SCRIPT_DIR/redragon_daemon.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon_daemon.py"
    print_success "Daemon instalado em $INSTALL_DIR/redragon_daemon.py"

    # Instala monitor de eventos
    cp "$SCRIPT_DIR/redragon_event_monitor.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/redragon_event_monitor.py"
    print_success "Monitor de eventos instalado em $INSTALL_DIR/redragon_event_monitor.py"
}

install_systemd_service() {
    echo
    echo "Instalando serviço systemd..."

    mkdir -p "$SYSTEMD_DIR"

    # Cria arquivo de serviço com path correto
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

    print_success "Serviço systemd instalado"

    # Recarrega systemd
    systemctl --user daemon-reload
    print_success "Systemd recarregado"

    # Pergunta se deseja habilitar o serviço
    echo
    read -p "Deseja habilitar o serviço para iniciar automaticamente? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        systemctl --user enable redragon-volume-sync.service
        systemctl --user start redragon-volume-sync.service
        print_success "Serviço habilitado e iniciado"
    else
        print_info "Você pode iniciar o serviço manualmente com:"
        print_info "  systemctl --user start redragon-volume-sync.service"
    fi
}

install_gnome_extension() {
    echo
    echo "Instalando extensão GNOME Shell..."

    if ! command -v gnome-shell &> /dev/null; then
        print_info "GNOME Shell não detectado, pulando instalação da extensão"
        return
    fi

    local ext_dir="$GNOME_EXT_DIR/redragon-volume-sync@cristiano"
    mkdir -p "$ext_dir"
    mkdir -p "$ext_dir/schemas"

    cp "$SCRIPT_DIR/gnome-extension/metadata.json" "$ext_dir/"
    cp "$SCRIPT_DIR/gnome-extension/extension.js" "$ext_dir/"
    cp "$SCRIPT_DIR/gnome-extension/schemas/org.gnome.shell.extensions.redragon-volume-sync.gschema.xml" "$ext_dir/schemas/"

    # Compila schemas
    if [ -d "$ext_dir/schemas" ]; then
        glib-compile-schemas "$ext_dir/schemas/"
        print_success "Schemas compilados"
    fi

    print_success "Extensão GNOME instalada"
    print_info "Habilite a extensão em: Extensões → Redragon Volume Sync"
}

install_cinnamon_applet() {
    echo
    echo "Instalando applet Cinnamon..."

    if [ "$XDG_CURRENT_DESKTOP" != "X-Cinnamon" ]; then
        print_info "Cinnamon não detectado, pulando instalação do applet"
        return
    fi

    local applet_dir="$CINNAMON_APPLET_DIR/redragon-volume-sync@cristiano"
    mkdir -p "$applet_dir"

    cp "$SCRIPT_DIR/cinnamon-applet/metadata.json" "$applet_dir/"
    cp "$SCRIPT_DIR/cinnamon-applet/applet.js" "$applet_dir/"

    print_success "Applet Cinnamon instalado"
    print_info "Adicione o applet ao painel em: Configurações → Applets → Redragon Volume Sync"
}

test_installation() {
    echo
    echo "Testando instalação..."

    if "$INSTALL_DIR/redragon_volume_sync.py" status &> /dev/null; then
        print_success "Script funcionando corretamente"
    else
        print_error "Erro ao executar script"
    fi

    echo
    echo "Verificando suporte a eventos..."
    if command -v alsactl &> /dev/null && command -v udevadm &> /dev/null; then
        print_success "Monitoramento por EVENTOS disponível (zero latência)"
    else
        print_info "Usando modo POLLING (verifica a cada 2s)"
        if ! command -v alsactl &> /dev/null; then
            print_info "  Para eventos: instale alsa-utils"
        fi
        if ! command -v udevadm &> /dev/null; then
            print_info "  Para eventos: systemd já deve estar instalado"
        fi
    fi
}

print_usage_info() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       Instalação Concluída! 🎉            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo
    echo "Comandos disponíveis:"
    echo "  redragon-sync status    - Mostra status do headset"
    echo "  redragon-sync sync      - Sincroniza volumes"
    echo "  redragon-sync set 75    - Define volume para 75%"
    echo
    echo "Controle de volume (para saída analógica):"
    echo "  redragon-volume 75      - Define volume para 75%"
    echo "  redragon-volume up      - Aumenta 5%"
    echo "  redragon-volume down    - Diminui 5%"
    echo "  redragon-volume mute    - Muta/desmuta"
    echo
    echo "Serviço systemd:"
    echo "  systemctl --user status redragon-volume-sync    - Ver status"
    echo "  systemctl --user start redragon-volume-sync     - Iniciar"
    echo "  systemctl --user stop redragon-volume-sync      - Parar"
    echo "  systemctl --user enable redragon-volume-sync    - Habilitar na inicialização"
    echo
    echo "Logs:"
    echo "  journalctl --user -u redragon-volume-sync -f    - Ver logs do daemon"
    echo "  tail -f ~/.local/share/h878-fixer/daemon.log - Ver logs locais"
    echo
}

# Main
main() {
    print_header

    check_dependencies
    install_scripts
    install_systemd_service

    # Tenta instalar extensão/applet apropriado
    if command -v gnome-shell &> /dev/null; then
        install_gnome_extension
    fi

    if [ "$XDG_CURRENT_DESKTOP" = "X-Cinnamon" ]; then
        install_cinnamon_applet
    fi

    test_installation
    print_usage_info
}

main "$@"
