# Redragon Volume Sync

Solução completa para sincronizar automaticamente os canais de volume de **Headsets Redragon sem fio** (H878, H848, H510, etc.) no Linux.

## 🎯 Problema

Os headsets Redragon sem fio (como H878, H848, H510) apresentam um problema no Linux onde os dois lados do fone só funcionam corretamente quando o volume dos dois canais de reprodução é definido separadamente via `alsamixer`. Este projeto resolve esse problema de forma automática e conveniente.

## ✨ Funcionalidades

- 🔧 **Script CLI** - Controle manual via linha de comando
- 🤖 **Daemon Automático** - Sincronização automática em background
- ⚡ **Monitoramento por Eventos** - Reage em tempo real a mudanças (ALSA + udev)
- ⏱️ **Fallback Polling** - Modo de verificação periódica quando eventos não estão disponíveis
- 🎨 **Extensão GNOME** - Interface gráfica para GNOME Shell
- 🍰 **Applet Cinnamon** - Interface gráfica para Cinnamon Desktop
- 🚀 **Auto-detecção** - Detecta automaticamente quando o headset é conectado
- 📊 **Sincronização Inteligente** - Usa o maior volume como referência

## 📋 Requisitos

- Python 3
- alsa-utils (amixer, aplay)
- systemd (para o daemon)
- GNOME Shell 45+ ou Cinnamon 5.0+ (para interface gráfica)

### Instalação de dependências

**Ubuntu/Debian:**
```bash
sudo apt install python3 alsa-utils
```

**Fedora:**
```bash
sudo dnf install python3 alsa-utils
```

**Arch Linux:**
```bash
sudo pacman -S python alsa-utils
```

## 🚀 Instalação

> 📦 **Múltiplos formatos disponíveis:** Script de instalação, Flatpak, pacotes .deb, extensões GNOME/Cinnamon separadas. Veja [DISTRIBUTION.md](DISTRIBUTION.md) para detalhes.

### Instalação Automática via Script (Recomendado)

```bash
cd ~/repos/h878-fixer
./install.sh
```

O script de instalação irá:
1. Verificar dependências
2. Instalar os scripts em `~/.local/bin`
3. Configurar o serviço systemd
4. Instalar a extensão GNOME (se aplicável)
5. Instalar o applet Cinnamon (se aplicável)

### Instalação via Pacote Debian (.deb)

```bash
# Download do release mais recente
wget https://github.com/cristiano/h878-fixer/releases/latest/download/redragon-volume-sync_VERSION_all.deb

# Instalar
sudo dpkg -i redragon-volume-sync_VERSION_all.deb

# Ativar serviço
systemctl --user enable --now redragon-volume-sync.service
```

### Instalação via Flatpak

⚠️ **Nota:** Flatpak tem limitações para este tipo de projeto. Veja [DISTRIBUTION.md](DISTRIBUTION.md) para detalhes.

```bash
# Instalar do bundle
flatpak install --user redragon-volume-sync.flatpak

# Executar configuração
flatpak run com.github.cristiano.RedragonVolumeSync
```

### Instalação Manual

<details>
<summary>Clique para expandir instruções de instalação manual</summary>

#### 1. Copiar scripts

```bash
mkdir -p ~/.local/bin
cp redragon_volume_sync.py ~/.local/bin/
cp redragon_daemon.py ~/.local/bin/
cp redragon_event_monitor.py ~/.local/bin/
cp redragon-volume ~/.local/bin/
chmod +x ~/.local/bin/redragon*.py ~/.local/bin/redragon-volume
ln -s ~/.local/bin/redragon_volume_sync.py ~/.local/bin/redragon-sync
```

#### 2. Instalar serviço systemd

```bash
mkdir -p ~/.config/systemd/user
cp redragon-volume-sync.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable redragon-volume-sync.service
systemctl --user start redragon-volume-sync.service
```

#### 3. Instalar extensão GNOME (opcional)

```bash
mkdir -p ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano
cp -r gnome-extension/* ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano/
glib-compile-schemas ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano/schemas/
```

Depois habilite em: **Extensões → Redragon Volume Sync**

#### 4. Instalar applet Cinnamon (opcional)

```bash
mkdir -p ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano
cp cinnamon-applet/* ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano/
```

Depois adicione em: **Configurações → Applets → Redragon Volume Sync**

</details>

## 📖 Uso

### Script CLI

```bash
# Ver status do headset
redragon-sync status

# Sincronizar volumes automaticamente (usa o maior valor atual)
redragon-sync sync

# Definir volume específico (0-100)
redragon-sync set 75
```

### Controle de Volume (Saída Analógica)

**⚠️ Importante:** Na saída analógica, use o script `redragon-volume` ao invés dos controles do sistema:

```bash
# Definir volume
redragon-volume 75          # 75%
redragon-volume 50          # 50%

# Ajustar volume
redragon-volume up          # +5%
redragon-volume down        # -5%
redragon-volume +10         # +10%
redragon-volume -5          # -5%

# Mutar/desmutar
redragon-volume mute

# Ver status
redragon-volume status
```

