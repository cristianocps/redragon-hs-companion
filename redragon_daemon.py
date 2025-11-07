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
                self.logger.info("Headset detected!")
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
                if not self.sync.detect_card():
                    return False

            if self.sync.should_debounce():
                return True

            # Detect if it is on analog output
            is_analog = self.sync._is_analog_output()

            vol1, vol2 = self.sync.get_volumes()

            if vol1 is None or vol2 is None:
                self.logger.warning("Failed to get volumes")
                self.sync.card_id = None
                return False

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
            else:
                if self.last_volumes != (vol1, vol2):
                    self.logger.debug(f"Digital output: volumes synchronized PCM[0]={vol1}%, PCM[1]={vol2}%")
                self.last_volumes = (vol1, vol2)

            return True

        except Exception as e:
            self.logger.error(f"Error in check_and_sync: {e}")
            self.sync.card_id = None
            return False

    def run(self):
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)

        self.logger.info("Redragon Volume Sync Daemon started (simple mode: PCM[0] → PCM[1])")

        if not self.wait_for_headset():
            return

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
