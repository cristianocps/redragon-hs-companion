#!/usr/bin/env python3
"""
Redragon Wireless Headset Volume Synchronizer
Synchronizes the volume channels of Redragon wireless headsets (via dongle) on Linux

Compatible with:
- Redragon H878, H848, H510, etc (wireless models via dongle USB)
- Other Redragon wireless headsets with similar issues
"""

import subprocess
import sys
import os
import argparse
import re
import time
import json
from pathlib import Path
from typing import Tuple, Optional, List


class RedragonVolumeSync:
    # Patterns to detect Redragon/similar headsets
    DEVICE_PATTERNS = [
        r'[Hh]\d{3}',                    # H878, H848, etc
        r'Wireless\s+headset',           # Generic pattern
        r'XiiSound',                     # Manufacturer
        r'Weltrend',                     # Other manufacturer
        r'Redragon',                     # Brand
    ]

    def __init__(self, device_pattern: str = None):
        """
        Args:
            device_pattern: Specific pattern to search (optional)
        """
        self.custom_pattern = device_pattern
        self.card_id = None
        self.device_name = None
        self.last_set_time = 0
        self.debounce_delay = 0.5  # seconds
        
        # Volume state persistence
        self.state_dir = Path.home() / ".local" / "share" / "redragon-hs-companion"
        self.state_file = self.state_dir / "volume_state.json"
        self.state_dir.mkdir(parents=True, exist_ok=True)
        
        self.detect_card()

    def detect_card(self) -> bool:
        """Detects automatically wireless headsets Redragon"""
        try:
            # Force English locale for consistent output
            env = os.environ.copy()
            env['LC_ALL'] = 'C'
            env['LANG'] = 'C'
            
            result = subprocess.run(
                ["aplay", "-l"],
                capture_output=True,
                text=True,
                check=True,
                env=env
            )

            # If a custom pattern was provided, use only it
            patterns_to_check = [self.custom_pattern] if self.custom_pattern else self.DEVICE_PATTERNS

            # Search for the card using the patterns
            for line in result.stdout.split('\n'):
                if 'card' in line.lower():
                    for pattern in patterns_to_check:
                        if re.search(pattern, line, re.IGNORECASE):
                            match = re.search(r'card (\d+):', line, re.IGNORECASE)
                            if match:
                                self.card_id = match.group(1)
                                # Extract the device name
                                name_match = re.search(r'\[([^\]]+)\]', line)
                                self.device_name = name_match.group(1) if name_match else "Headset Redragon"
                                print(f"✓ {self.device_name} detected on card {self.card_id}")
                                return True

            print("✗ Headset Redragon wireless not found")
            print("   Compatible devices: H878, H848, etc (via dongle USB)")
            return False

        except subprocess.CalledProcessError as e:
            print(f"✗ Error detecting audio devices: {e}")
            return False

    def get_volumes(self) -> Tuple[Optional[int], Optional[int]]:
        """Gets the current volumes of the two PCM controls"""
        if not self.card_id:
            return None, None

        try:
            # Force English locale for consistent output
            env = os.environ.copy()
            env['LC_ALL'] = 'C'
            env['LANG'] = 'C'
            
            result = subprocess.run(
                ["amixer", "-c", self.card_id, "contents"],
                capture_output=True,
                text=True,
                check=True,
                env=env
            )

            pcm_vol1 = None
            pcm_vol2 = None

            lines = result.stdout.split('\n')
            for i, line in enumerate(lines):
                if "name='PCM Playback Volume'" in line:
                    # Next line contains the values
                    if i + 1 < len(lines):
                        value_line = lines[i + 2]
                        if 'values=' in value_line:
                            values = re.search(r'values=(.+)', value_line)
                            if values:
                                vals = values.group(1).strip().split(',')
                                if "index=1" in line:
                                    pcm_vol2 = int(vals[0])
                                else:
                                    pcm_vol1 = int(vals[0])

            return pcm_vol1, pcm_vol2

        except subprocess.CalledProcessError as e:
            print(f"✗ Error getting volumes: {e}")
            return None, None

    def set_volume(self, volume: int, silent: bool = False) -> bool:
        """Defines the volume intelligently based on the output type

        DIGITAL OUTPUT:
        - Synchronizes PCM[0] and PCM[1] with the same value

        ANALOG OUTPUT:
        - Keeps PCM[0] at 100% (avoid conflict with PipeWire)
        - Defines only PCM[1] with the desired volume
        """
        if not self.card_id:
            if not silent:
                print("✗ Headset not detected")
            return False

        if not 0 <= volume <= 100:
            if not silent:
                print("✗ Volume must be between 0 and 100")
            return False

        try:
            # Adjust via ALSA (different logic for analog/digital)
            success = self._set_volume_alsa(volume, silent)

            # Update timestamp of the last set
            self.last_set_time = time.time()

            if success:
                # Save volume state to disk
                self._save_volume_state(volume)
                
                if not silent:
                    print(f"✓ Volume synchronized to {volume}%")

            return success

        except subprocess.CalledProcessError as e:
            if not silent:
                print(f"✗ Error defining volume: {e}")
            return False

    def _set_volume_alsa(self, volume: int, silent: bool = False) -> bool:
        """Defines volume directly via ALSA

        Different behavior by output type:

        DIGITAL OUTPUT:
        - Defines PCM[0] and PCM[1] with the same value
        - Traditional method that always worked

        ANALOG OUTPUT:
        - Keeps PCM[0] fixed at 100% (avoid conflict with PipeWire)
        - Defines only PCM[1] with the desired volume
        - PipeWire does not control PCM[1], so there is no conflict
        """
        try:
            is_analog = self._is_analog_output()
            print(f"is_analog: {is_analog}")

            if is_analog:
                # ANALOG OUTPUT: PCM[0]=100% fixed, PCM[1]=variable

                # Keeps PCM[0] always at 100%
                subprocess.run(
                    ["amixer", "-c", self.card_id, "set", "PCM", "100%"],
                    capture_output=True,
                    check=True
                )

                # Adjusts only PCM[1] with the desired volume
                subprocess.run(
                    ["amixer", "-c", self.card_id, "cset", "numid=10", str(volume)],
                    capture_output=True,
                    check=True
                )
            else:
                # DIGITAL OUTPUT: Synchronizes PCM[0] and PCM[1] normally

                # Define PCM[0] (2 channels) - Used by PipeWire/PulseAudio
                subprocess.run(
                    ["amixer", "-c", self.card_id, "set", "PCM", f"{volume}%"],
                    capture_output=True,
                    check=True
                )

                # Define PCM[1] (1 channel) - Not controlled by PipeWire
                subprocess.run(
                    ["amixer", "-c", self.card_id, "cset", "numid=10", str(volume)],
                    capture_output=True,
                    check=True
                )

            return True
        except subprocess.CalledProcessError:
            return False

    def _is_analog_output(self) -> bool:
        """Detects if the analog output is active"""
        try:
            # Force English locale for consistent output
            env = os.environ.copy()
            env['LC_ALL'] = 'C'
            env['LANG'] = 'C'
            
            result = subprocess.run(
                ["pactl", "list", "cards"],
                capture_output=True,
                text=True,
                check=True,
                env=env
            )

            # Search for the Redragon card
            in_redragon_card = False
            for line in result.stdout.split('\n'):
                if any(pattern in line for pattern in ['XiiSound', 'Weltrend', 'Redragon', 'H878']):
                    in_redragon_card = True

                if in_redragon_card and 'Active Profile:' in line:
                    return 'analog' in line

            return False
        except:
            return False

    def _get_pipewire_sink(self) -> Optional[str]:
        """Gets the name of the PipeWire sink for the headset"""
        try:
            # Force English locale for consistent output
            env = os.environ.copy()
            env['LC_ALL'] = 'C'
            env['LANG'] = 'C'
            
            result = subprocess.run(
                ["pactl", "list", "sinks", "short"],
                capture_output=True,
                text=True,
                check=True,
                env=env
            )

            # Search for the Redragon sink
            for line in result.stdout.split('\n'):
                if any(pattern in line for pattern in ['XiiSound', 'Weltrend', 'Redragon']):
                    parts = line.split()
                    if len(parts) >= 2:
                        return parts[1]  # Sink name

            return None
        except:
            return None

    def sync_from_master(self) -> bool:
        """Synchronizes PCM[1] copying the value of PCM[0] (master)

        PCM[0] (numid=9) is controlled by PipeWire/PulseAudio.
        PCM[1] (numid=10) is not controlled and needs to be synchronized manually.
        """
        vol1, vol2 = self.get_volumes()

        if vol1 is None or vol2 is None:
            return False

        # If they are already synchronized, do nothing
        if vol1 == vol2:
            return False

        # Copies the volume of PCM[0] (master) to PCM[1]
        try:
            subprocess.run(
                ["amixer", "-c", self.card_id, "cset", f"numid=10", f"{vol1}"],
                capture_output=True,
                check=True
            )

            self.last_set_time = time.time()
            return True

        except subprocess.CalledProcessError:
            return False

    def should_debounce(self) -> bool:
        """Checks if we should wait (debounce) before synchronizing"""
        elapsed = time.time() - self.last_set_time
        return elapsed < self.debounce_delay

    def sync_volumes(self, prefer_lower: bool = False) -> bool:
        """Synchronizes the volumes

        Args:
            prefer_lower: If True, uses the smaller value instead of the larger.
                         Useful when the user is decreasing the volume.
        """
        vol1, vol2 = self.get_volumes()

        if vol1 is None or vol2 is None:
            print("✗ Unable to get current volumes")
            return False

        # Chooses the target based on the preference
        if prefer_lower:
            target_volume = min(vol1, vol2)
        else:
            target_volume = max(vol1, vol2)

        print(f"📊 Current volumes: PCM={vol1}%, PCM[1]={vol2}%")
        print(f"🎯 Synchronizing to: {target_volume}%")

        return self.set_volume(target_volume)

    def smart_sync(self, vol1: int, vol2: int, prev_vol1: int = None, prev_vol2: int = None) -> bool:
        """Smart synchronization that detects the direction of the change

        Args:
            vol1, vol2: Current volumes
            prev_vol1, prev_vol2: Previous volumes (optional)

        Returns:
            True if synchronized, False if not necessary or there was an error
        """
        if vol1 == vol2:
            return False  # Already synchronized

        # If we have history, detects direction
        if prev_vol1 is not None and prev_vol2 is not None:
            # Detects which control changed
            vol1_changed = vol1 != prev_vol1
            vol2_changed = vol2 != prev_vol2

            # Detects direction (increasing or decreasing)
            vol1_decreased = vol1 < prev_vol1
            vol2_decreased = vol2 < prev_vol2

            # If any volume decreased, uses the smaller
            if vol1_decreased or vol2_decreased:
                target = min(vol1, vol2)
            # If increased, uses the larger
            else:
                target = max(vol1, vol2)
        else:
            # No history, uses the larger (safe behavior)
            target = max(vol1, vol2)

        return self.set_volume(target, silent=True)

    def _save_volume_state(self, volume: int) -> None:
        """Save volume state to disk for persistence across reboots"""
        try:
            state = {
                "volume": volume,
                "device": self.device_name or "Unknown",
                "card_id": self.card_id,
                "timestamp": time.time()
            }
            with open(self.state_file, 'w') as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            # Silent fail - not critical
            pass

    def _load_volume_state(self) -> Optional[int]:
        """Load saved volume state from disk"""
        try:
            if self.state_file.exists():
                with open(self.state_file, 'r') as f:
                    state = json.load(f)
                    return state.get("volume")
        except Exception as e:
            # Silent fail - return None if can't read
            pass
        return None

    def restore_volume(self, silent: bool = False) -> bool:
        """Restore volume from saved state"""
        saved_volume = self._load_volume_state()
        if saved_volume is not None:
            if not silent:
                print(f"🔄 Restoring saved volume: {saved_volume}%")
            return self.set_volume(saved_volume, silent=silent)
        return False

    def show_status(self) -> None:
        """Shows the current status of the headset"""
        if not self.card_id:
            print("❌ Headset Redragon not found")
            return

        vol1, vol2 = self.get_volumes()

        device_display = self.device_name or "Headset Redragon"

        print("\n" + "="*50)
        print(f"  {device_display} - Status")
        print("="*50)
        print(f"  Card: {self.card_id}")
        print(f"  PCM Volume (2 channels): {vol1}%")
        print(f"  PCM Volume [1] (1 channel): {vol2}%")

        if vol1 == vol2:
            print("  Status: ✓ Synchronized")
        else:
            print("  Status: ✗ Desynchronized")

        print("="*50 + "\n")


