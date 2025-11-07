const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const St = imports.gi.St;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Util = imports.misc.util;

class H878VolumeApplet extends Applet.TextIconApplet {
    constructor(metadata, orientation, panel_height, instance_id) {
        super(orientation, panel_height, instance_id);

        this.metadata = metadata;
        this.orientation = orientation;

        try {
            // Define ícone
            this.set_applet_icon_symbolic_name("audio-headphones");
            this.set_applet_tooltip("H878 Volume Sync");

            // Cria menu
            this.menuManager = new PopupMenu.PopupMenuManager(this);
            this.menu = new Applet.AppletPopupMenu(this, orientation);
            this.menuManager.addMenu(this.menu);

            // Status
            this.statusLabel = new St.Label({ text: "Detectando..." });
            let statusItem = new PopupMenu.PopupMenuItem("", { reactive: false });
            statusItem.addActor(this.statusLabel);
            this.menu.addMenuItem(statusItem);

            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            // Volume atual
            this.volumeLabel = new St.Label({ text: "Volume: --%" });
            let volumeItem = new PopupMenu.PopupMenuItem("", { reactive: false });
            volumeItem.addActor(this.volumeLabel);
            this.menu.addMenuItem(volumeItem);

            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            // Controles de volume
            let volumeControlItem = new PopupMenu.PopupMenuItem("Controle de Volume", { reactive: false });
            this.menu.addMenuItem(volumeControlItem);

            // Botões +/-
            let buttonBox = new St.BoxLayout({ style_class: 'popup-menu-item' });

            let downButton = new St.Button({
                label: "-5%",
                style_class: 'button',
                x_expand: true
            });
            downButton.connect('clicked', Lang.bind(this, function() {
                this.changeVolume(-5);
            }));
            buttonBox.add(downButton);

            let upButton = new St.Button({
                label: "+5%",
                style_class: 'button',
                x_expand: true
            });
            upButton.connect('clicked', Lang.bind(this, function() {
                this.changeVolume(5);
            }));
            buttonBox.add(upButton);

            let buttonItem = new PopupMenu.PopupMenuItem("", { reactive: false });
            buttonItem.addActor(buttonBox);
            this.menu.addMenuItem(buttonItem);

            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            // Botão de sincronização
            let syncItem = new PopupMenu.PopupMenuItem("🔄 Sincronizar Agora");
            syncItem.connect('activate', Lang.bind(this, this.syncVolumes));
            this.menu.addMenuItem(syncItem);

            // Botão de reload
            let reloadItem = new PopupMenu.PopupMenuItem("🔃 Redetectar Headset");
            reloadItem.connect('activate', Lang.bind(this, this.detectHeadset));
            this.menu.addMenuItem(reloadItem);

            // Variáveis de estado
            this.isConnected = false;
            this.deviceName = null;

            // Tenta encontrar o script (instalado ou no diretório)
            this.scriptPath = this._findScript();

            // Inicia monitoramento
            this.detectHeadset();
            this.startMonitoring();

        } catch (e) {
            global.logError(e);
        }
    }

    on_applet_clicked(event) {
        this.menu.toggle();
    }

    _findScript() {
        // Tenta encontrar o script instalado
        let possiblePaths = [
            GLib.get_home_dir() + '/.local/bin/redragon-volume',
            GLib.get_home_dir() + '/.local/bin/h878-volume',
            this.metadata.path.replace("/cinnamon-applet", "/redragon-volume")
        ];

        for (let path of possiblePaths) {
            if (GLib.file_test(path, GLib.FileTest.EXISTS)) {
                return path;
            }
        }

        // Fallback para o caminho relativo
        return GLib.get_home_dir() + '/.local/bin/redragon-volume';
    }

    detectHeadset() {
        try {
            let [success, stdout, stderr] = GLib.spawn_command_line_sync('aplay -l');
            if (success) {
                let output = stdout.toString();
                // Detecta qualquer headset Redragon sem fio
                let patterns = ['H878', 'H848', 'H510', 'Wireless headset', 'XiiSound', 'Weltrend', 'Redragon'];
                this.isConnected = false;
                this.deviceName = null;

                for (let pattern of patterns) {
                    if (output.includes(pattern)) {
                        this.isConnected = true;
                        // Tenta extrair o nome do dispositivo
                        let match = output.match(/\[([^\]]+)\]/);
                        this.deviceName = match ? match[1] : 'Redragon';
                        break;
                    }
                }

                if (this.isConnected) {
                    this.statusLabel.set_text("✓ " + this.deviceName + " Conectado");
                    this.set_applet_label(this.deviceName);
                    this.getVolume();
                } else {
                    this.statusLabel.set_text("✗ Redragon Desconectado");
                    this.set_applet_label("");
                    this.volumeLabel.set_text("Volume: --");
                }
            }
        } catch (e) {
            global.logError("Redragon: Erro ao detectar headset: " + e);
        }
    }

    getVolume() {
        if (!this.isConnected) return;

        try {
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(
                this.scriptPath + ' status'
            );

            if (success) {
                let output = stdout.toString();
                // Procura pelo volume PCM (2 canais)
                let match = output.match(/PCM Volume \(2 canais\):\s*(\d+)%/);
                if (match) {
                    let volume = match[1];
                    this.volumeLabel.set_text("Volume: " + volume + "%");
                    // Atualiza o label do applet também
                    this.set_applet_label(volume + "%");
                } else {
                    // Fallback: tenta padrão antigo
                    match = output.match(/PCM Volume.*:\s*(\d+)%/);
                    if (match) {
                        this.volumeLabel.set_text("Volume: " + match[1] + "%");
                        this.set_applet_label(match[1] + "%");
                    }
                }
            }
        } catch (e) {
            global.logError("Redragon: Erro ao obter volume: " + e);
        }
    }

    changeVolume(delta) {
        if (!this.isConnected) {
            this._notify("Headset não conectado");
            return;
        }

        try {
            let command = this.scriptPath + (delta > 0 ? ' +' + delta : ' ' + delta);
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(command);

            if (success) {
                // Atualiza o volume exibido após breve delay
                Mainloop.timeout_add(500, Lang.bind(this, function() {
                    this.getVolume();
                    return false;
                }));
            } else {
                this._notify("Erro ao ajustar volume");
            }
        } catch (e) {
            global.logError("Redragon: Erro ao ajustar volume: " + e);
            this._notify("Erro: " + e);
        }
    }

    syncVolumes() {
        if (!this.isConnected) {
            this._notify("Headset não conectado");
            return;
        }

        try {
            let [success, stdout, stderr] = GLib.spawn_command_line_sync(
                this.scriptPath + ' status'
            );

            if (success) {
                this._notify("Volume atualizado!");
                this.getVolume();
            } else {
                this._notify("Erro ao sincronizar");
            }
        } catch (e) {
            global.logError("Redragon: Erro ao sincronizar: " + e);
            this._notify("Erro: " + e);
        }
    }

    startMonitoring() {
        // Monitora a cada 5 segundos
        this.timeout = Mainloop.timeout_add_seconds(5, Lang.bind(this, function() {
            this.detectHeadset();
            return true;
        }));
    }

    _notify(message) {
        Util.spawnCommandLine('notify-send "H878 Volume Sync" "' + message + '"');
    }

    on_applet_removed_from_panel() {
        if (this.timeout) {
            Mainloop.source_remove(this.timeout);
        }
    }
}

function main(metadata, orientation, panel_height, instance_id) {
    return new H878VolumeApplet(metadata, orientation, panel_height, instance_id);
}
