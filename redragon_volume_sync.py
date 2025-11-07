#!/usr/bin/env python3
"""
Redragon Wireless Headset Volume Synchronizer
Sincroniza os canais de volume de headsets Redragon sem fio (via dongle) no Linux

Compatível com:
- Redragon H878
- Outros headsets Redragon sem fio com problema similar
"""

import subprocess
import sys
import argparse
import re
import time
from typing import Tuple, Optional, List


class RedragonVolumeSync:
    # Padrões para detectar headsets Redragon/similares
    DEVICE_PATTERNS = [
        r'[Hh]\d{3}',                    # H878, H848, etc
        r'Wireless\s+headset',           # Padrão genérico
        r'XiiSound',                     # Fabricante
        r'Weltrend',                     # Outro fabricante
        r'Redragon',                     # Marca
    ]

    def __init__(self, device_pattern: str = None):
        """
        Args:
            device_pattern: Padrão específico para buscar (opcional)
        """
        self.custom_pattern = device_pattern
        self.card_id = None
        self.device_name = None
        self.last_set_time = 0
        self.debounce_delay = 0.5  # segundos
        self.detect_card()

    def detect_card(self) -> bool:
        """Detecta automaticamente headsets Redragon sem fio"""
        try:
            result = subprocess.run(
                ["aplay", "-l"],
                capture_output=True,
                text=True,
                check=True
            )

            # Se um padrão customizado foi fornecido, usa apenas ele
            patterns_to_check = [self.custom_pattern] if self.custom_pattern else self.DEVICE_PATTERNS

            # Procura pela placa usando os padrões
            for line in result.stdout.split('\n'):
                if 'placa' in line.lower():
                    for pattern in patterns_to_check:
                        if re.search(pattern, line, re.IGNORECASE):
                            match = re.search(r'placa (\d+):', line)
                            if match:
                                self.card_id = match.group(1)
                                # Extrai o nome do dispositivo
                                name_match = re.search(r'\[([^\]]+)\]', line)
                                self.device_name = name_match.group(1) if name_match else "Headset Redragon"
                                print(f"✓ {self.device_name} detectado na placa {self.card_id}")
                                return True

            print("✗ Headset Redragon sem fio não encontrado")
            print("   Dispositivos compatíveis: H878, H848, etc (via dongle USB)")
            return False

        except subprocess.CalledProcessError as e:
            print(f"✗ Erro ao detectar dispositivos de áudio: {e}")
            return False

    def get_volumes(self) -> Tuple[Optional[int], Optional[int]]:
        """Obtém os volumes atuais dos dois controles PCM"""
        if not self.card_id:
            return None, None

        try:
            result = subprocess.run(
                ["amixer", "-c", self.card_id, "contents"],
                capture_output=True,
                text=True,
                check=True
            )

            pcm_vol1 = None
            pcm_vol2 = None

            lines = result.stdout.split('\n')
            for i, line in enumerate(lines):
                if "name='PCM Playback Volume'" in line:
                    # Próxima linha contém os valores
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
            print(f"✗ Erro ao obter volumes: {e}")
            return None, None

    def set_volume(self, volume: int, silent: bool = False) -> bool:
        """Define o volume em ambos os controles PCM"""
        if not self.card_id:
            if not silent:
                print("✗ Headset não detectado")
            return False

        if not 0 <= volume <= 100:
            if not silent:
                print("✗ Volume deve estar entre 0 e 100")
            return False

        try:
            # Define PCM,0 (2 canais) - Usado pelo PipeWire/PulseAudio
            subprocess.run(
                ["amixer", "-c", self.card_id, "set", "PCM", f"{volume}%"],
                capture_output=True,
                check=True
            )

            # Define PCM,1 (1 canal) - Não controlado pelo PipeWire
            subprocess.run(
                ["amixer", "-c", self.card_id, "cset", f"numid=10", f"{volume}"],
                capture_output=True,
                check=True
            )

            # Atualiza timestamp do último set
            self.last_set_time = time.time()

            if not silent:
                print(f"✓ Volume sincronizado para {volume}%")
            return True

        except subprocess.CalledProcessError as e:
            if not silent:
                print(f"✗ Erro ao definir volume: {e}")
            return False

    def sync_from_master(self) -> bool:
        """Sincroniza PCM[1] copiando o valor de PCM[0] (master)

        PCM[0] (numid=9) é controlado pelo PipeWire/PulseAudio.
        PCM[1] (numid=10) não é controlado e precisa ser sincronizado manualmente.
        """
        vol1, vol2 = self.get_volumes()

        if vol1 is None or vol2 is None:
            return False

        # Se já estão sincronizados, não faz nada
        if vol1 == vol2:
            return False

        # Copia o volume do PCM[0] (master) para PCM[1]
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
        """Verifica se devemos aguardar (debounce) antes de sincronizar"""
        elapsed = time.time() - self.last_set_time
        return elapsed < self.debounce_delay

    def sync_volumes(self, prefer_lower: bool = False) -> bool:
        """Sincroniza os volumes

        Args:
            prefer_lower: Se True, usa o menor valor ao invés do maior.
                         Útil quando o usuário está diminuindo o volume.
        """
        vol1, vol2 = self.get_volumes()

        if vol1 is None or vol2 is None:
            print("✗ Não foi possível obter volumes atuais")
            return False

        # Escolhe target baseado na preferência
        if prefer_lower:
            target_volume = min(vol1, vol2)
        else:
            target_volume = max(vol1, vol2)

        print(f"📊 Volumes atuais: PCM={vol1}%, PCM[1]={vol2}%")
        print(f"🎯 Sincronizando para: {target_volume}%")

        return self.set_volume(target_volume)

    def smart_sync(self, vol1: int, vol2: int, prev_vol1: int = None, prev_vol2: int = None) -> bool:
        """Sincronização inteligente que detecta a direção da mudança

        Args:
            vol1, vol2: Volumes atuais
            prev_vol1, prev_vol2: Volumes anteriores (opcional)

        Returns:
            True se sincronizou, False se não foi necessário ou houve erro
        """
        if vol1 == vol2:
            return False  # Já sincronizado

        # Se temos histórico, detecta direção
        if prev_vol1 is not None and prev_vol2 is not None:
            # Detecta qual controle mudou
            vol1_changed = vol1 != prev_vol1
            vol2_changed = vol2 != prev_vol2

            # Detecta direção (aumentando ou diminuindo)
            vol1_decreased = vol1 < prev_vol1
            vol2_decreased = vol2 < prev_vol2

            # Se qualquer volume diminuiu, usa o menor
            if vol1_decreased or vol2_decreased:
                target = min(vol1, vol2)
            # Se aumentou, usa o maior
            else:
                target = max(vol1, vol2)
        else:
            # Sem histórico, usa o maior (comportamento seguro)
            target = max(vol1, vol2)

        return self.set_volume(target, silent=True)

    def show_status(self) -> None:
        """Mostra o status atual do headset"""
        if not self.card_id:
            print("❌ Headset Redragon não encontrado")
            return

        vol1, vol2 = self.get_volumes()

        device_display = self.device_name or "Headset Redragon"

        print("\n" + "="*50)
        print(f"  {device_display} - Status")
        print("="*50)
        print(f"  Placa: {self.card_id}")
        print(f"  PCM Volume (2 canais): {vol1}%")
        print(f"  PCM Volume [1] (1 canal): {vol2}%")

        if vol1 == vol2:
            print("  Status: ✓ Sincronizado")
        else:
            print("  Status: ✗ Dessincronizado")

        print("="*50 + "\n")


