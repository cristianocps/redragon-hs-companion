#!/bin/bash
# Redragon Volume Sync - Post-Install GUI
# Este script é executado quando o usuário abre a aplicação via menu

set -e

DIALOG_CMD=""

# Detecta qual ferramenta de diálogo está disponível
if command -v zenity &> /dev/null; then
    DIALOG_CMD="zenity"
elif command -v kdialog &> /dev/null; then
    DIALOG_CMD="kdialog"
else
    # Fallback para terminal
    echo "⚠️  Nenhuma ferramenta de diálogo GUI encontrada"
    echo "Executando instalação via terminal..."
    exec x-terminal-emulator -e "$0" --terminal
fi

show_info() {
    if [ "$DIALOG_CMD" = "zenity" ]; then
        zenity --info --title="Redragon Volume Sync" --text="$1" --width=400
    elif [ "$DIALOG_CMD" = "kdialog" ]; then
        kdialog --msgbox "$1" --title "Redragon Volume Sync"
    else
        echo "$1"
    fi
}

show_question() {
    if [ "$DIALOG_CMD" = "zenity" ]; then
        zenity --question --title="Redragon Volume Sync" --text="$1" --width=400
    elif [ "$DIALOG_CMD" = "kdialog" ]; then
        kdialog --yesno "$1" --title "Redragon Volume Sync"
    else
        read -p "$1 (s/n) " -n 1 -r
        echo
        [[ $REPLY =~ ^[SsYy]$ ]]
    fi
}

show_error() {
    if [ "$DIALOG_CMD" = "zenity" ]; then
        zenity --error --title="Redragon Volume Sync" --text="$1" --width=400
    elif [ "$DIALOG_CMD" = "kdialog" ]; then
        kdialog --error "$1" --title "Redragon Volume Sync"
    else
        echo "ERRO: $1"
    fi
}

# Detecta headset
detect_headset() {
    if aplay -l 2>/dev/null | grep -qE 'H[0-9]{3}|Redragon|XiiSound|Weltrend'; then
        return 0
    fi
    return 1
}

# Instalação
install_files() {
    show_info "Bem-vindo ao Redragon Volume Sync!\n\nEste assistente irá configurar o sincronizador de volume para headsets Redragon sem fio.\n\nO que será instalado:\n• Scripts CLI (~/.local/bin)\n• Serviço systemd\n• Extensão GNOME/Applet Cinnamon"

    if ! detect_headset; then
        show_error "Nenhum headset Redragon detectado!\n\nPor favor, conecte seu headset e tente novamente."
        exit 1
    fi

    if ! show_question "Headset Redragon detectado!\n\nDeseja prosseguir com a instalação?"; then
        exit 0
    fi

    # Criar diretórios
    mkdir -p ~/.local/bin
    mkdir -p ~/.config/systemd/user

    # Copiar scripts
    cp /app/bin/redragon_volume_sync.py ~/.local/bin/
    cp /app/bin/redragon_daemon.py ~/.local/bin/
    cp /app/bin/redragon_event_monitor.py ~/.local/bin/
    cp /app/bin/redragon-volume ~/.local/bin/
    cp /app/bin/configure-pipewire.sh ~/.local/bin/

    chmod +x ~/.local/bin/redragon*.py ~/.local/bin/redragon-volume ~/.local/bin/configure-pipewire.sh

    # Criar symlink
    ln -sf ~/.local/bin/redragon_volume_sync.py ~/.local/bin/redragon-sync

    # Copiar serviço systemd
    cp /app/share/redragon-volume-sync/redragon-volume-sync.service ~/.config/systemd/user/

    # Perguntar sobre iniciar serviço
    if show_question "Deseja iniciar o serviço systemd automaticamente na inicialização?"; then
        systemctl --user daemon-reload
        systemctl --user enable redragon-volume-sync.service
        systemctl --user start redragon-volume-sync.service
    fi

    # Instalar extensão GNOME se disponível
    if command -v gnome-shell &> /dev/null; then
        if show_question "GNOME Shell detectado!\n\nDeseja instalar a extensão GNOME?"; then
            mkdir -p ~/.local/share/gnome-shell/extensions
            cp -r /app/share/gnome-shell/extensions/redragon-volume-sync@cristiano \
                 ~/.local/share/gnome-shell/extensions/
            show_info "Extensão GNOME instalada!\n\nHabilite em: Extensões → Redragon Volume Sync"
        fi
    fi

    # Instalar applet Cinnamon se disponível
    if [ "$XDG_CURRENT_DESKTOP" = "X-Cinnamon" ]; then
        if show_question "Cinnamon Desktop detectado!\n\nDeseja instalar o applet?"; then
            mkdir -p ~/.local/share/cinnamon/applets
            cp -r /app/share/cinnamon/applets/redragon-volume-sync@cristiano \
                 ~/.local/share/cinnamon/applets/
            show_info "Applet Cinnamon instalado!\n\nAdicione em: Configurações → Applets"
        fi
    fi

    # Sucesso
    show_info "✅ Instalação concluída com sucesso!\n\nComandos disponíveis:\n• redragon-sync status\n• redragon-volume 75\n• redragon-volume up/down\n\nDocumentação: /app/share/doc/redragon-volume-sync/"

    # Perguntar se quer abrir a documentação
    if show_question "Deseja ver a documentação?"; then
        if command -v xdg-open &> /dev/null; then
            xdg-open /app/share/doc/redragon-volume-sync/README.md &
        fi
    fi
}

# Verificar se já está instalado
if [ -f ~/.local/bin/redragon_volume_sync.py ]; then
    if show_question "Os scripts já parecem estar instalados.\n\nDeseja reinstalar?"; then
        install_files
    else
        show_info "Para usar os comandos:\n• redragon-sync status\n• redragon-volume 75\n\nDocumentação: /app/share/doc/redragon-volume-sync/"
    fi
else
    install_files
fi
