#!/usr/bin/env python3
"""
Redragon Event Monitor
Monitora eventos ALSA e udev em tempo real para headsets Redragon sem fio
"""

import subprocess
import threading
import signal
import sys
import logging
import re
import select
from pathlib import Path
from redragon_volume_sync import RedragonVolumeSync, H878VolumeSync


class ALSAEventMonitor:
    """Monitora eventos ALSA usando alsactl monitor"""

    def __init__(self, card_id, callback):
        self.card_id = card_id
        self.callback = callback
        self.running = False
        self.process = None
        self.thread = None
        self.logger = logging.getLogger(__name__)

    def start(self):
        """Inicia o monitoramento de eventos ALSA"""
        if self.running:
            return

        self.running = True
        self.thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.thread.start()
        self.logger.info(f"Monitoramento ALSA iniciado para placa {self.card_id}")

    def _monitor_loop(self):
        """Loop de monitoramento usando alsactl monitor"""
        try:
            # Inicia alsactl monitor para a placa específica
            cmd = ['alsactl', 'monitor', f'hw:{self.card_id}']
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                bufsize=1
            )

            self.logger.info("alsactl monitor iniciado")

            # Lê eventos linha por linha
            while self.running and self.process.poll() is None:
                line = self.process.stdout.readline()
                if line:
                    line = line.strip()
                    # Detecta eventos de mudança de volume PCM
                    if 'PCM Playback Volume' in line or 'numid=9' in line or 'numid=10' in line:
                        self.logger.debug(f"Evento ALSA detectado: {line}")
                        self.callback()

        except Exception as e:
            self.logger.error(f"Erro no monitoramento ALSA: {e}")
        finally:
            if self.process:
                self.process.terminate()
                self.process.wait()

    def stop(self):
        """Para o monitoramento"""
        self.running = False
        if self.process:
            self.process.terminate()
        if self.thread:
            self.thread.join(timeout=2)


class UdevMonitor:
    """Monitora eventos udev para detectar conexão/desconexão do headset"""

    def __init__(self, callback):
        self.callback = callback
        self.running = False
        self.process = None
        self.thread = None
        self.logger = logging.getLogger(__name__)

    def start(self):
        """Inicia o monitoramento de eventos udev"""
        if self.running:
            return

        self.running = True
        self.thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.thread.start()
        self.logger.info("Monitoramento udev iniciado")

    def _monitor_loop(self):
        """Loop de monitoramento usando udevadm monitor"""
        try:
            # Monitora eventos de dispositivos de som
            cmd = ['udevadm', 'monitor', '--subsystem-match=sound', '--property']
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                bufsize=1
            )

            self.logger.info("udevadm monitor iniciado")

            # Lê eventos
            while self.running and self.process.poll() is None:
                line = self.process.stdout.readline()
                if line:
                    line = line.strip()
                    # Detecta eventos relacionados ao H878
                    if 'H878' in line or 'add' in line.lower() or 'remove' in line.lower():
                        self.logger.debug(f"Evento udev detectado: {line}")
                        self.callback()

        except Exception as e:
            self.logger.error(f"Erro no monitoramento udev: {e}")
        finally:
            if self.process:
                self.process.terminate()
                self.process.wait()

    def stop(self):
        """Para o monitoramento"""
        self.running = False
        if self.process:
            self.process.terminate()
        if self.thread:
            self.thread.join(timeout=2)


