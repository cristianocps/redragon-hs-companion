# Plano: modo `--config-only` no instalador (alternativa sem daemon, issue #6)

## Objetivo

Adicionar ao `install.sh` uma alternativa ao método baseado em daemons, seguindo os
findings da issue #6: correção somente via configuração do WirePlumber + serviço
systemd oneshot que trava o PCM em 100%. Ativado exclusivamente pela flag
`--config-only` (sem prompt interativo). Scripts, CLI e widgets continuam sendo
instalados normalmente; o que muda é **qual correção é aplicada/ativada**.

Decisões do usuário:
- Seleção do modo: **apenas flag `--config-only`** (padrão continua daemon).
- Escopo: **instala tudo** (scripts, CLI, widgets); no modo config-only a correção
  ativada é WirePlumber + `restore-headset.service` em vez dos daemons.
- Config cobrindo outros device names + autodetecção do dongle.

## Pesquisa de identificadores (web + dongle real conectado)

**Verificado localmente com o dongle H878 conectado:**
- `device.name = "alsa_card.usb-XiiSound_Technology_Corporation_H878_Wireless_headset-00"`
- `device.vendor.id = "0x040b"`, `device.product.id = "0x0897"` (formato PipeWire
  inclui prefixo `0x`)
- `lsusb`: `ID 040b:0897 Weltrend Semiconductor H878 Wireless headset`
- `/proc/asound/cards`: `4 [headset ]: USB-Audio - H878 Wireless headset` →
  grep por padrão retorna card number `4` corretamente
- `amixer contents`: dois pares independentes `PCM Playback Switch`/`Volume`
  (numid 9/10, índices 0 e 1) — confirma o bug descrito na alsa-ucm-conf#760

**Família de rebrands do mesmo chipset 040b:0897 (Weltrend/XiiSound):**

| Dispositivo | VID:PID | String do produto | Fonte |
|---|---|---|---|
| Redragon H878 Wireless | `040b:0897` | `H878 Wireless headset` | verificado local |
| Redragon H848 (IRE PRO) Wireless | `040b:0897` | `H848 Wireless headset` | linux-hardware.org/?id=usb:040b-0897 |
| Redragon H510-PRO Wireless | `040b:0897` | strings `XiiSound Technology Corporation` | LKML patch ALSA jul/2026 |
| Havit Fuxi-H3 | `040b:0897` | `FuxiH3`/`Fuxi-H3` em /proc/asound/cards | github.com/cleisonsantos/havit-fuxi-h3-linux-fix |
| Redragon H818 | família Weltrend | `Weltrend 2.4G Wireless headset` / `2.4G wireless headset` | forums.linuxmint.com t=406530 |

Notas:
- O match por `{ device.vendor.id = "0x040b", device.product.id = "0x0897" }`
  cobre a família inteira de rebrands — é o identificador primário.
- Existe patch de quirk no kernel (LKML jul/2026, Agustin Luzardo) para esse
  VID:PID; se um dia for mergeado, o modo config-only pode se tornar desnecessário.
  Mencionar no README como nota de futuro.
- O repo de referência `havit-fuxi-h3-linux-fix` (MIT) valida a abordagem em
  WirePlumber 0.4 **e** 0.5 com `monitor.alsa.rules` + `update-props`, e testa
  `api.alsa.soft-mixer=true` + `api.alsa.enable-hw-volume=false`.
- H510 Zeus (com fio, listado no README) é outro dispositivo — fora do escopo do
  modo config-only, que mira a família de dongles 2.4G.

## Arquivos novos no repositório

### 1. `wireplumber/99-redragon-headset-fix.conf`
Arquivo estático (copiado verbatim — sem geração via sed). Combina o match por
VID:PID (família inteira) com padrões de nome (defesa em profundidade para
variantes com PID diferente, ex.: H818), e mescla as props da issue #6 com as do
repo fuxi-h3 (battle-tested em WP 0.4/0.5). Comentário no cabeçalho creditando
a issue #6 e o repo havit-fuxi-h3-linux-fix:

