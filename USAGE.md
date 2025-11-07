# Como Controlar o Volume do H878

## ⚠️  IMPORTANTE: Como Controlar o Volume

### ✅ Jeito CORRETO (Recomendado)

Use os controles normais do sistema:

1. **Controle de volume do sistema** (barra de tarefas)
2. **Teclas de atalho** do teclado (Volume +/-)
3. **Comando pactl**:
   ```bash
   pactl set-sink-volume @DEFAULT_SINK@ 70%
   pactl set-sink-volume @DEFAULT_SINK@ +5%
   pactl set-sink-volume @DEFAULT_SINK@ -5%
   ```

### ❌ Jeito INCORRETO (Não use!)

**NÃO** use controles ALSA diretamente:
- ❌ `alsamixer` - não use
- ❌ `amixer -c 4 set PCM 50%` - não use
- ❌ Aplicativos que controlam ALSA diretamente

## 🔧 Por que?

### Como o sistema funciona:

```
Você ajusta o volume
       ↓
  PipeWire (controle em software)
       ↓
  Daemon H878 (garante ALSA em 100%)
       ↓
  ALSA PCM[0]=100%, PCM[1]=100%
       ↓
  Headset H878 (áudio funciona em ambos os lados!)
```

### O que o daemon faz:

1. **Monitora** os controles ALSA (numid=9 e numid=10)
2. **Garante** que ambos fiquem sempre em **100%**
3. **Corrige** automaticamente se algo tentar mudar

### Por que os controles ALSA ficam em 100%?

- O PipeWire controla o volume em **software** (nível superior)
- Os controles ALSA são o volume de **hardware**
- Para hardware máximo, ALSA deve ficar em 100%
- Você controla o volume pelo PipeWire, não pelo ALSA!

## 🧪 Testando

### Teste 1: Volume via sistema (Correto ✅)

```bash
# Ajuste o volume usando o controle do sistema ou:
pactl set-sink-volume @DEFAULT_SINK@ 50%

# Verifique que ALSA permanece em 100%:
./h878_volume_sync.py status

# Deve mostrar:
# PCM Volume (2 canais): 100%
# PCM Volume [1] (1 canal): 100%
# Status: ✓ Sincronizado
```

**Resultado esperado:** Áudio funcionando, volume em 50%, ambos os lados tocando!

### Teste 2: Volume via ALSA (Incorreto ❌)

```bash
# Se você tentar mudar via ALSA:
amixer -c 4 set PCM 50%

# O daemon vai detectar e corrigir em ~0.5s:
# "Controles ALSA fora do esperado, corrigindo para 100%"

# Os controles voltam para 100%
```

**Resultado:** O daemon restaura para 100% (comportamento correto!)

## 🎛️ Controle Fino de Volume

Se você precisa de controle mais preciso:

```bash
# Volume por porcentagem
pactl set-sink-volume @DEFAULT_SINK@ 75%

# Aumentar/diminuir em steps
pactl set-sink-volume @DEFAULT_SINK@ +2%
pactl set-sink-volume @DEFAULT_SINK@ -2%

# Mutar/desmutar
pactl set-sink-mute @DEFAULT_SINK@ toggle
```

## 🐛 Troubleshooting

### "O volume volta para 100% quando eu diminuo"

**Causa:** Você está usando alsamixer ou controlando ALSA diretamente

**Solução:** Use os controles do sistema ou `pactl` conforme indicado acima

### "O áudio funciona só de um lado com volume baixo"

**Causa:** O daemon não está rodando

**Solução:**
```bash
# Verifique se está rodando
systemctl --user status h878-volume-sync

# Se não estiver, inicie:
systemctl --user start h878-volume-sync

# Habilite para iniciar automaticamente:
systemctl --user enable h878-volume-sync
```

### "Quero controlar via ALSA mesmo assim"

Se você realmente precisa controlar via ALSA (ex: não usa PipeWire/PulseAudio):

```bash
# Pare o daemon
systemctl --user stop h878-volume-sync

# Use o script manual quando precisar sincronizar
./h878_volume_sync.py sync
```

**Nota:** Sem o daemon, você precisará sincronizar manualmente sempre que o volume dessincronizar.

## 📊 Verificando Status

```bash
# Status dos controles ALSA
./h878_volume_sync.py status

# Status do daemon
systemctl --user status h878-volume-sync

# Logs do daemon
journalctl --user -u h878-volume-sync -f

# Volume do PipeWire
pactl list sinks | grep -A 10 "H878"
```

## 💡 Resumo

- ✅ **USE:** Controles do sistema / pactl
- ✅ **ESPERE:** ALSA sempre em 100%
- ✅ **DEIXE:** O daemon fazer seu trabalho
- ❌ **NÃO USE:** alsamixer / amixer para volume

O daemon garante que o hardware esteja configurado corretamente (100%) enquanto você controla o volume normalmente pelo sistema! 🎧
