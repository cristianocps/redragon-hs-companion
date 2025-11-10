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
        this._isMuted = false;
        this._deviceName = "Redragon";
        this._sinkName = null;
        this._syncTimeout = null;
        this._volumeChangeTimeout = null;
        this._updatingSlider = false;
        this._translator = new Translator();
        this._osdHideTimeout = null;

        // Panel icon (dynamic)
        this._panelIcon = new St.Icon({
            icon_name: 'audio-volume-muted-symbolic',
            style_class: 'system-status-icon',
        });

        this.add_child(this._panelIcon);

        // Volume label next to icon (for OSD effect)
        this._panelLabel = new St.Label({
            text: '',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'system-status-icon',
            visible: false,  // Start hidden
        });
        this.add_child(this._panelLabel);

        // Label de status
        this._statusLabel = new St.Label({
            text: this._translator._('detecting'),
            style_class: 'popup-menu-item',
            style: 'font-size: 9pt;',
        });

        // Menu items
        let statusItem = new PopupMenu.PopupMenuItem('', {
            reactive: false,
            can_focus: false,
        });
        statusItem.add_child(this._statusLabel);
        this.menu.addMenuItem(statusItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Volume display (large and bold)
        this._volumeLabel = new St.Label({
            text: '-- %',
            style: 'font-size: 18pt; font-weight: bold; padding: 6px 0;',
        });

        let volumeItem = new PopupMenu.PopupMenuItem('', {
            reactive: false,
            can_focus: false,
        });
        volumeItem.add_child(this._volumeLabel);
        this.menu.addMenuItem(volumeItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

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

        // Mute/unmute button
        this._muteButton = new PopupMenu.PopupMenuItem('🔇 ' + this._translator._('mute'));
        this._muteButton.connect('activate', () => {
            this._toggleMute();
        });
        this.menu.addMenuItem(this._muteButton);

        // Button to set as default output
        let setDefaultButton = new PopupMenu.PopupMenuItem('🔊 ' + this._translator._('use_as_output'));
        setDefaultButton.connect('activate', () => {
            this._setAsDefaultSink();
        });
        this.menu.addMenuItem(setDefaultButton);

        // Connect scroll event
        this.connect('scroll-event', (actor, event) => {
            return this._onScrollEvent(actor, event);
        });

        // Connect click events (middle and right button for mute)
        this.connect('button-press-event', (actor, event) => {
            let button = event.get_button();
            // Middle button (2) or right button (3) for mute/unmute
            if (button === 2 || button === 3) {
                this._toggleMute();
                return Clutter.EVENT_STOP;
            }
            return Clutter.EVENT_PROPAGATE;
        });

        // Start monitoring
        this._startMonitoring();
    }

    _updateIcon() {
        // Update icon based on volume
        if (this._currentVolume === 0 || this._isMuted) {
            this._panelIcon.icon_name = 'audio-volume-muted-symbolic';
        } else if (this._currentVolume < 33) {
            this._panelIcon.icon_name = 'audio-volume-low-symbolic';
        } else if (this._currentVolume < 66) {
            this._panelIcon.icon_name = 'audio-volume-medium-symbolic';
        } else {
            this._panelIcon.icon_name = 'audio-volume-high-symbolic';
        }
    }

    _showVolumeOSD() {
        // Show volume percentage temporarily next to the icon
        this._panelLabel.text = ` ${this._currentVolume}%`;
        this._panelLabel.visible = true;

        // Clear previous timeout
        if (this._osdHideTimeout) {
            GLib.source_remove(this._osdHideTimeout);
        }

        // Hide after 2 seconds
        this._osdHideTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
            this._panelLabel.text = '';
            this._panelLabel.visible = false;
            this._osdHideTimeout = null;
            return GLib.SOURCE_REMOVE;
        });
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

        // Show OSD with current volume
        this._showVolumeOSD();

        return Clutter.EVENT_STOP;
    }

    _changeVolume(delta) {
        if (!this._isConnected) return;

        let newVolume = Math.max(0, Math.min(100, this._currentVolume + delta));

        if (newVolume !== this._currentVolume) {
            // Update UI immediately
            this._currentVolume = newVolume;
            this._isMuted = (newVolume === 0);
            this._volumeLabel.text = newVolume + ' %';
            this._updateIcon();

            // Update slider
            this._updatingSlider = true;
            this._slider.value = newVolume / 100.0;
            this._updatingSlider = false;

            // Execute command
            try {
                let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
                GLib.spawn_command_line_async(`${scriptPath} ${newVolume}`);
            } catch (e) {
                log(`Redragon: Error adjusting volume: ${e}`);
            }
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
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(`${scriptPath} status`);
            
            if (success) {
                let output = new TextDecoder().decode(stdout);
                // Parse: OK: device=H878 Wireless headset card=3 ...
                let deviceMatch = output.match(/device=([^\s]+(?:\s+[^\s]+)*?)\s+card=/);
                
                if (deviceMatch) {
                    this._deviceName = deviceMatch[1];
                    this._isConnected = true;
                    this._statusLabel.text = '✓ ' + this._deviceName;
                    
                    // Find sink name for setting as default
                    this._findSinkName();
                    this._getVolume();
                } else {
                    this._isConnected = false;
                    this._deviceName = "Redragon";
                    this._statusLabel.text = '❌ ' + this._translator._('not_found');
                }
            }
        } catch (e) {
            log(`Redragon: Error detecting headset: ${e}`);
            this._isConnected = false;
            this._statusLabel.text = '❌ ' + this._translator._('error');
        }
    }

    _findSinkName() {
        try {
            let [success, stdout] = GLib.spawn_command_line_sync('pactl list sinks short');
            if (success) {
                let output = new TextDecoder().decode(stdout);
                let lines = output.split('\n');
                for (let line of lines) {
                    if (line.includes('XiiSound') || line.includes('Weltrend') ||
                        line.includes('Redragon') || line.includes('H878')) {
                        let parts = line.split(/\s+/);
                        if (parts.length >= 2) {
                            this._sinkName = parts[1];
                            break;
                        }
                    }
                }
            }
        } catch (e) {
            log(`Redragon: Error finding sink: ${e}`);
        }
    }

    _getVolume() {
        if (!this._isConnected) return;

        try {
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(`${scriptPath} get`);

            if (success) {
                let output = new TextDecoder().decode(stdout);
                // Parse: Volume: 75%
                let match = output.match(/Volume:\s*(\d+)%/);
                if (match) {
                    this._currentVolume = parseInt(match[1]);
                    this._isMuted = (this._currentVolume === 0);
                    
                    // Update volume label
                    this._volumeLabel.text = this._currentVolume + ' %';
                    
                    // Update icon
                    this._updateIcon();
                    
                    // Update mute button text
                    if (this._isMuted) {
                        this._muteButton.label.text = '🔊 ' + this._translator._('unmute');
                    } else {
                        this._muteButton.label.text = '🔇 ' + this._translator._('mute');
                    }
                    
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

    _toggleMute() {
        if (!this._isConnected) return;

        try {
            let scriptPath = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'redragon-volume']);
            GLib.spawn_command_line_async(`${scriptPath} mute`);
            
            // Update volume after a brief delay
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
                this._getVolume();
                return GLib.SOURCE_REMOVE;
            });
        } catch (e) {
            log(`Redragon: Error toggling mute: ${e}`);
        }
    }

    _setAsDefaultSink() {
        if (!this._isConnected || !this._sinkName) {
            return;
        }

        try {
            GLib.spawn_command_line_async(`pactl set-default-sink ${this._sinkName}`);
            
            let message = this._translator._('set_as_default', {device: this._deviceName});
            GLib.spawn_command_line_async(`notify-send "Redragon Volume" "${message}" -i audio-headphones`);
        } catch (e) {
            log(`Redragon: Error setting default sink: ${e}`);
        }
    }

    _onSliderChanged() {
        if (!this._isConnected || this._updatingSlider) return;

        let volume = Math.round(this._slider.value * 100);
        
        // Immediate visual feedback
        this._currentVolume = volume;
        this._isMuted = (volume === 0);
        this._volumeLabel.text = volume + ' %';
        this._updateIcon();

        // Debounce: only execute command after 20ms without changes
        if (this._volumeChangeTimeout) {
            GLib.source_remove(this._volumeChangeTimeout);
        }

        this._volumeChangeTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 20, () => {
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


    destroy() {
        if (this._syncTimeout) {
            GLib.source_remove(this._syncTimeout);
            this._syncTimeout = null;
        }
        if (this._volumeChangeTimeout) {
            GLib.source_remove(this._volumeChangeTimeout);
            this._volumeChangeTimeout = null;
        }
        if (this._osdHideTimeout) {
            GLib.source_remove(this._osdHideTimeout);
            this._osdHideTimeout = null;
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