```
monitor.alsa.rules = [
  {
    matches = [
      {
        device.vendor.id = "0x040b"
        device.product.id = "0x0897"
      }
      {
        device.name = "~alsa_card.usb-XiiSound*"
      }
      {
        device.name = "~alsa_card.usb-Weltrend*"
      }
      {
        device.name = "~alsa_card.usb-*H878*"
      }
      {
        device.name = "~alsa_card.usb-*H848*"
      }
      {
        device.name = "~alsa_card.usb-*H510*"
      }
      {
        device.name = "~alsa_card.usb-*Fuxi*"
      }
      {
        device.name = "~alsa_card.usb-*Redragon*"
      }
      {
        device.name = "~alsa_card.usb-*2.4G*Wireless*"
      }
    ]
    actions = {
      update-props = {
        api.alsa.soft-mixer = true
        api.alsa.ignore-dB = true
        api.alsa.enable-hw-volume = false
        device.profile-set = "analog-only.conf"
      }
    }
  }
]
```

### 2. `redragon-lock-pcm.sh` (helper com detecção em runtime)
Substitui a ideia anterior de gerar o service com card fixa: detecta a card em
tempo de execução (robusto a renumeração de cards entre boots) e cobre as
variantes de firmware. Instalado em `~/.local/bin` por `install_scripts`
(sempre, não só no modo config-only — consistente com "instala tudo").

Comportamento (baseado no fuxi-h3-volume-fix.sh, adaptado aos padrões do repo):
- `sleep 2` inicial.
- `CARD=$(grep -iE 'H878|H848|H510|Fuxi|XiiSound|Weltrend|Redragon|Wireless headset|2\.4G' /proc/asound/cards | head -1 | awk '{print $1}')`
  — validado nesta máquina (retornou `4` com o H878).
- Se não achar card: exit 1 com `--retry` (systemd tenta de novo), exit 0 sem.
- `amixer -c "$CARD" sset 'PCM',0 100%,100%` (volume estéreo L/R)
- `amixer -c "$CARD" sset 'PCM',1 100%` e `sset 'PCM',1 on` (variantes de
  firmware: segundo PCM como volume ou como switch — cobre ambos)
- Idempotente; `export PATH=/usr/sbin:/usr/bin:/sbin:/bin` no topo.

### 3. `systemd/restore-headset.service`
Estático (sem geração), usando o helper + retry para vencer a corrida do boot
(melhor que o `ExecStartPre=/usr/bin/sleep 2` fixo da issue):

```ini
[Unit]
Description=Lock Redragon/XiiSound Headset PCM Channels at 100 Percent
After=pipewire.service

[Service]
Type=oneshot
ExecStart=%h/.local/bin/redragon-lock-pcm.sh --retry
Restart=on-failure
RestartSec=3
RemainAfterExit=yes

[Install]
WantedBy=default.target
```

(`%h` já é usado no `systemd/redragon-control-daemon.service` existente.)

## Mudanças em `install.sh`

1. **Parse da flag**: aceitar `--config-only` (seta `CONFIG_ONLY=true`) no loop
   de argumentos. Atualizar `show_help()` documentando a flag e os dois modos.

2. **`install_scripts()`**: copiar também `redragon-lock-pcm.sh` para
   `$INSTALL_DIR` com `chmod +x` (independente do modo).

3. **Nova função `detect_dongle()`** (informativa/validação, não gera config):
   1. `lsusb | grep -iE '040b:0897|XiiSound|Weltrend|Redragon'` → dongle USB.
   2. `pactl list cards` → grepar bloco com `device.vendor.id = "0x040b"` /
      padrões de nome para exibir o `device.name`/`device.nick` detectado.
   3. `grep -iE <padrões> /proc/asound/cards` → card ALSA atual.
   4. Nada detectado → `print_info` avisando que a config foi instalada mesmo
      assim e sugerindo reconectar o dongle e rodar
      `systemctl --user restart wireplumber pipewire`.
   - Resultado usado apenas para feedback no fim da instalação.

