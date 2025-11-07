/* extension.js
 *
 * Redragon Volume Sync - GNOME extension
 * Synchronizes volumes of Redragon wireless headsets
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

import {Translator} from './translations.js';

const RedragonIndicator = GObject.registerClass(
class RedragonIndicator extends PanelMenu.Button {
    _init(settings, extensionPath) {
        super._init(0.0, 'Redragon Volume Sync');

        this._settings = settings;
        this._extensionPath = extensionPath;
        this._isConnected = false;
        this._currentVolume = 0;
        this._syncTimeout = null;
        this._volumeChangeTimeout = null;
        this._updatingSlider = false;
        this._translator = new Translator();

        // Panel icon
        let icon = new St.Icon({
            icon_name: 'audio-headphones-symbolic',
            style_class: 'system-status-icon',
        });

        this.add_child(icon);

        // Label de status
        this._statusLabel = new St.Label({
            text: 'Redragon: ' + this._translator._('detecting'),
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

        // Manual synchronization button
        let syncButton = new PopupMenu.PopupMenuItem('🔄 ' + this._translator._('synchronize_now'));
        syncButton.connect('activate', () => {
            this._syncVolumes();
        });
        this.menu.addMenuItem(syncButton);

        // Volume slider
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

        // Settings
        let settingsButton = new PopupMenu.PopupMenuItem('⚙️ ' + this._translator._('settings'));
        settingsButton.connect('activate', () => {
            this._openSettings();
        });
        this.menu.addMenuItem(settingsButton);

        // Connect scroll event
        this.connect('scroll-event', (actor, event) => {
            return this._onScrollEvent(actor, event);
        });

        // Start monitoring
        this._startMonitoring();
    }

    _onScrollEvent(actor, event) {
        if (!this._isConnected) return Clutter.EVENT_PROPAGATE;

        let direction = event.get_scroll_direction();
        let delta = 5;

        if (direction === Clutter.ScrollDirection.UP) {
            this._changeVolume(delta);
        } else if (direction === Clutter.ScrollDirection.DOWN) {
            this._changeVolume(-delta);
        }

        return Clutter.EVENT_STOP;
    }

    _changeVolume(delta) {
        if (!this._isConnected) return;

        let newVolume = Math.max(0, Math.min(100, this._currentVolume + delta));

        try {
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            GLib.spawn_command_line_async(`${scriptPath} ${newVolume}`);
            this._currentVolume = newVolume;
            this._slider.value = newVolume / 100.0;
            // Schedule update after a brief delay to confirm
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
                this._getVolume();
                return GLib.SOURCE_REMOVE;
            });
        } catch (e) {
            log(`Redragon: Error adjusting volume: ${e}`);
        }
    }

    _startMonitoring() {
        // Detect the headset initially
        this._detectHeadset();

        // Monitor every 2 seconds
        this._syncTimeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
            // Update the volume whenever the headset is connected
            if (this._isConnected) {
                this._getVolume();
            } else {
                // If not connected, try to detect
                this._detectHeadset();
            }
            return GLib.SOURCE_CONTINUE;
        });
    }

    _detectHeadset() {
        try {
            let [success, stdout, stderr] = GLib.spawn_command_line_sync('aplay -l');
            if (success) {
                let output = new TextDecoder().decode(stdout);
                // Detect any Redragon wireless headset
                let patterns = ['H878', 'H848', 'H510', 'Wireless headset', 'XiiSound', 'Weltrend', 'Redragon'];
                this._isConnected = patterns.some(pattern => output.includes(pattern));

                if (this._isConnected) {
                    this._statusLabel.text = 'Redragon: ✓ ' + this._translator._('connected');
                    this._getVolume();
                } else {
                    this._statusLabel.text = 'Redragon: ✗ ' + this._translator._('disconnected');
                }
            }
        } catch (e) {
            log(`Redragon: Error detecting headset: ${e}`);
        }
    }

    _getVolume() {
        if (!this._isConnected) return;

        try {
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(`${scriptPath} status`);

            if (success) {
                let output = new TextDecoder().decode(stdout);
                // Search for the Effective Volume (PCM[1] - real control)
                let match = output.match(/Volume Efetivo:\s*(\d+)%/);
                if (match) {
                    this._currentVolume = parseInt(match[1]);
                    // Update slider without triggering event
                    this._updatingSlider = true;
                    this._slider.value = this._currentVolume / 100.0;
                    this._updatingSlider = false;
                }
            }
        } catch (e) {
            log(`Redragon: Error getting volume: ${e}`);
        }
    }

    _syncVolumes() {
        if (!this._isConnected) {
            Main.notify('Redragon Volume Sync', this._translator._('headset_not_connected'));
            return;
        }

        try {
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(`${scriptPath} status`);

            if (success) {
                Main.notify('Redragon Volume Sync', this._translator._('volume_updated'));
                this._getVolume();
            } else {
                Main.notify('Redragon Volume Sync', this._translator._('error_updating'));
            }
        } catch (e) {
            log(`Redragon: Error synchronizing: ${e}`);
            Main.notify('Redragon Volume Sync', this._translator._('error') + `: ${e}`);
        }
    }

    _onSliderChanged() {
        if (!this._isConnected || this._updatingSlider) return;

        let volume = Math.round(this._slider.value * 100);
        this._currentVolume = volume;

        // Debounce: only execute command after 100ms without changes
        if (this._volumeChangeTimeout) {
            GLib.source_remove(this._volumeChangeTimeout);
        }

        this._volumeChangeTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
            this._volumeChangeTimeout = null;
            try {
                let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
                GLib.spawn_command_line_async(`${scriptPath} ${volume}`);
            } catch (e) {
                log(`Redragon: Error setting volume: ${e}`);
            }
            return GLib.SOURCE_REMOVE;
        });
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
            log(`Redragon: Error opening settings: ${e}`);
        }
    }

    destroy() {
        if (this._syncTimeout) {
            GLib.source_remove(this._syncTimeout);
            this._syncTimeout = null;
        }
        if (this._volumeChangeTimeout) {
            GLib.source_remove(this._volumeChangeTimeout);
            this._volumeChangeTimeout = null;
        }
        super.destroy();
    }
});

export default class RedragonExtension extends Extension {
    enable() {
        log('Redragon Volume Sync: Enabling extension');

        this._settings = this.getSettings();
        this._indicator = new RedragonIndicator(this._settings, this.path);
        Main.panel.addToStatusArea('redragon-volume-sync', this._indicator);
    }

    disable() {
        log('Redragon Volume Sync: Disabling extension');

        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }

        this._settings = null;
    }
}
