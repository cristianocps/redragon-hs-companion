const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const St = imports.gi.St;
const GLib = imports.gi.GLib;
const Mainloop = imports.mainloop;
const Util = imports.misc.util;

class RedragonVolumeApplet extends Applet.TextIconApplet {
    constructor(metadata, orientation, panel_height, instance_id) {
        super(orientation, panel_height, instance_id);

        this.metadata = metadata;
        this.orientation = orientation;

        try {
            // State
            this.isConnected = false;
            this.deviceName = "Redragon";
            this.sinkName = null;
            this.currentVolume = 0;
            this.isMuted = false;
            this._updatingSlider = false;
            this._volumeChangeTimeout = null;
            this._monitoringTimeout = null;

            // Script path
            this.scriptPath = GLib.get_home_dir() + '/.local/bin/redragon-volume';
            this.scriptAvailable = GLib.file_test(this.scriptPath, GLib.FileTest.EXISTS);

            // Define initial icon
            this._updateIcon();
            this.set_applet_tooltip("Redragon Volume Control");

            // Create menu
            this.menuManager = new PopupMenu.PopupMenuManager(this);
            this.menu = new Applet.AppletPopupMenu(this, orientation);
            this.menuManager.addMenu(this.menu);

            this._buildMenu();

            // Connect events
            this.actor.connect('scroll-event', (actor, event) => {
                return this.onScrollEvent(actor, event);
            });

            // Start monitoring
            this.detectDevice();
            this.startMonitoring();

        } catch (e) {
            global.logError("Redragon: Applet error: " + e);
        }
    }