4. **Nova função `install_config_only_fix()`**:
   - `mkdir -p ~/.config/wireplumber/wireplumber.conf.d` e copia
     `wireplumber/99-redragon-headset-fix.conf` para lá.
   - Copia `systemd/restore-headset.service` para `$SYSTEMD_DIR`.
   - Limpa cache do WirePlumber: `rm -rf ~/.local/state/wireplumber/*`.
   - `systemctl --user daemon-reload`.
   - `systemctl --user enable --now restore-headset.service`.
   - `systemctl --user restart wireplumber pipewire` (com `|| true` + mensagem
     caso a stack não esteja rodando).
   - Roda `detect_dongle` para o resumo final.
   - Sem prompt de enable: a flag já expressa a intenção.

5. **`main()`**: quando `CONFIG_ONLY=true`, chamar `install_config_only_fix` no
   lugar de `install_systemd_service`. Instalação de scripts e
   extensão/applet/widget inalteradas.

6. **`print_usage_info()`**: no modo config-only, bloco explicando que o volume é
   gerenciado pelo PipeWire (soft-mixer; controle nativo do DE funciona), qual
   dongle/card foi detectado, que o serviço ativo é `restore-headset.service`, e
   que CLI/daemons estão instalados mas não habilitados.

7. **`test_installation()`**: manter — `redragon_volume_sync.py status` usa
   `amixer`/`aplay` diretamente e funciona nos dois modos.

## Mudanças em `uninstall.sh`

- Parar/desabilitar/remover `restore-headset.service` (mesmo padrão dos services
  existentes: `is-active` → stop, `is-enabled` → disable, `rm -f`).
- Remover `~/.config/wireplumber/wireplumber.conf.d/99-redragon-headset-fix.conf`
  se existir, com `print_info` sugerindo
  `systemctl --user restart wireplumber pipewire` para reverter o perfil.
- Remover `$INSTALL_DIR/redragon-lock-pcm.sh` junto dos demais scripts.

## Mudanças em `README.md`

- Nova subseção em **Installation** documentando `./install.sh --config-only`:
  o que faz, família de dispositivos coberta (040b:0897: H878, H848, H510-PRO
  Wireless, Havit Fuxi-H3 e rebrands XiiSound/Weltrend), por que é útil (distros
  imutáveis como Fedora Silverblue, sem daemons), crédito à issue #6 e ao repo
  havit-fuxi-h3-linux-fix, e nota sobre o quirk de kernel em discussão na LKML.
- Atualizar **Project Structure** com os 3 novos arquivos.
- Nota de que nesse modo o volume é controlado pelo PipeWire (soft-mixer) e o
  controle nativo do desktop já funciona.

## Fora de escopo (possível follow-up)

- Regra udev em `/etc/udev/rules.d` para re-aplicar o lock de PCM em hotplug
  (como faz o repo fuxi-h3). Hoje o lock ocorre no login; com soft-mixer +
  `enable-hw-volume=false` o PipeWire não delega volume ao hardware, mas um
  re-plug do dongle pode exigir re-lock. Requer sudo para instalar a regra —
  avaliar separadamente.

## Validação

- `bash -n install.sh uninstall.sh redragon-lock-pcm.sh` (syntax check).
- `./install.sh --help` mostra a flag.
- Testar `detect_dongle` e o grep de `/proc/asound/cards` com o dongle conectado
  (já validado: retorna card `4`) e sem o dongle (caminho de aviso).
- Testar `redragon-lock-pcm.sh` manualmente com o dongle conectado:
  `amixer -c 4 sget 'PCM',0` e `sget 'PCM',1` devem mostrar 100%.
- Após instalar no modo config-only: `pactl list sinks | grep -E "soft-mixer|enable-hw-volume"`
  deve mostrar `api.alsa.soft-mixer = "true"` e
  `api.alsa.enable-hw-volume = "false"`.
- Lint: o repo não tem linter configurado; validação é o syntax check do bash.
