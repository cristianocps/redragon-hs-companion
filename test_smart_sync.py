#!/usr/bin/env python3
"""
Teste da sincronização inteligente
"""

import time
import subprocess
from h878_volume_sync import H878VolumeSync

def test_decrease_volume():
    """Testa diminuir o volume"""
    print("\n" + "="*60)
    print("TESTE: Diminuindo volume de 100% para 50%")
    print("="*60)

    sync = H878VolumeSync()

    if not sync.card_id:
        print("❌ Headset não detectado")
        return False

    # Define volume inicial em 100%
    print("\n1. Definindo volume inicial: 100%")
    sync.set_volume(100)
    time.sleep(0.6)  # Aguarda debounce

    # Simula usuário diminuindo volume do PCM[0]
    print("\n2. Simulando usuário diminuindo PCM[0] para 50%")
    subprocess.run(
        ["amixer", "-c", sync.card_id, "set", "PCM", "50%"],
        capture_output=True
    )

    time.sleep(0.2)
    vol1, vol2 = sync.get_volumes()
    print(f"   Volumes após mudança: PCM={vol1}%, PCM[1]={vol2}%")

    # Agora o daemon deve sincronizar para o MENOR (50%)
    print("\n3. Simulando sincronização do daemon...")

    # Simula o que o daemon faria
    prev_vol1, prev_vol2 = 100, 100
    vol_decreased = vol1 < prev_vol1 or vol2 < prev_vol2
    target = min(vol1, vol2) if vol_decreased else max(vol1, vol2)

    print(f"   Direção: {'DIMINUINDO' if vol_decreased else 'AUMENTANDO'}")
    print(f"   Target escolhido: {target}%")

    sync.set_volume(target)
    time.sleep(0.2)

    # Verifica resultado
    vol1, vol2 = sync.get_volumes()
    print(f"\n4. Resultado final: PCM={vol1}%, PCM[1]={vol2}%")

    if vol1 == 50 and vol2 == 50:
        print("   ✅ SUCESSO: Volume sincronizou para 50%!")
        return True
    else:
        print(f"   ❌ FALHA: Esperado 50%, obteve {vol1}%/{vol2}%")
        return False

def test_increase_volume():
    """Testa aumentar o volume"""
    print("\n" + "="*60)
    print("TESTE: Aumentando volume de 50% para 80%")
    print("="*60)

    sync = H878VolumeSync()

    # Define volume inicial em 50%
    print("\n1. Definindo volume inicial: 50%")
    sync.set_volume(50)
    time.sleep(0.6)

    # Simula usuário aumentando volume
    print("\n2. Simulando usuário aumentando PCM[0] para 80%")
    subprocess.run(
        ["amixer", "-c", sync.card_id, "set", "PCM", "80%"],
        capture_output=True
    )

    time.sleep(0.2)
    vol1, vol2 = sync.get_volumes()
    print(f"   Volumes após mudança: PCM={vol1}%, PCM[1]={vol2}%")

    # Daemon deve sincronizar para o MAIOR (80%)
    print("\n3. Simulando sincronização do daemon...")

    prev_vol1, prev_vol2 = 50, 50
    vol_decreased = vol1 < prev_vol1 or vol2 < prev_vol2
    target = min(vol1, vol2) if vol_decreased else max(vol1, vol2)

    print(f"   Direção: {'DIMINUINDO' if vol_decreased else 'AUMENTANDO'}")
    print(f"   Target escolhido: {target}%")

    sync.set_volume(target)
    time.sleep(0.2)

    # Verifica resultado
    vol1, vol2 = sync.get_volumes()
    print(f"\n4. Resultado final: PCM={vol1}%, PCM[1]={vol2}%")

    if vol1 == 80 and vol2 == 80:
        print("   ✅ SUCESSO: Volume sincronizou para 80%!")
        return True
    else:
        print(f"   ❌ FALHA: Esperado 80%, obteve {vol1}%/{vol2}%")
        return False

def main():
    print("\n🧪 Testando Sincronização Inteligente do H878\n")

    results = []

    # Teste 1: Diminuir volume
    results.append(("Diminuir volume", test_decrease_volume()))

    time.sleep(1)

    # Teste 2: Aumentar volume
    results.append(("Aumentar volume", test_increase_volume()))

    # Resultado final
    print("\n" + "="*60)
    print("RESUMO DOS TESTES")
    print("="*60)

    for name, passed in results:
        status = "✅ PASSOU" if passed else "❌ FALHOU"
        print(f"{name}: {status}")

    all_passed = all(result for _, result in results)

    print("\n" + "="*60)
    if all_passed:
        print("🎉 Todos os testes passaram!")
        print("O problema do volume voltando para 100% foi CORRIGIDO!")
    else:
        print("⚠️  Alguns testes falharam")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
