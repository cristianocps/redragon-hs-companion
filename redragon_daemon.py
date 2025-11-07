#!/usr/bin/env python3
"""
Redragon Volume Sync Daemon - Versão Simples
Monitora e sincroniza automaticamente PCM[0] → PCM[1]
NÃO interfere com o PipeWire
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

        # Configurar logging
        log_dir = Path.home() / ".local" / "share" / "h878-fixer"
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
        self.logger.info(f"Recebido sinal {signum}, encerrando daemon...")
        self.running = False

    def wait_for_headset(self):
        self.logger.info("Aguardando conexão do headset...")
        while self.running:
            if self.sync.detect_card():
                self.logger.info("Headset detectado!")
                return True
            time.sleep(5)
        return False

    def check_and_sync(self):
        """Sincroniza PCM[0] → PCM[1] APENAS"""
        try:
            if not self.sync.card_id:
                if not self.sync.detect_card():
                    return False

            if self.sync.should_debounce():
                return True

            vol1, vol2 = self.sync.get_volumes()

            if vol1 is None or vol2 is None:
                self.logger.warning("Não foi possível obter volumes")
                self.sync.card_id = None
                return False

            # Sincroniza apenas se PCM[0] != PCM[1]
            if vol1 != vol2:
                self.logger.info(f"Sincronizando PCM[1] para {vol1}% (copiando de PCM[0])")
                if self.sync.sync_from_master():
                    self.last_volumes = (vol1, vol1)
                else:
                    self.logger.error("Falha ao sincronizar volumes")
            else:
                if self.last_volumes != (vol1, vol2):
                    self.logger.debug(f"Volumes sincronizados: PCM[0]={vol1}%, PCM[1]={vol2}%")
                self.last_volumes = (vol1, vol2)

            return True

        except Exception as e:
            self.logger.error(f"Erro no check_and_sync: {e}")
            self.sync.card_id = None
            return False

    def run(self):
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)

        self.logger.info("Redragon Volume Sync Daemon iniciado (modo simples: PCM[0] → PCM[1])")

        if not self.wait_for_headset():
            return

        self.logger.info("Executando sincronização inicial...")
        self.check_and_sync()

        self.logger.info(f"Daemon ativo, verificando a cada {self.check_interval}s...")
        while self.running:
            self.check_and_sync()
            time.sleep(self.check_interval)

        self.logger.info("Redragon Volume Sync Daemon encerrado")


if __name__ == "__main__":
    daemon = RedragonDaemonSimple()
    try:
        daemon.run()
    except KeyboardInterrupt:
        daemon.logger.info("Interrompido pelo usuário")
    except Exception as e:
        daemon.logger.error(f"Erro fatal: {e}", exc_info=True)
        sys.exit(1)
