#!/usr/bin/env python3
"""
Redragon Control Daemon - Fast volume control server
Accepts commands via Unix socket to avoid Python startup overhead
"""

import socket
import os
import sys
import signal
import logging
from pathlib import Path
from redragon_volume_sync import RedragonVolumeSync

class RedragonControlDaemon:
    def __init__(self):
        self.running = True
        self.sync = RedragonVolumeSync()
        self.volume_before_mute = None  # Stores volume before muting

        # Socket path
        runtime_dir = os.environ.get('XDG_RUNTIME_DIR', '/tmp')
        self.socket_path = f"{runtime_dir}/redragon-control.sock"

        # Configure logging
        log_dir = Path.home() / ".local" / "share" / "redragon-hs-companion"
        log_dir.mkdir(parents=True, exist_ok=True)
        log_file = log_dir / "control-daemon.log"

        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

    def signal_handler(self, signum, frame):
        self.logger.info(f"Received signal {signum}, closing daemon...")
        self.running = False

    def process_command(self, command):
        """Processes commands received via socket"""
        parts = command.strip().split()
        if not parts:
            return "ERROR: empty command"

        cmd = parts[0]

        try:
            if cmd == "set" and len(parts) == 2:
                volume = int(parts[1])
                if self.sync.set_volume(volume, silent=True):
                    return f"OK: {volume}"
                else:
                    return "ERROR: failed to set volume"

            elif cmd == "get":
                vol1, vol2 = self.sync.get_volumes()
                if vol1 is not None:
                    # Returns the effective volume (PCM[1] on analog, or any on digital)
                    is_analog = self.sync._is_analog_output()
                    effective_vol = vol2 if is_analog else vol1
                    return f"OK: {effective_vol}"
                else:
                    return "ERROR: failed to get volume"

            elif cmd == "status":
                vol1, vol2 = self.sync.get_volumes()
                is_analog = self.sync._is_analog_output()
                device_name = self.sync.device_name or "Redragon"
                card_id = self.sync.card_id or "?"
                return f"OK: device={device_name} card={card_id} pcm0={vol1} pcm1={vol2} analog={is_analog}"

            elif cmd == "mute":
                # Toggle mute
                vol1, vol2 = self.sync.get_volumes()
                if vol1 is None:
                    return "ERROR: failed to get volume"

                is_analog = self.sync._is_analog_output()
                current_vol = vol2 if is_analog else vol1

                if current_vol == 0:
                    # Unmute: restore previous volume (or 50 if none)
                    restore_vol = self.volume_before_mute if self.volume_before_mute else 50
                    if self.sync.set_volume(restore_vol, silent=True):
                        self.volume_before_mute = None
                        return f"OK: unmuted {restore_vol}"
                    else:
                        return "ERROR: failed to unmute"
                else:
                    # Mute: store current volume and set to 0
                    self.volume_before_mute = current_vol
                    if self.sync.set_volume(0, silent=True):
                        return "OK: muted"
                    else:
                        return "ERROR: failed to mute"

            elif cmd == "ping":
                return "OK: pong"

            else:
                return f"ERROR: unknown command '{cmd}'"

        except Exception as e:
            self.logger.error(f"Error processing command '{command}': {e}")
            return f"ERROR: {e}"

    def run(self):
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)

        # Remove old socket if it exists
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

        # Create Unix socket
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(self.socket_path)
        server.listen(5)
        server.settimeout(1.0)  # Timeout to check self.running

        # Permissions for the socket
        os.chmod(self.socket_path, 0o600)

        self.logger.info(f"Redragon Control Daemon started")
        self.logger.info(f"Socket: {self.socket_path}")

        if not self.sync.card_id:
            self.logger.warning("Headset not detected, waiting for connection...")

        while self.running:
            try:
                # Accept connection with timeout
                try:
                    client, _ = server.accept()
                except socket.timeout:
                    continue

                # Read command
                data = client.recv(1024).decode('utf-8').strip()

                if data:
                    # Process and respond
                    response = self.process_command(data)
                    client.sendall(response.encode('utf-8'))

                client.close()

            except Exception as e:
                self.logger.error(f"Error in main loop: {e}")

        # Cleanup
        server.close()
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

        self.logger.info("Redragon Control Daemon closed")


if __name__ == "__main__":
    daemon = RedragonControlDaemon()
    try:
        daemon.run()
    except KeyboardInterrupt:
        daemon.logger.info("Interrupted by user")
    except Exception as e:
        daemon.logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
