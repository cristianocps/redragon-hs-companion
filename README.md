# Redragon HS Companion

Volume control solution for Redragon wireless headsets (H878, H848, H510, etc.) on Linux.

## Problem

Redragon wireless headsets have an issue on Linux where PipeWire only controls one of the headset's PCM channels, leaving the other out of sync. This causes volume imbalance and audio problems.

## Features

- Fast command-line control (~20ms response)
- Automatic PCM channel synchronization daemon
- Unix socket server for instant control
- Desktop widgets for GNOME Shell, Cinnamon, KDE Plasma, and COSMIC
- Auto-detection of connected headsets
- Support for both analog and digital outputs
- Multilingual interface (English, Portuguese, Spanish)

## Requirements

- Python 3
- alsa-utils (amixer)
- systemd (optional, for daemons)
- GNOME Shell 45+ / Cinnamon 5.0+ / KDE Plasma 6+ (optional, for GUI)
- Rust toolchain (cargo), only to build the COSMIC applet from source (optional — a prebuilt binary from the latest GitHub release is used automatically when available)

## Installation

The easiest way to install is the [quick installer](#quick-install-curl) — one command, no repository clone needed. Platform-specific prebuilt packages are also published on the [releases page](https://github.com/cristianocps/redragon-hs-companion/releases/latest):

- **Any distro (recommended)** → [quick install (curl)](#quick-install-curl)
- **Debian/Ubuntu** → [.deb package](#debian--ubuntu-deb)
- **GNOME / Cinnamon** → [prebuilt widget zips](#gnome--cinnamon-widgets)
- **COSMIC** → [prebuilt applet binary](#cosmic-prebuilt-applet)
- **Flatpak** → [experimental bundle](#flatpak-experimental)

### Quick install (curl)

One command, no repository clone needed — the script downloads the source it needs by itself:

```bash
curl -fsSL https://raw.githubusercontent.com/cristianocps/redragon-hs-companion/master/install.sh | bash
```

Daemon-less mode (`--config-only`):

```bash
curl -fsSL https://raw.githubusercontent.com/cristianocps/redragon-hs-companion/master/install.sh | bash -s -- --config-only
```

This is the only method that sets up everything in one shot (core + widgets for GNOME/Cinnamon/KDE Plasma/COSMIC). If you prefer to inspect the code first, clone and run locally:

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

#### Daemon-less alternative (`--config-only`)

```bash
./install.sh --config-only
```

Instead of enabling the daemons, this applies the fix from
[issue #6](https://github.com/cristianocps/redragon-hs-companion/issues/6):
a WirePlumber rule (software mixer, hides the phantom digital interface) plus a
oneshot systemd service that locks the hardware PCM channels at 100%. Ideal for
immutable distros such as Fedora Silverblue, or whenever you prefer zero
background daemons — your desktop's native volume control simply works.

- Scripts and CLI are still installed (daemons stay available but not enabled)
- Desktop widgets/applets are not installed in this mode (they depend on the daemons)
- Covers the whole Weltrend/XiiSound `040b:0897` dongle family: Redragon H878,
  H848, H510-PRO Wireless, Havit Fuxi-H3 and rebrands
- Approach validated on WirePlumber 0.4 and 0.5; also based on the MIT-licensed
  [havit-fuxi-h3-linux-fix](https://github.com/cleisonsantos/havit-fuxi-h3-linux-fix)
- To switch back to daemon mode, just run `./install.sh` again without the flag

Note: a kernel-side quirk for this chipset is being discussed upstream
([LKML](https://lkml.org/lkml/2026/7/5/558)); once merged in mainline kernels,
the workaround may become unnecessary.

### Debian / Ubuntu (.deb)

The `.deb` includes the CLI, both daemons and the systemd user units (desktop widgets are not included — grab them from the sections below). Works on any apt-based distro (Debian, Ubuntu, Mint, Pop!_OS, ...):

```bash
DEB_URL=$(curl -s https://api.github.com/repos/cristianocps/redragon-hs-companion/releases/latest \
  | grep browser_download_url | grep '\.deb"' | cut -d'"' -f4)
wget "$DEB_URL"
sudo apt install ./redragon-volume-sync_*_all.deb
```

Then enable the daemons:

```bash
systemctl --user daemon-reload
systemctl --user enable --now redragon-volume-sync.service
systemctl --user enable --now redragon-control-daemon.service
```

### GNOME / Cinnamon widgets

Requires the core installed first (via the quick install or the .deb above).

**GNOME Shell 45+:**

```bash
wget https://github.com/cristianocps/redragon-hs-companion/releases/latest/download/redragon-volume-sync-gnome-extension.zip
mkdir -p ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano
unzip redragon-volume-sync-gnome-extension.zip -d ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano/
```

Log out and back in (Wayland) or restart the Shell (X11: `Alt+F2` → `r`), then enable "Redragon HS Companion" in the Extensions app or with `gnome-extensions enable redragon-volume-sync@cristiano`.

**Cinnamon 5.0+:**

```bash
wget https://github.com/cristianocps/redragon-hs-companion/releases/latest/download/redragon-volume-sync-cinnamon-applet.zip
mkdir -p ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano
unzip redragon-volume-sync-cinnamon-applet.zip -d ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano/
```

Then add the applet in Settings → Applets.

### COSMIC (prebuilt applet)

Requires the core installed first (via the quick install or the .deb above). No Rust toolchain needed:

```bash
wget https://github.com/cristianocps/redragon-hs-companion/releases/latest/download/redragon-volume-applet-linux-x86_64.tar.gz
tar -xzf redragon-volume-applet-linux-x86_64.tar.gz
install -Dm755 redragon-volume-applet ~/.local/bin/redragon-volume-applet
install -Dm644 com.github.cristianocps.RedragonVolume.desktop ~/.local/share/applications/com.github.cristianocps.RedragonVolume.desktop
```

Then add the applet in Settings → Panel → Applets.

### Flatpak (experimental)

```bash
wget https://github.com/cristianocps/redragon-hs-companion/releases/latest/download/redragon-hs-companion.flatpak
flatpak install --user ./redragon-hs-companion.flatpak
```

**Limitations:** the sandboxed bundle ships only the CLI/daemon binaries — no systemd integration and no desktop widgets — and the sandboxed CLI cannot reach the host daemon's socket. Prefer the quick install or the `.deb` for real use.

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
**COSMIC:** Settings → Panel → Applets → Add "Redragon HS Companion" (the installer downloads a prebuilt binary from the latest GitHub release when available, or builds from `cosmic-applet/` if the Rust toolchain is installed)

Widget controls:
- Left click: Open volume control
- Middle/Right click: Quick mute toggle
- Scroll: Adjust volume (±5%)

### Internationalization

The desktop widgets automatically detect your system language and display text in:
- **English** (default)
- **Portuguese** (Português)
- **Spanish** (Español)

Language is detected from `LANG` or `LANGUAGE` environment variables.

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
redragon-volume ping    # Test if the control daemon is reachable
```

### Error communicating with daemon

```bash
redragon-volume ping                              # Test connectivity
systemctl --user status redragon-control-daemon # Check daemon state
journalctl --user -u redragon-control-daemon -e # View recent logs
```

### Widget not showing

**GNOME:** `gnome-extensions disable redragon-volume-sync@cristiano && gnome-extensions enable redragon-volume-sync@cristiano`  
**Cinnamon:** Open Settings → Applets  
**KDE:** `kquitapp6 plasmashell && plasmashell &`  
**COSMIC:** Remove and re-add the applet in Settings → Panel → Applets (or log out and back in)

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
- Disable and remove desktop widgets (GNOME/Cinnamon/KDE/COSMIC)
- Remove widget from panel automatically
- Ask if you want to remove logs

Manual uninstallation:

```bash
# Stop and disable services
systemctl --user stop redragon-volume-sync.service redragon-control-daemon.service
systemctl --user disable redragon-volume-sync.service redragon-control-daemon.service

# Disable widgets
gnome-extensions disable redragon-volume-sync@cristiano  # GNOME
# For Cinnamon/KDE/COSMIC: remove from panel in Settings

# Remove files
rm -rf ~/.local/bin/redragon*
rm -rf ~/.config/systemd/user/redragon-*
rm -rf ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano
rm -rf ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano
rm -rf ~/.local/share/plasma/plasmoids/redragon-volume-sync@cristiano
rm -f ~/.local/share/applications/com.github.cristianocps.RedragonVolume.desktop  # COSMIC
systemctl --user daemon-reload
```

## Project Structure

- `redragon_volume_sync.py` - Core ALSA control library
- `redragon_daemon.py` - PCM synchronization daemon
- `redragon_control_daemon.py` - Unix socket control server
- `redragon-volume` - Fast Python CLI client
- `redragon-lock-pcm.sh` - PCM lock helper (daemon-less mode)
- `wireplumber/` - WirePlumber rule for the daemon-less mode
- `gnome-extension/` - GNOME Shell widget
- `cinnamon-applet/` - Cinnamon panel applet
- `plasma-widget/` - KDE Plasma widget
- `cosmic-applet/` - COSMIC panel applet (Rust/libcosmic)
- `systemd/` - systemd service templates
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
