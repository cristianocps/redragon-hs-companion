# Guia de Atualização - v2.0

## 🎉 Novidades da v2.0

### 1. ✨ Detecção Genérica
Agora suporta **qualquer headset Redragon sem fio** via dongle USB:
- Redragon H878 ✅
- Redragon H848 ✅
- Redragon H510 ✅
- Outros modelos similares ✅

### 2. 🎯 Volume Correto no Applet
O applet do Cinnamon agora mostra o volume ALSA correto!

### 3. 📝 Script de Controle Melhorado
Comando `h878-volume` funciona perfeitamente para controle via ALSA.

## 🔄 Como Atualizar

### Opção 1: Atualização Automática (Recomendado)

```bash
cd ~/repos/h878-fixer
git pull  # Se estiver usando git
# ou baixe a versão mais recente

./install.sh
```

### Opção 2: Atualização Manual

#### 1. Atualizar Scripts

```bash
cd ~/repos/h878-fixer

# Para o daemon
systemctl --user stop h878-volume-sync

# Copia os novos scripts
cp h878_volume_sync.py ~/.local/bin/
cp h878_daemon.py ~/.local/bin/
cp h878_event_monitor.py ~/.local/bin/
cp h878-volume ~/.local/bin/

# Reinicia o daemon
systemctl --user start h878-volume-sync
```

#### 2. Atualizar Applet do Cinnamon

```bash
# Remove o applet antigo
rm -rf ~/.local/share/cinnamon/applets/h878-volume-sync@cristiano

# Copia o novo
mkdir -p ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano
cp cinnamon-applet/* ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano/

# Reinicia o Cinnamon
# Pressione Alt+F2, digite 'r', pressione Enter
```

**⚠️ Importante:** O UUID do applet mudou de `h878-volume-sync@cristiano` para `redragon-volume-sync@cristiano`.

Você precisará:
1. Remover o applet antigo do painel
2. Adicionar o novo applet (agora chamado "Redragon Volume Sync")

#### 3. Atualizar Extensão GNOME (se usar)

```bash
# Remove a antiga
rm -rf ~/.local/share/gnome-shell/extensions/h878-volume-sync@cristiano

# Copia a nova
mkdir -p ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano
cp -r gnome-extension/* ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano/

# Compila schemas
glib-compile-schemas ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano/schemas/

# Reinicia o GNOME Shell (Alt+F2, 'r', Enter)
```

## 🧪 Testando a Atualização

### 1. Teste o script CLI

```bash
# Deve detectar seu headset automaticamente
h878-sync status

# Deve mostrar algo como:
# ✓ H878 Wireless headset detectado na placa 4
```

### 2. Teste o controle de volume

```bash
# Teste ajustar o volume
h878-volume 60

# Verifique
h878-volume status

# Deve mostrar 60% nos dois canais
```

### 3. Teste o daemon

```bash
# Verifique o daemon
systemctl --user status h878-volume-sync

# Deve mostrar "active (running)"

# Teste mudar o volume manualmente
h878-volume 50

# Verifique os logs
journalctl --user -u h878-volume-sync -n 5

# Deve mostrar: "Sincronizando PCM[1] para 50%"
```

### 4. Teste o applet (Cinnamon)

1. Adicione o applet "Redragon Volume Sync" ao painel
2. Clique nele - deve mostrar seu headset conectado
3. O volume exibido deve corresponder ao volume ALSA real

## 🔧 Compatibilidade

### Headsets Testados
- ✅ Redragon H878 (via dongle USB)

### Headsets Compatíveis (não testados)
- 🟡 Redragon H848
- 🟡 Redragon H510
- 🟡 Outros modelos sem fio via dongle

Se você tiver outro modelo Redragon sem fio, teste e reporte!

### Detectar Automaticamente

O script agora busca por:
- Padrões: H878, H848, H510, etc
- Palavras-chave: "Wireless headset", "XiiSound", "Weltrend", "Redragon"

Se seu headset não for detectado, você pode forçar:

```bash
# Especifique o modelo
h878-sync -d H848 status

# Ou use parte do nome
h878-sync -d "Wireless" status
```

## 📝 Mudanças de Nome

| Antigo | Novo |
|--------|------|
| H878 Volume Sync | Redragon Volume Sync |
| `h878-volume-sync@cristiano` | `redragon-volume-sync@cristiano` |
| "Detecta H878" | "Detecta headsets Redragon" |
| Classe `H878VolumeSync` | Classe `RedragonVolumeSync` |

**Nota:** A classe antiga ainda existe como alias para compatibilidade.

## ❓ Problemas?

### Applet não aparece
1. Certifique-se de remover o antigo primeiro
2. Copie o novo
3. Reinicie o Cinnamon (Alt+F2, 'r', Enter)
4. Procure por "Redragon" nos applets

### Volume não atualiza no applet
1. Verifique se o script está instalado: `which h878-sync`
2. Teste manualmente: `h878-sync status`
3. Verifique os logs do Cinnamon: `journalctl -f /usr/bin/cinnamon`

### Daemon não detecta mudanças
1. Reinicie o daemon: `systemctl --user restart h878-volume-sync`
2. Verifique os logs: `journalctl --user -u h878-volume-sync -f`
3. Teste o monitoramento: `h878-volume 50` e veja se o daemon responde

## 🎊 Pronto!

Sua instalação está atualizada para v2.0 com:
- ✅ Detecção genérica de headsets Redragon
- ✅ Volume correto no applet
- ✅ Melhor compatibilidade
- ✅ Mais estável e robusto

Aproveite! 🎧