# Alias para compatibilidade com código existente
H878VolumeSync = RedragonVolumeSync


def main():
    parser = argparse.ArgumentParser(
        description="Sincronizador de volume para headsets Redragon sem fio (via dongle)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Dispositivos compatíveis:
  - Redragon H878, H848, H510, etc (modelos sem fio via dongle USB)
  - Detecta automaticamente o dispositivo conectado

Exemplos:
  %(prog)s sync          # Sincroniza volumes automaticamente
  %(prog)s set 75        # Define volume para 75%
  %(prog)s status        # Mostra status atual
  %(prog)s -d H848 sync  # Especifica modelo específico
        """
    )

    parser.add_argument(
        "command",
        choices=["sync", "set", "status"],
        help="Comando a executar"
    )

    parser.add_argument(
        "volume",
        nargs="?",
        type=int,
        help="Volume (0-100) para o comando 'set'"
    )

    parser.add_argument(
        "-d", "--device",
        type=str,
        help="Padrão de busca do dispositivo (ex: H878, H848)",
        default=None
    )

    args = parser.parse_args()

    sync = RedragonVolumeSync(device_pattern=args.device)

    if not sync.card_id:
        print("\n⚠️  Certifique-se de que o headset Redragon está conectado (via dongle USB)")
        sys.exit(1)

    if args.command == "sync":
        success = sync.sync_volumes()
        sys.exit(0 if success else 1)

    elif args.command == "set":
        if args.volume is None:
            print("✗ Especifique um valor de volume (0-100)")
            sys.exit(1)
        success = sync.set_volume(args.volume)
        sys.exit(0 if success else 1)

    elif args.command == "status":
        sync.show_status()
        sys.exit(0)


if __name__ == "__main__":
    main()
