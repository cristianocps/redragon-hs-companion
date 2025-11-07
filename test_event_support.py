#!/usr/bin/env python3
"""Script de teste para verificar suporte a eventos"""

import subprocess
import sys

def check_event_support():
    """Verifica se o sistema suporta monitoramento por eventos"""

    print("🔍 Verificando suporte a monitoramento por eventos...\n")

    # Verifica alsactl
    result = subprocess.run(
        ['which', 'alsactl'],
        capture_output=True,
        check=False
    )
    has_alsactl = result.returncode == 0

    if has_alsactl:
        alsactl_path = result.stdout.decode().strip()
        print(f"✅ alsactl encontrado: {alsactl_path}")
    else:
        print("❌ alsactl não encontrado")

    # Verifica udevadm
    result = subprocess.run(
        ['which', 'udevadm'],
        capture_output=True,
        check=False
    )
    has_udevadm = result.returncode == 0

    if has_udevadm:
        udevadm_path = result.stdout.decode().strip()
        print(f"✅ udevadm encontrado: {udevadm_path}")
    else:
        print("❌ udevadm não encontrado")

    print()

    if has_alsactl and has_udevadm:
        print("🎉 Seu sistema SUPORTA monitoramento por eventos!")
        print("   O daemon usará modo de EVENTOS por padrão (zero latência)")
        return 0
    else:
        print("⚠️  Seu sistema NÃO suporta completamente monitoramento por eventos")
        print("   O daemon usará modo de POLLING por padrão (verifica a cada 2s)")
        print("\n   Para habilitar eventos, instale:")
        if not has_alsactl:
            print("   - alsa-utils (fornece alsactl)")
        if not has_udevadm:
            print("   - systemd (fornece udevadm)")
        return 1

if __name__ == "__main__":
    sys.exit(check_event_support())
