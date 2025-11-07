# Redragon HS Companion

Complete solution for controlling the volume of **Redragon wireless headsets** (H878, H848, H510, etc.) on Linux.

## 🎯 Problem

Redragon wireless headsets have an issue on Linux where PipeWire only controls one of the headset's PCM channels (PCM[0]), leaving the other channel (PCM[1]) out of sync. This causes volume issues and unbalanced audio.

## ✨ Features

- 🔧 **Fast Client** - Command-line control with ~20ms response time
- 🤖 **Sync Daemon** - Automatically keeps PCM[0] and PCM[1] synchronized
- ⚡ **Control Daemon** - Unix socket server for fast control
- 🎨 **Graphical Interface** - Support for GNOME Shell, Cinnamon, and KDE Plasma
- 🚀 **Auto-detection** - Automatically detects when headset is connected
- 🔊 **Analog Output** - Works perfectly with analog output (PCM[0]=100%, PCM[1]=variable)
- 🎵 **Digital Output** - Also works with digital output (IEC958)

## 📋 Requirements

- Python 3
- alsa-utils (amixer)
- systemd (for daemons)
- GNOME Shell 45+ / Cinnamon 5.0+ / KDE Plasma 6+ (for graphical interface)

### Installing dependencies

**Ubuntu/Debian:**
```bash
sudo apt install python3 alsa-utils
```

**Fedora:**
```bash
sudo dnf install python3 alsa-utils
```

**Arch Linux:**
```bash
sudo pacman -S python alsa-utils
```

## 🚀 Installation

### Automatic Installation (Recommended)

```bash
git clone https://github.com/cristianocps/redragon-hs-companion.git
cd redragon-hs-companion
./install.sh
```

The installation script will:
1. ✅ Check dependencies
2. ✅ Install scripts to `~/.local/bin`
3. ✅ Configure systemd services
4. ✅ Install extension/applet/widget for your desktop environment

### Enable services

```bash
# Enable and start both daemons
systemctl --user enable --now redragon-volume-sync.service
systemctl --user enable --now redragon-control-daemon.service
```

## 🎮 Usage

### Command Line

```bash
# Show headset status
redragon-volume status

# Get current volume
redragon-volume get

# Set volume (0-100)
redragon-volume 75

# Increase/decrease volume
redragon-volume +10
redragon-volume -5

# Mute/unmute (toggle)
redragon-volume mute
```

### Graphical Interface

#### GNOME Shell
1. Open **Extensions** (gnome-extensions)
2. Enable **Redragon HS Companion**
3. The icon will appear in the top bar

#### Cinnamon
1. Open **Settings** → **Applets**
2. Search for **Redragon HS Companion**
3. Add to panel

#### KDE Plasma
1. Right-click on panel
2. **Add Widgets**
3. Search for **Redragon HS Companion**
4. Drag to panel or system tray

### Interface Controls

- **Left click**: Open control popup
- **Middle/Right click**: Quick mute/unmute
- **Scroll**: Increase/decrease volume (±5%)
- **Slider**: Precise volume control
- **"Use as audio output" button**: Set headset as default output

## 🔧 How It Works

### Architecture

The project uses a two-daemon architecture for maximum performance:

```
┌─────────────────────────────────────────┐
│  Interface (GNOME/Cinnamon/Plasma)      │
│  or Bash Client (redragon-volume)       │
└──────────────┬──────────────────────────┘
               │ ~20ms via Unix socket
               ▼
┌─────────────────────────────────────────┐
│  Control Daemon                         │
│  (redragon_control_daemon.py)           │
│  • Accepts commands via socket          │
│  • Sets volumes instantly               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  ALSA (amixer)                          │
│  • PCM[0] (2 channels, numid=9)        │
│  • PCM[1] (1 channel, numid=10)        │
└──────────────▲──────────────────────────┘
               │
               │ monitors/syncs
               │
┌─────────────────────────────────────────┐
│  Sync Daemon                            │
│  (redragon_daemon.py)                   │
│  • Digital output: PCM[0] → PCM[1]      │
│  • Analog output: doesn't sync          │
└─────────────────────────────────────────┘
```

### Analog vs Digital Output