class RedragonEventDaemon:
    """Daemon baseado em eventos para headsets Redragon"""

    def __init__(self):
        self.running = True
        self.sync = RedragonVolumeSync()
        self.last_volumes = (None, None)
        self.last_pipewire_volume = None
        self.sink_name = None
        self.alsa_monitor = None
        self.udev_monitor = None
        self.sync_lock = threading.Lock()
        self.reconnect_attempts = 0
        self.max_reconnect_attempts = 10

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
        """Manipula sinais de término"""
        self.logger.info(f"Recebido sinal {signum}, encerrando daemon...")
        self.running = False

    def wait_for_headset(self):
        """Aguarda até que o headset seja detectado"""
        self.logger.info("Aguardando conexão do headset H878...")

        while self.running:
            if self.sync.detect_card():
                self.logger.info("Headset H878 detectado!")
                self.reconnect_attempts = 0
                # Detecta o sink do PipeWire
                self._detect_pipewire_sink()
                return True

            self.reconnect_attempts += 1
            if self.reconnect_attempts >= self.max_reconnect_attempts:
                self.logger.warning("Número máximo de tentativas de reconexão atingido")
                # Continua tentando, mas com intervalo maior
                import time
                time.sleep(30)
                self.reconnect_attempts = 0
            else:
                import time
                time.sleep(5)

        return False

    def _detect_pipewire_sink(self):
        """Detecta o sink do PipeWire para o headset Redragon"""
        try:
            result = subprocess.run(
                ["pactl", "list", "sinks", "short"],
                capture_output=True,
                text=True,
                check=True
            )

            # Procura por sinks Redragon/XiiSound/Weltrend
            for line in result.stdout.split('\n'):
                if any(pattern in line for pattern in ['XiiSound', 'Weltrend', 'Redragon']):
                    parts = line.split()
                    if len(parts) >= 2:
                        self.sink_name = parts[1]
                        self.logger.info(f"✓ PipeWire sink detectado: {self.sink_name}")
                        return True

            self.logger.warning("⚠️  Sink do PipeWire não detectado")
            return False

        except subprocess.CalledProcessError as e:
            self.logger.error(f"Erro ao detectar sink do PipeWire: {e}")
            return False

    def _get_pipewire_volume(self):
        """Obtém o volume atual do PipeWire (em porcentagem)"""
        if not self.sink_name:
            return None

        try:
            result = subprocess.run(
                ["pactl", "get-sink-volume", self.sink_name],
                capture_output=True,
                text=True,
                check=True
            )

            # Parse: "Volume: front-left: 65536 / 100% / 0,00 dB"
            match = re.search(r'(\d+)%', result.stdout)
            if match:
                return int(match.group(1))

            return None

        except subprocess.CalledProcessError:
            return None

    def _sync_pipewire_to_alsa(self):
        """Sincroniza o volume do PipeWire para os controles ALSA"""
        pw_volume = self._get_pipewire_volume()

        if pw_volume is None:
            return False

        # Se o volume não mudou, não faz nada
        if pw_volume == self.last_pipewire_volume:
            return False

        self.last_pipewire_volume = pw_volume

        # Aplica o volume do PipeWire aos controles ALSA
        self.logger.info(f"🔊 PipeWire volume mudou para {pw_volume}%, aplicando aos controles ALSA")

        success = self.sync.set_volume(pw_volume, silent=True)

        if success:
            # Atualiza o volume armazenado
            self.last_volumes = (pw_volume, pw_volume)

        return success

    def on_alsa_event(self):
        """Callback para eventos ALSA"""
        with self.sync_lock:
            self.check_and_sync()

    def on_udev_event(self):
        """Callback para eventos udev"""
        self.logger.info("Evento de dispositivo detectado, verificando headset...")

        # Para monitores antigos
        if self.alsa_monitor:
            self.alsa_monitor.stop()
            self.alsa_monitor = None

        # Re-detecta o headset
        if self.sync.detect_card():
            self.logger.info("Headset reconectado!")
            # Sincroniza imediatamente
            with self.sync_lock:
                self.sync.sync_volumes()
            # Reinicia monitor ALSA
            self.start_alsa_monitor()
        else:
            self.logger.info("Headset desconectado")

    def start_alsa_monitor(self):
        """Inicia o monitor de eventos ALSA"""
        if not self.sync.card_id:
            return

        if self.alsa_monitor:
            self.alsa_monitor.stop()

        self.alsa_monitor = ALSAEventMonitor(
            self.sync.card_id,
            self.on_alsa_event
        )
        self.alsa_monitor.start()

    def start_udev_monitor(self):
        """Inicia o monitor de eventos udev"""
        self.udev_monitor = UdevMonitor(self.on_udev_event)
        self.udev_monitor.start()

    def check_and_sync(self):
        """Verifica e sincroniza os volumes se necessário

        Estratégia:
        1. Monitora o volume do PipeWire e aplica aos controles ALSA
        2. Sincroniza PCM[0] (master) para PCM[1]
        """
        try:
            if not self.sync.card_id:
                return False

            # Debounce: não verifica se acabamos de definir
            if self.sync.should_debounce():
                return True

            # Primeiro, sincroniza PipeWire → ALSA se necessário
            self._sync_pipewire_to_alsa()

            # Depois, verifica se PCM[0] e PCM[1] estão sincronizados
            vol1, vol2 = self.sync.get_volumes()

            if vol1 is None or vol2 is None:
                self.logger.warning("Não foi possível obter volumes")
                return False

            # Verifica se mudou desde a última verificação
            current_volumes = (vol1, vol2)

            if current_volumes != self.last_volumes:
                self.logger.debug(f"Volumes: PCM[0]={vol1}%, PCM[1]={vol2}%")

                # Se dessincronizados, copia PCM[0] para PCM[1]
                if vol1 != vol2:
                    self.logger.info(f"Sincronizando PCM[1] para {vol1}% (copiando de PCM[0])")

                    if self.sync.sync_from_master():
                        self.last_volumes = (vol1, vol1)
                        return True
                    else:
                        self.logger.error("Falha ao sincronizar volumes")
                else:
                    self.last_volumes = current_volumes

            return True

        except Exception as e:
            self.logger.error(f"Erro no check_and_sync: {e}")
            return False

    def run(self):
        """Loop principal do daemon"""
        import time

        # Registrar handlers de sinal
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)

        self.logger.info("Redragon Volume Sync Daemon (Event-based) iniciado")

        # Aguarda o headset na inicialização
        if not self.wait_for_headset():
            return

        # Sincronização inicial
        self.logger.info("Executando sincronização inicial...")
        self.check_and_sync()

        # Inicia monitores de eventos
        self.logger.info("Iniciando monitores de eventos...")
        self.start_alsa_monitor()
        self.start_udev_monitor()

        # Loop principal - verifica PipeWire periodicamente E aguarda eventos ALSA
        self.logger.info("Daemon ativo, monitorando PipeWire e aguardando eventos ALSA...")
        try:
            while self.running:
                # Verifica volume do PipeWire periodicamente (a cada 2 segundos)
                # Isso é necessário porque mudanças via controles do sistema não
                # disparam eventos ALSA quando o PipeWire usa volume em software
                with self.sync_lock:
                    self.check_and_sync()
                time.sleep(2)
        except KeyboardInterrupt:
            pass

        # Cleanup
        self.logger.info("Parando monitores...")
        if self.alsa_monitor:
            self.alsa_monitor.stop()
        if self.udev_monitor:
            self.udev_monitor.stop()

        self.logger.info("Redragon Volume Sync Daemon encerrado")


# Alias para compatibilidade com código existente
H878EventDaemon = RedragonEventDaemon


def main():
    daemon = RedragonEventDaemon()

    try:
        daemon.run()
    except KeyboardInterrupt:
        daemon.logger.info("Interrompido pelo usuário")
    except Exception as e:
        daemon.logger.error(f"Erro fatal: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