    _buildMenu() {
        // Status compact - uses simple label in item
        let statusItem = new PopupMenu.PopupMenuItem("Detectando...", { reactive: false });
        statusItem.label.style = "font-size: 9pt;";
        this.statusLabel = statusItem.label;
        this.menu.addMenuItem(statusItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Volume large and compact - uses simple label in item
        let volumeItem = new PopupMenu.PopupMenuItem("-- %", { reactive: false });
        volumeItem.label.style = "font-size: 18pt; font-weight: bold; padding: 6px 0;";
        this.volumeLabel = volumeItem.label;
        this.menu.addMenuItem(volumeItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Volume slider
        this.volumeSlider = new PopupMenu.PopupSliderMenuItem(0);
        this.volumeSlider.connect('value-changed', (slider, value) => {
            this.onSliderChanged(value);
        });
        this.menu.addMenuItem(this.volumeSlider);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Mute/unmute button
        this.muteItem = new PopupMenu.PopupMenuItem("🔇 Mutar");
        this.muteItem.connect('activate', () => {
            this.toggleMute();
        });
        this.menu.addMenuItem(this.muteItem);

        // Button to set as default output
        let setDefaultItem = new PopupMenu.PopupMenuItem("🔊 Usar como saída de áudio");
        setDefaultItem.connect('activate', () => {
            this.setAsDefaultSink();
        });
        this.menu.addMenuItem(setDefaultItem);
    }

    _updateIcon() {
        // Update icon based on volume
        if (this.currentVolume === 0 || this.isMuted) {
            this.set_applet_icon_symbolic_name("audio-volume-muted-symbolic");
        } else if (this.currentVolume < 33) {
            this.set_applet_icon_symbolic_name("audio-volume-low-symbolic");
        } else if (this.currentVolume < 66) {
            this.set_applet_icon_symbolic_name("audio-volume-medium-symbolic");
        } else {
            this.set_applet_icon_symbolic_name("audio-volume-high-symbolic");
        }
    }

    onScrollEvent(actor, event) {
        if (!this.isConnected) return false;

        let direction = event.get_scroll_direction();
        let delta = 5;

        if (direction == 0) { // Scroll up
            this.changeVolume(delta);
        } else if (direction == 1) { // Scroll down
            this.changeVolume(-delta);
        }

        return true;
    }

    on_applet_clicked(event) {
        let button = event.get_button();

        // Left click: toggle menu
        if (button === 1) {
            this.menu.toggle();
        }
        // Middle click: mute/unmute
        else if (button === 2) {
            this.toggleMute();
            return true;
        }
        // Right click: also mute (alternative)
        else if (button === 3) {
            this.toggleMute();
            return true;
        }
    }

    toggleMute() {
        if (!this.isConnected) return;

        try {
            Util.spawn_async([this.scriptPath, 'mute'], () => {
                // After muting, update the volume
                Mainloop.timeout_add(100, () => {
                    this.updateVolume();
                    return false;
                });
            });
        } catch (e) {
            global.logError("Redragon: Error muting: " + e);
        }
    }

    detectDevice() {
        if (!this.scriptAvailable) {
            this.statusLabel.set_text("❌ Script not installed");
            this.isConnected = false;
            return;
        }

        try {
            Util.spawn_async([this.scriptPath, 'status'], (stdout) => {
                let output = stdout.toString();

                // Parse: OK: device=H878 Wireless headset card=3 ...
                let deviceMatch = output.match(/device=([^\s]+(?:\s+[^\s]+)*?)\s+card=/);
                if (deviceMatch) {
                    this.deviceName = deviceMatch[1];
                    this.isConnected = true;
                    this.statusLabel.set_text("✓ " + this.deviceName);

                    // Search for the sink name to be able to set as default
                    this._findSinkName();

                    this.updateVolume();
                } else {
                    this.isConnected = false;
                    this.statusLabel.set_text("❌ Not found");
                }
            });
        } catch (e) {
            global.logError("Redragon: Error detecting: " + e);
            this.isConnected = false;
            this.statusLabel.set_text("❌ Erro");
        }
    }

    _findSinkName() {
        try {
            let [success, stdout] = GLib.spawn_command_line_sync('pactl list sinks short');
            if (success) {
                let output = stdout.toString();
                // Search for line containing XiiSound, Weltrend, Redragon or H878
                let lines = output.split('\n');
                for (let line of lines) {
                    if (line.includes('XiiSound') || line.includes('Weltrend') ||
                        line.includes('Redragon') || line.includes('H878')) {
                        // Formato: ID  NAME  MODULE  ...
                        let parts = line.split(/\s+/);
                        if (parts.length >= 2) {
                            this.sinkName = parts[1];
                            break;
                        }
                    }
                }
            }
        } catch (e) {
            global.logError("Redragon: Error searching sink: " + e);
        }
    }

    setAsDefaultSink() {
        if (!this.isConnected || !this.sinkName) {
            return;
        }

        try {
            Util.spawn_async(['pactl', 'set-default-sink', this.sinkName], () => {
                // Show success notification
                Util.spawnCommandLine('notify-send "Redragon Volume" "' +
                    this.deviceName + ' set as default output" -i audio-headphones');
            });
        } catch (e) {
            global.logError("Redragon: Error setting default sink: " + e);
        }
    }

    updateVolume() {
        if (!this.isConnected) return;

        try {
            Util.spawn_async([this.scriptPath, 'get'], (stdout) => {
                let output = stdout.toString();
                let match = output.match(/Volume:\s*(\d+)%/);
                if (match) {
                    this.currentVolume = parseInt(match[1]);
                    this.isMuted = (this.currentVolume === 0);

                    this.volumeLabel.set_text(this.currentVolume + " %");
                    this.set_applet_label(this.currentVolume + "%");
                    this._updateIcon();

                    // Update mute button text
                    if (this.muteItem) {
                        this.muteItem.label.set_text(this.isMuted ? "🔊 Desmutar" : "🔇 Mutar");
                    }

                    // Update slider without triggering event
                    this._updatingSlider = true;
                    this.volumeSlider.setValue(this.currentVolume / 100.0);
                    this._updatingSlider = false;
                }
            });
        } catch (e) {
            global.logError("Redragon: Error getting volume: " + e);
        }
    }

    onSliderChanged(value) {
        if (this._updatingSlider || !this.isConnected) return;

        let volume = Math.round(value * 100);

        // Immediate visual feedback
        this.currentVolume = volume;
        this.isMuted = (volume === 0);
        this.volumeLabel.set_text(volume + " %");
        this.set_applet_label(volume + "%");
        this._updateIcon();

        // Debounce: 20ms without changes
        if (this._volumeChangeTimeout) {
            Mainloop.source_remove(this._volumeChangeTimeout);
        }

        this._volumeChangeTimeout = Mainloop.timeout_add(20, () => {
            this._volumeChangeTimeout = null;
            this.setVolumeAsync(volume);
            return false;
        });
    }

    setVolumeAsync(volume) {
        if (!this.isConnected) return;

        try {
            Util.spawn_async([this.scriptPath, volume.toString()], () => {});
        } catch (e) {
            global.logError("Redragon: Error setting volume: " + e);
        }
    }

    changeVolume(delta) {
        if (!this.isConnected) return;

        let newVolume = Math.max(0, Math.min(100, this.currentVolume + delta));

        if (newVolume !== this.currentVolume) {
            // Update UI immediately
            this.currentVolume = newVolume;
            this.isMuted = (newVolume === 0);
            this.volumeLabel.set_text(newVolume + " %");
            this.set_applet_label(newVolume + "%");
            this._updateIcon();

            // Update slider
            this._updatingSlider = true;
            this.volumeSlider.setValue(newVolume / 100.0);
            this._updatingSlider = false;

            // Execute command
            this.setVolumeAsync(newVolume);
        }
    }

    startMonitoring() {
        // Update every 3 seconds
        this._monitoringTimeout = Mainloop.timeout_add_seconds(3, () => {
            if (this.isConnected) {
                this.updateVolume();
            } else {
                this.detectDevice();
            }
            return true;
        });
    }

    on_applet_removed_from_panel() {
        if (this._monitoringTimeout) {
            Mainloop.source_remove(this._monitoringTimeout);
        }
        if (this._volumeChangeTimeout) {
            Mainloop.source_remove(this._volumeChangeTimeout);
        }
    }
}

function main(metadata, orientation, panel_height, instance_id) {
    return new RedragonVolumeApplet(metadata, orientation, panel_height, instance_id);
}
