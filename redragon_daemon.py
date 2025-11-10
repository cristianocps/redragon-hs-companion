#!/usr/bin/env python3
"""
Redragon Volume Sync Daemon - Simple version
Monitors and automatically synchronizes PCM[0] → PCM[1]
Does not interfere with PipeWire
"""

import subprocess
import time
import signal
import sys
import logging
from pathlib import Path
from redragon_volume_sync import RedragonVolumeSync

class RedragonDaemonSimple:
    def __init__(self):
        self.running = True
        self.sync = RedragonVolumeSync()
        self.last_volumes = (None, None)
        self.check_interval = 2
        self.error_count = 0
        self.max_errors = 3  # Reconnect after 3 consecutive errors

        # Configure logging
        log_dir = Path.home() / ".local" / "share" / "redragon-hs-companion"
        log_dir.mkdir(parents=True, exist_ok=True)
        log_file = log_dir / "daemon.log"

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

    def wait_for_headset(self):
        self.logger.info("Waiting for headset connection...")
        while self.running:
            if self.sync.detect_card():
                device_info = f"{self.sync.device_name} (card {self.sync.card_id})"
                self.logger.info(f"Headset detected: {device_info}")
                return True
            time.sleep(5)
        return False

    def check_and_sync(self):
        """Synchronizes PCM[0] → PCM[1] only on DIGITAL OUTPUT

        On analog output, does not synchronize because:
        - PCM[0] must be fixed at 100% (controlled by PipeWire)
        - PCM[1] is variable (controls the real volume)
        """
        try:
            if not self.sync.card_id:
                self.logger.info("Card ID lost, attempting to detect headset...")
                if not self.sync.detect_card():
                    self.error_count += 1
                    if self.error_count >= self.max_errors:
                        self.logger.warning(f"Failed to detect headset {self.error_count} times, will keep retrying...")
                    return False
                else:
                    device_info = f"{self.sync.device_name} (card {self.sync.card_id})"
                    self.logger.info(f"Headset reconnected successfully: {device_info}")
                    self.error_count = 0

            if self.sync.should_debounce():
                return True

            # Detect if it is on analog output
            is_analog = self.sync._is_analog_output()

            vol1, vol2 = self.sync.get_volumes()

            if vol1 is None or vol2 is None:
                self.error_count += 1
                self.logger.warning(f"Failed to get volumes (error {self.error_count}/{self.max_errors})")
                
                # Force reconnection after consecutive errors
                if self.error_count >= self.max_errors:
                    self.logger.warning("Too many errors, forcing headset re-detection...")
                    self.sync.card_id = None
                    self.error_count = 0
                return False

            # Reset error count on successful read
            if self.error_count > 0:
                self.logger.info("Volume read successful, error count reset")
                self.error_count = 0

            # On analog output: does not synchronize (PCM[0]=100% fixed, PCM[1]=variable)
            if is_analog:
                if self.last_volumes != (vol1, vol2):
                    self.logger.debug(f"Analog output: PCM[0]={vol1}% (fixed), PCM[1]={vol2}% (variable)")
                self.last_volumes = (vol1, vol2)
                return True

            # On digital output: synchronize PCM[0] → PCM[1] when needed
            if vol1 != vol2:
                self.logger.info(f"Digital output: synchronizing PCM[1] to {vol1}% (copying from PCM[0])")
                if self.sync.sync_from_master():
                    self.last_volumes = (vol1, vol1)
                else:
                    self.logger.error("Failed to synchronize volumes")
                    self.error_count += 1
            else:
                if self.last_volumes != (vol1, vol2):
                    self.logger.debug(f"Digital output: volumes synchronized PCM[0]={vol1}%, PCM[1]={vol2}%")
                self.last_volumes = (vol1, vol2)

            return True

        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Error in check_and_sync: {e} (error {self.error_count}/{self.max_errors})")
            
            # Force reconnection after consecutive errors
            if self.error_count >= self.max_errors:
                self.logger.warning("Too many errors, forcing headset re-detection...")
                self.sync.card_id = None
                self.error_count = 0
            return False

    def run(self):
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)

        self.logger.info("Redragon Volume Sync Daemon started (simple mode: PCM[0] → PCM[1])")

        if not self.wait_for_headset():
            return

        # Try to restore saved volume state
        self.logger.info("Attempting to restore saved volume state...")
        if self.sync.restore_volume(silent=True):
            saved_vol = self.sync._load_volume_state()
            if saved_vol is not None:
                self.logger.info(f"Volume restored to {saved_vol}%")
        else:
            self.logger.info("No saved volume state found or restoration failed")

        self.logger.info("Executing initial synchronization...")
        self.check_and_sync()

        self.logger.info(f"Daemon active, checking every {self.check_interval}s...")
        while self.running:
            self.check_and_sync()
            time.sleep(self.check_interval)

        self.logger.info("Redragon Volume Sync Daemon closed")


if __name__ == "__main__":
    daemon = RedragonDaemonSimple()
    try:
        daemon.run()
    except KeyboardInterrupt:
        daemon.logger.info("Interrupted by user")
    except Exception as e:
        daemon.logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