**Por quê?** Na saída analógica, o PipeWire controla o volume em software. Os headsets Redragon precisam dos controles ALSA ajustados. Veja [ANALOG_OUTPUT.md](ANALOG_OUTPUT.md) para detalhes e como configurar atalhos de teclado.

### Daemon Systemd

O daemon suporta dois modos de operação:

#### 🎯 Modo de Eventos (Recomendado)
Reage instantaneamente a mudanças usando `alsactl monitor` e `udevadm monitor`:
- **Zero latência** - Sincroniza imediatamente quando o volume muda
- **Zero CPU idle** - Não consome recursos quando não há eventos
- **Detecção instantânea** - Identifica conexão/desconexão do headset em tempo real

#### ⏱️ Modo Polling (Fallback)
Verifica volumes periodicamente (intervalo de 2 segundos):
- **Compatibilidade** - Funciona em qualquer sistema
- **Uso leve de CPU** - Verificação rápida a cada 2s
- **Confiável** - Sempre funciona, mesmo sem suporte a eventos

O daemon detecta automaticamente qual modo usar. Para forçar um modo específico:

```bash
# Executar manualmente em modo automático (detecta o melhor)
~/.local/bin/redragon_daemon.py

# Forçar modo de eventos
~/.local/bin/redragon_daemon.py --mode event

# Forçar modo polling
~/.local/bin/redragon_daemon.py --mode poll
```

#### Comandos do serviço systemd

```bash
# Ver status do serviço
systemctl --user status redragon-volume-sync

# Iniciar serviço
systemctl --user start redragon-volume-sync

# Parar serviço
systemctl --user stop redragon-volume-sync

# Habilitar na inicialização
systemctl --user enable redragon-volume-sync

# Desabilitar na inicialização
systemctl --user disable redragon-volume-sync

# Ver logs (para ver qual modo está ativo)
journalctl --user -u redragon-volume-sync -f
```

### Extensão GNOME / Applet Cinnamon

Após instalar:
1. Adicione o indicador ao painel
2. Clique no ícone de headphone para abrir o menu
3. Use o menu para:
   - Ver status da conexão
   - Sincronizar volumes manualmente
   - Ajustar volume (GNOME)
   - Redetectar headset

## 🔧 Funcionamento Técnico

### O Problema

Os headsets Redragon sem fio expõem dois controles PCM separados no ALSA:
- **PCM Playback Volume** (numid=9): 2 canais (esquerdo/direito)
- **PCM Playback Volume[1]** (numid=10): 1 canal adicional

O problema é que o numid=10 frequentemente fica dessincronizado, causando perda de áudio em um dos lados.

### A Solução

Com PipeWire/PulseAudio (padrão em sistemas modernos):
- O PipeWire controla o volume em **software** (nível superior)
- Os controles ALSA devem permanecer em **100%** para volume máximo de hardware
- Este daemon garante que **ambos os controles ALSA fiquem fixos em 100%**
- Você controla o volume normalmente pelo sistema (PipeWire cuida disso)

Sem PipeWire/PulseAudio (ALSA puro):
- O daemon sincroniza ambos os controles ALSA para o mesmo valor
- Você controla o volume via alsamixer ou este script

### Monitoramento por Eventos

O daemon usa um sistema inteligente de monitoramento:

1. **ALSA Events** (`alsactl monitor`):
   - Monitora mudanças nos controles de volume em tempo real
   - Reage instantaneamente quando você ajusta o volume
   - Sem polling, sem latência

2. **udev Events** (`udevadm monitor`):
   - Detecta quando o headset é conectado/desconectado
   - Re-sincroniza automaticamente após reconexão
   - Sem necessidade de reiniciar o daemon

3. **Fallback Automático**:
   - Se `alsactl` ou `udevadm` não estiverem disponíveis
   - Volta automaticamente para modo polling
   - Garante funcionamento em qualquer sistema

## 📁 Estrutura do Projeto

```
h878-fixer/
├── redragon_volume_sync.py              # Script CLI principal
├── redragon_daemon.py                   # Daemon híbrido (eventos + polling)
├── redragon_event_monitor.py            # Monitor de eventos ALSA/udev
├── redragon-volume                      # Script de controle de volume
├── redragon-volume-sync.service         # Template do serviço systemd
├── configure-pipewire.sh                # Configurador automático PipeWire (opcional)
├── pipewire-redragon-template.conf      # Template de configuração PipeWire
├── install.sh                           # Script de instalação
├── uninstall.sh                         # Script de desinstalação
├── ANALOG_OUTPUT.md                     # Guia para saída analógica
├── gnome-extension/                     # Extensão GNOME Shell
│   ├── extension.js
│   ├── metadata.json
│   └── schemas/
│       └── org.gnome.shell.extensions.redragon-volume-sync.gschema.xml
├── cinnamon-applet/                     # Applet Cinnamon
│   ├── applet.js
│   └── metadata.json
├── LICENSE                              # Licença MIT
└── README.md                            # Este arquivo
```