#### Analog Output (Default)
- **PCM[0]**: Kept at **100%** fixed (avoids conflict with PipeWire)
- **PCM[1]**: **Variable** control (0-100%)
- PipeWire monitors PCM[0] but can't change it
- Sync daemon does NOT interfere

#### Digital Output (IEC958/S/PDIF)
- **PCM[0]**: Synchronized with desired volume
- **PCM[1]**: Synchronized with PCM[0]
- PipeWire doesn't interfere
- Sync daemon keeps both equal

## 📊 Logs and Diagnostics

### View daemon logs

```bash
# Sync daemon
journalctl --user -u redragon-volume-sync -f

# Control daemon
journalctl --user -u redragon-control-daemon -f

# Local logs
tail -f ~/.local/share/redragon-hs-companion/daemon.log
tail -f ~/.local/share/redragon-hs-companion/control-daemon.log
```

### Service status

```bash
systemctl --user status redragon-volume-sync.service
systemctl --user status redragon-control-daemon.service
```

## 🔍 Troubleshooting

### Headset not detected

```bash
# Check if headset is connected
lsusb | grep -i "redragon\|weltrend"

# Check sound cards
aplay -l

# Test manual detection
redragon-volume status
```

### Volume not changing

```bash
# Check if daemons are running
systemctl --user status redragon-control-daemon.service

# Check Unix socket
ls -la $XDG_RUNTIME_DIR/redragon-control.sock

# Restart daemons
systemctl --user restart redragon-volume-sync.service
systemctl --user restart redragon-control-daemon.service
```

### Audio only on one side

```bash
# Check ALSA volumes
amixer -c <CARD_ID> sget PCM
amixer -c <CARD_ID> cget numid=9   # PCM[0]
amixer -c <CARD_ID> cget numid=10  # PCM[1]

# Force sync
redragon-volume 75
```

### Graphical interface not showing

**GNOME:**
```bash
# Reload extensions
gnome-extensions disable redragon-volume-sync@cristiano
gnome-extensions enable redragon-volume-sync@cristiano
```

**Cinnamon:**
```bash
# Reload applets
cinnamon-settings applets
```

**KDE Plasma:**
```bash
# Reload Plasma
kquitapp6 plasmashell && plasmashell &
```

## 🗑️ Uninstallation

```bash
./uninstall.sh
```

Or manually:

```bash
# Stop and disable services
systemctl --user stop redragon-volume-sync.service
systemctl --user stop redragon-control-daemon.service
systemctl --user disable redragon-volume-sync.service
systemctl --user disable redragon-control-daemon.service

# Remove files
rm -rf ~/.local/bin/redragon*
rm -rf ~/.config/systemd/user/redragon-*
rm -rf ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano
rm -rf ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano
rm -rf ~/.local/share/plasma/plasmoids/redragon-volume-sync@cristiano

# Reload systemd
systemctl --user daemon-reload
```

## 📝 Project Files

### Python Scripts
- `redragon_volume_sync.py` - Core library with ALSA control
- `redragon_daemon.py` - PCM[0] ↔ PCM[1] sync daemon
- `redragon_control_daemon.py` - Fast control daemon (Unix socket)

### Client
- `redragon-volume` - Fast bash client (~20ms)

### Graphical Interfaces
- `gnome-extension/` - GNOME Shell extension
- `cinnamon-applet/` - Cinnamon applet
- `plasma-widget/` - KDE Plasma widget

### Installation
- `install.sh` - Automatic installation script
- `uninstall.sh` - Uninstallation script

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Improve documentation

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🎧 Compatible Headsets

Tested and working with:
- ✅ Redragon H878 Wireless
- ✅ Redragon H848 Bluetooth
- ✅ Redragon H510 Zeus

Should work with any Redragon wireless headset that uses the XiiSound/Weltrend USB driver.

## ⚡ Performance

- **Bash client**: ~11-20ms latency
- **Control daemon**: instant response via Unix socket
- **Monitoring**: polling every 2-3 seconds (low CPU impact)
- **Memory**: ~8-10MB per daemon

## 🙏 Acknowledgments

- Linux community for tools like ALSA, PulseAudio, and PipeWire
- GNOME Shell, Cinnamon, and KDE Plasma developers
- Users who reported bugs and tested solutions
