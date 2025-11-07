/* extension.js
 *
 * Redragon Volume Sync - Extensão GNOME
 * Sincroniza volumes de headsets Redragon sem fio
 */

import GObject from 'gi://GObject';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Slider from 'resource:///org/gnome/shell/ui/slider.js';

const RedragonIndicator = GObject.registerClass(
class RedragonIndicator extends PanelMenu.Button {
    _init(settings, extensionPath) {
        super._init(0.0, 'Redragon Volume Sync');

        this._settings = settings;
        this._extensionPath = extensionPath;
        this._isConnected = false;
        this._currentVolume = 0;
        this._syncTimeout = null;

        // Ícone do painel
        let icon = new St.Icon({
            icon_name: 'audio-headphones-symbolic',
            style_class: 'system-status-icon',
        });

        this.add_child(icon);

        // Label de status
        this._statusLabel = new St.Label({
            text: 'Redragon: Detectando...',
            y_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });

        // Menu items
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        let statusItem = new PopupMenu.PopupMenuItem('', {
            reactive: false,
            can_focus: false,
        });
        statusItem.add_child(this._statusLabel);
        this.menu.addMenuItem(statusItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Botão de sincronização manual
        let syncButton = new PopupMenu.PopupMenuItem('🔄 Sincronizar Agora');
        syncButton.connect('activate', () => {
            this._syncVolumes();
        });
        this.menu.addMenuItem(syncButton);

        // Slider de volume
        this._volumeSlider = new PopupMenu.PopupBaseMenuItem({activate: false});
        let sliderIcon = new St.Icon({
            icon_name: 'audio-volume-high-symbolic',
            style_class: 'popup-menu-icon',
        });
        this._volumeSlider.add_child(sliderIcon);

        this._slider = new Slider.Slider(0);
        this._slider.connect('notify::value', () => {
            this._onSliderChanged();
        });
        this._volumeSlider.add_child(this._slider.actor);
        this.menu.addMenuItem(this._volumeSlider);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Configurações
        let settingsButton = new PopupMenu.PopupMenuItem('⚙️ Configurações');
        settingsButton.connect('activate', () => {
            this._openSettings();
        });
        this.menu.addMenuItem(settingsButton);

        // Iniciar monitoramento
        this._startMonitoring();
    }

    _startMonitoring() {
        // Detecta o headset inicialmente
        this._detectHeadset();

        // Monitora a cada 3 segundos
        this._syncTimeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 3, () => {
            this._checkAndSync();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _detectHeadset() {
        try {
            let [success, stdout, stderr] = GLib.spawn_command_line_sync('aplay -l');
            if (success) {
                let output = new TextDecoder().decode(stdout);
                // Detecta qualquer headset Redragon sem fio
                let patterns = ['H878', 'H848', 'H510', 'Wireless headset', 'XiiSound', 'Weltrend', 'Redragon'];
                this._isConnected = patterns.some(pattern => output.includes(pattern));

                if (this._isConnected) {
                    this._statusLabel.text = 'Redragon: ✓ Conectado';
                    this._getVolume();
                } else {
                    this._statusLabel.text = 'Redragon: ✗ Desconectado';
                }
            }
        } catch (e) {
            log(`Redragon: Erro ao detectar headset: ${e}`);
        }
    }

    _getVolume() {
        if (!this._isConnected) return;

        try {
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(`${scriptPath} status`);

            if (success) {
                let output = new TextDecoder().decode(stdout);
                // Parse volume from status output
                let match = output.match(/PCM Volume.*:\s*(\d+)%/);
                if (match) {
                    this._currentVolume = parseInt(match[1]);
                    this._slider.value = this._currentVolume / 100.0;
                }
            }
        } catch (e) {
            log(`Redragon: Erro ao obter volume: ${e}`);
        }
    }

    _syncVolumes() {
        if (!this._isConnected) {
            Main.notify('Redragon Volume Sync', 'Headset não conectado');
            return;
        }

        try {
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(`${scriptPath} status`);

            if (success) {
                Main.notify('Redragon Volume Sync', 'Volume atualizado!');
                this._getVolume();
            } else {
                Main.notify('Redragon Volume Sync', 'Erro ao atualizar volume');
            }
        } catch (e) {
            log(`Redragon: Erro ao sincronizar: ${e}`);
            Main.notify('Redragon Volume Sync', `Erro: ${e}`);
        }
    }

    _onSliderChanged() {
        if (!this._isConnected) return;

        let volume = Math.round(this._slider.value * 100);

        try {
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            GLib.spawn_command_line_async(`${scriptPath} ${volume}`);
            this._currentVolume = volume;
        } catch (e) {
            log(`Redragon: Erro ao definir volume: ${e}`);
        }
    }

    _checkAndSync() {
        this._detectHeadset();

        if (this._isConnected && this._settings.get_boolean('auto-sync')) {
            this._syncVolumes();
        }
    }

    _openSettings() {
        try {
            Gio.Subprocess.new(
                ['gnome-extensions', 'prefs', 'redragon-volume-sync@cristiano'],
                Gio.SubprocessFlags.NONE
            );
        } catch (e) {
            log(`Redragon: Erro ao abrir configurações: ${e}`);
        }
    }

    destroy() {
        if (this._syncTimeout) {
            GLib.source_remove(this._syncTimeout);
            this._syncTimeout = null;
        }
        super.destroy();
    }
});

export default class RedragonExtension extends Extension {
    enable() {
        log('Redragon Volume Sync: Habilitando extensão');

        this._settings = this.getSettings();
        this._indicator = new RedragonIndicator(this._settings, this.path);
        Main.panel.addToStatusArea('redragon-volume-sync', this._indicator);
    }

    disable() {
        log('Redragon Volume Sync: Desabilitando extensão');

        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }

        this._settings = null;
    }
}