# Alias for compatibility with existing code
H878VolumeSync = RedragonVolumeSync


def main():
    parser = argparse.ArgumentParser(
        description="Volume synchronizer for Redragon wireless headsets (via dongle)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Compatible devices:
  - Redragon H878, H848, H510, etc (wireless models via dongle USB)
  - Automatically detects the connected device

Exemplos:
  %(prog)s sync          # Synchronizes volumes automatically
  %(prog)s set 75        # Defines volume to 75%
  %(prog)s status        # Shows current status
  %(prog)s -d H848 sync  # Specifies specific model
        """
    )

    parser.add_argument(
        "command",
        choices=["sync", "set", "status"],
        help="Command to execute"
    )

    parser.add_argument(
        "volume",
        nargs="?",
        type=int,
        help="Volume (0-100) for the 'set' command"
    )

    parser.add_argument(
        "-d", "--device",
        type=str,
        help="Search pattern for the device (ex: H878, H848)",
        default=None
    )

    args = parser.parse_args()

    sync = RedragonVolumeSync(device_pattern=args.device)

    if not sync.card_id:
        print("\n⚠️  Ensure the Redragon headset is connected (via dongle USB)")
        sys.exit(1)

    if args.command == "sync":
        success = sync.sync_volumes()
        sys.exit(0 if success else 1)

    elif args.command == "set":
        if args.volume is None:
            print("✗ Specify a volume value (0-100)")
            sys.exit(1)
        success = sync.set_volume(args.volume)
        sys.exit(0 if success else 1)

    elif args.command == "status":
        sync.show_status()
        sys.exit(0)


if __name__ == "__main__":
    main()
