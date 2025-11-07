# Redragon HS Companion

Volume control solution for Redragon wireless headsets (H878, H848, H510, etc.) on Linux.

## Problem

Redragon wireless headsets have an issue on Linux where PipeWire only controls one of the headset's PCM channels, leaving the other out of sync. This causes volume imbalance and audio problems.

## Features

- Fast command-line control (~20ms response)
- Automatic PCM channel synchronization daemon
- Unix socket server for instant control
- Desktop widgets for GNOME Shell, Cinnamon, and KDE Plasma
- Auto-detection of connected headsets
- Support for both analog and digital outputs

## Requirements

- Python 3
- alsa-utils (amixer)
- systemd (optional, for daemons)
- GNOME Shell 45+ / Cinnamon 5.0+ / KDE Plasma 6+ (optional, for GUI)

## Installation

```bash
git clone https://github.com/cristianocps/redragon-hs-companion.git
cd redragon-hs-companion
./install.sh
```

The installer automatically:
- Detects your distribution and package manager
- Installs missing dependencies (python3, alsa-utils)
- Installs scripts to `~/.local/bin`
- Configures systemd services
- Installs desktop widgets for your environment
- Offers to enable and add widgets to panel automatically

**Supported distributions:** Ubuntu, Debian, Fedora, Arch Linux, openSUSE, Alpine, Gentoo  
**Supported package managers:** apt, dnf, yum, pacman, zypper, apk, emerge

The installer will ask if you want to:
- Enable systemd services automatically
- Enable GNOME extension (if using GNOME)
- Add applet to panel (if using Cinnamon)
- Add widget to panel (if using KDE Plasma)

## Usage

### Command Line

```bash
redragon-volume status        # Show headset status
redragon-volume get           # Get current volume
redragon-volume 75            # Set volume to 75%
redragon-volume +10           # Increase volume
redragon-volume -5            # Decrease volume
redragon-volume mute          # Toggle mute
```

### Desktop Widgets

**GNOME Shell:** Open Extensions and enable "Redragon HS Companion"  
**Cinnamon:** Settings → Applets → Add "Redragon HS Companion"  
**KDE Plasma:** Right-click panel → Add Widgets → "Redragon HS Companion"

Widget controls:
- Left click: Open volume control
- Middle/Right click: Quick mute toggle
- Scroll: Adjust volume (±5%)

## Architecture

Two-daemon design for performance:

```
┌─────────────────────────────────────────┐
│  Client (CLI / Desktop Widget)          │
└──────────────┬──────────────────────────┘
               │ Unix socket (~20ms)
               ▼
┌─────────────────────────────────────────┐
│  Control Daemon                         │
│  Fast volume control via socket         │
└──────────────┬──────────────────────────┘
               ▼
┌─────────────────────────────────────────┐
│  ALSA (amixer)                          │
│  PCM[0] and PCM[1] channels             │
└──────────────▲──────────────────────────┘
               │
┌─────────────────────────────────────────┐
│  Sync Daemon                            │
│  Monitors and syncs PCM channels        │
└─────────────────────────────────────────┘
```

**Analog output:** PCM[0] stays at 100%, PCM[1] is controlled  
**Digital output:** Both channels synchronized

## Troubleshooting

### Headset not detected

```bash
lsusb | grep -i "redragon\|weltrend"    # Check USB connection
aplay -l                                 # List sound cards
redragon-volume status                   # Test detection
```

### Volume not working

```bash
systemctl --user status redragon-control-daemon.service
systemctl --user restart redragon-volume-sync.service
systemctl --user restart redragon-control-daemon.service
```

### Widget not showing

**GNOME:** `gnome-extensions disable redragon-volume-sync@cristiano && gnome-extensions enable redragon-volume-sync@cristiano`  
**Cinnamon:** Open Settings → Applets  
**KDE:** `kquitapp6 plasmashell && plasmashell &`

### View logs

```bash
journalctl --user -u redragon-volume-sync -f
journalctl --user -u redragon-control-daemon -f
```

## Manual Installation

If you prefer manual dependency installation:

**Ubuntu/Debian:** `sudo apt update && sudo apt install -y python3 alsa-utils`  
**Fedora:** `sudo dnf install -y python3 alsa-utils`  
**Arch Linux:** `sudo pacman -S --noconfirm python alsa-utils`  
**openSUSE:** `sudo zypper install -y python3 alsa-utils`  
**Alpine:** `sudo apk add python3 alsa-utils`  
**Gentoo:** `sudo emerge dev-lang/python media-sound/alsa-utils`

## Uninstallation

```bash
./uninstall.sh
```

The uninstaller will:
- Stop and disable systemd services
- Remove all scripts and binaries
- Disable and remove desktop widgets (GNOME/Cinnamon/KDE)
- Remove widget from panel automatically
- Ask if you want to remove logs

Manual uninstallation:

```bash
# Stop and disable services
systemctl --user stop redragon-volume-sync.service redragon-control-daemon.service
systemctl --user disable redragon-volume-sync.service redragon-control-daemon.service

# Disable widgets
gnome-extensions disable redragon-volume-sync@cristiano  # GNOME
# For Cinnamon/KDE: remove from panel in Settings

# Remove files
rm -rf ~/.local/bin/redragon*
rm -rf ~/.config/systemd/user/redragon-*
rm -rf ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano
rm -rf ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano
rm -rf ~/.local/share/plasma/plasmoids/redragon-volume-sync@cristiano
systemctl --user daemon-reload
```

## Project Structure

- `redragon_volume_sync.py` - Core ALSA control library
- `redragon_daemon.py` - PCM synchronization daemon
- `redragon_control_daemon.py` - Unix socket control server
- `redragon-volume` - Fast bash client
- `gnome-extension/` - GNOME Shell widget
- `cinnamon-applet/` - Cinnamon panel applet
- `plasma-widget/` - KDE Plasma widget
- `install.sh` - Automatic installer
- `uninstall.sh` - Uninstaller

## Compatible Headsets

Tested with:
- Redragon H878 Wireless
- Redragon H848 Bluetooth
- Redragon H510 Zeus

Should work with any Redragon wireless headset using XiiSound/Weltrend USB driver.

## Performance

- Command-line latency: ~11-20ms
- Memory usage: ~8-10MB per daemon
- CPU usage: minimal (polling every 2-3 seconds)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome. Report bugs, suggest features, or submit pull requests at the GitHub repository.