## 🐛 Solução de Problemas

### Headset não detectado

```bash
# Verificar se o headset está listado (procure por H878, H848, H510, etc.)
aplay -l | grep -E 'H[0-9]{3}|Redragon|XiiSound|Weltrend'

# Verificar controles do mixer
amixer -c 4 contents
```

### Serviço não inicia

```bash
# Ver logs detalhados
journalctl --user -u redragon-volume-sync --no-pager

# Verificar status
systemctl --user status redragon-volume-sync
```

### Extensão GNOME não aparece

```bash
# Verificar logs do GNOME Shell
journalctl -f /usr/bin/gnome-shell

# Recarregar GNOME Shell (Alt+F2, digite 'r', Enter)
```

### Volumes dessincronizam frequentemente

Se o daemon systemd não está funcionando adequadamente:

1. **Verifique qual modo está ativo**:
   ```bash
   journalctl --user -u redragon-volume-sync -n 20
   # Procure por "Usando modo de EVENTOS" ou "Usando modo de POLLING"
   ```

2. **Se estiver usando polling**, considere forçar modo de eventos:
   ```bash
   # Edite o serviço systemd
   systemctl --user edit redragon-volume-sync --full
   # Adicione --mode event ao ExecStart:
   # ExecStart=/home/SEU_USUARIO/.local/bin/redragon_daemon.py --mode event
   ```

3. **Se eventos não funcionarem**, verifique se os comandos estão disponíveis:
   ```bash
   which alsactl
   which udevadm
   ```

4. **Teste manualmente** para diagnosticar:
   ```bash
   # Pare o serviço
   systemctl --user stop redragon-volume-sync

   # Execute manualmente com debug
   ~/.local/bin/redragon_daemon.py --mode event
   ```

5. Verifique se há conflitos com outras ferramentas de áudio
6. Considere usar o applet/extensão para controle manual adicional

## 🗑️ Desinstalação

```bash
./uninstall.sh
```

Ou manualmente:
```bash
systemctl --user stop redragon-volume-sync
systemctl --user disable redragon-volume-sync
rm -f ~/.local/bin/redragon_volume_sync.py
rm -f ~/.local/bin/redragon_daemon.py
rm -f ~/.local/bin/redragon_event_monitor.py
rm -f ~/.local/bin/redragon-sync
rm -f ~/.local/bin/redragon-volume
rm -f ~/.config/systemd/user/redragon-volume-sync.service
rm -rf ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano
rm -rf ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano
rm -rf ~/.local/share/h878-fixer
systemctl --user daemon-reload
```

## 📝 Logs

Os logs são salvos em:
- **Daemon**: `~/.local/share/h878-fixer/daemon.log`
- **Systemd**: `journalctl --user -u redragon-volume-sync`

## 🏗️ Distribuição e CI/CD

Este projeto usa GitHub Actions para automatizar builds e releases:

### Workflows Disponíveis

1. **Flatpak** (`.github/workflows/flatpak.yml`)
   - Build automático em cada push
   - Publicação em releases
   - ⚠️ Veja [DISTRIBUTION.md](DISTRIBUTION.md) sobre limitações

2. **Pacote Debian** (`.github/workflows/debian-package.yml`)
   - Cria pacote .deb para Ubuntu/Debian
   - Publicação automática em releases
   - ⭐ Método recomendado para Ubuntu/Mint

3. **Extensões Desktop** (`.github/workflows/desktop-extensions.yml`)
   - Empacota extensão GNOME
   - Empacota applet Cinnamon
   - Preparado para publicação nas lojas oficiais

### Publicar Releases

Para criar um novo release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Os workflows irão automaticamente:
- ✅ Build do Flatpak
- ✅ Build do pacote .deb
- ✅ Empacotar extensões desktop
- ✅ Criar GitHub Release com todos os arquivos
- ✅ Gerar release notes automaticamente

### Formatos de Distribuição

Veja [DISTRIBUTION.md](DISTRIBUTION.md) para:
- Comparação detalhada de formatos
- Por que Flatpak não é ideal para este projeto
- Como criar pacotes .rpm, AUR, etc.
- Como publicar nas lojas GNOME Extensions e Cinnamon Spices

## 🤝 Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para:
- Reportar bugs
- Sugerir novas funcionalidades
- Enviar pull requests
- Melhorar a documentação
- Ajudar com empacotamento para outras distros

## 📄 Licença

Este projeto é de código aberto e está disponível sob a licença MIT.

## 🙏 Agradecimentos

Criado para resolver um problema comum com headsets Redragon sem fio no Linux.

## 📞 Suporte

Se encontrar problemas:
1. Verifique a seção de [Solução de Problemas](#-solução-de-problemas)
2. Consulte os logs
3. Abra uma issue no repositório

---

**Status**: ✅ Testado no Ubuntu/Debian com Cinnamon Desktop

**Versão**: 1.0.0
