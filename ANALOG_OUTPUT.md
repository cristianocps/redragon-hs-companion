# Guia: Saída Analógica de Headsets Redragon

## 🔊 Problema na Saída Analógica

Na saída analógica, o PipeWire controla o volume em **software** (não ajusta os controles ALSA). Porém, os headsets Redragon **precisam** que os controles ALSA sejam ajustados para o áudio funcionar corretamente.

**Sintoma:**
- Volume só funciona em 100% quando usa controles do sistema
- Com alsamixer funciona normalmente

**Causa Raiz:**
- PipeWire mapeia volumes < 100% como 0 nos controles ALSA (controle de software)
- PipeWire monitora ativamente os controles ALSA e reverte mudanças manuais
- Headset precisa PCM[0] == PCM[1] para áudio sair nos dois canais

## ✅ Soluções Implementadas

### ✅ Solução 1: Applet/Extensão Gráfica (MAIS FÁCIL)

Os applets do Cinnamon e extensão do GNOME foram atualizados com **controles de volume integrados**:

**Cinnamon:**
- Botões +5% e -5% no menu do applet
- Mostra volume atual em tempo real
- Sincronização automática PCM[0] ↔ PCM[1]

**GNOME:**
- Slider de volume no menu da extensão
- Botão de sincronização manual
- Indicador de status no painel

**Como Usar:**
1. Clique no ícone do headset no painel
2. Use os controles de volume diretamente no menu
3. O daemon sincroniza automaticamente PCM[0] → PCM[1]

### Solução 2: Script de Linha de Comando

Use o script `redragon-volume` para controlar via terminal:

```bash
# Controles básicos
redragon-volume 75          # Define para 75%
redragon-volume up          # Aumenta 5%
redragon-volume down        # Diminui 5%
redragon-volume +10         # Aumenta 10%
redragon-volume -5          # Diminui 5%
redragon-volume mute        # Muta/desmuta
redragon-volume status      # Mostra status
```

### Solução 3: Configurar Atalhos de Teclado (Opcional)

Configure atalhos de teclado para chamar o script:

#### No Cinnamon:
1. **Configurações** → **Teclado** → **Atalhos**
2. Adicione novos atalhos:

| Tecla | Comando | Ação |
|-------|---------|------|
| `XF86AudioRaiseVolume` | `redragon-volume up` | Aumentar volume |
| `XF86AudioLowerVolume` | `redragon-volume down` | Diminuir volume |
| `XF86AudioMute` | `redragon-volume mute` | Mutar |

**Nota:** Pode ser necessário desabilitar os atalhos padrão primeiro.

#### No GNOME:
1. **Configurações** → **Teclado** → **Atalhos de Teclado**
2. Role até "Som e Mídia"
3. Redefina os atalhos para usar `redragon-volume`

### Solução 4: Usar alsamixer Diretamente (Avançado)

Se preferir usar alsamixer manualmente:

```bash
# Abrir alsamixer
alsamixer -c <número-da-placa>

# Use F6 para selecionar a placa correta (Redragon)
# Use setas para ajustar PCM
# O daemon irá sincronizar automaticamente PCM[0] → PCM[1]
```

## 🔧 Como Funciona Internamente

```
┌─────────────────────────────────────────────────────┐
│  Você usa Applet/redragon-volume                    │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│  1. PipeWire é colocado em 100%                     │
│     (desativa controle de software)                 │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│  2. redragon-volume ajusta PCM[0] via ALSA          │
│     Exemplo: PCM[0] = 70                            │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│  3. Daemon detecta mudança em PCM[0]                │
│     (via eventos ALSA ou polling)                   │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│  4. Daemon copia PCM[0] → PCM[1]                    │
│     PCM[0] = 70, PCM[1] = 70 ✅                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│  ✓ Áudio sai nos dois canais em 70%!               │
└─────────────────────────────────────────────────────┘
```

## 🧪 Testando

```bash
# Teste 1: Aumentar volume
redragon-volume 50
# Verifique se o áudio está nos dois lados

# Teste 2: Diminuir volume
redragon-volume 30
# Verifique se o áudio está nos dois lados

# Teste 3: Status
redragon-volume status
# Deve mostrar PCM[0] e PCM[1] com o mesmo valor
```

## 📱 Applet/Extensão

Os applets (Cinnamon) e extensão (GNOME) que criamos também podem ser configurados para usar o controle via ALSA ao invés de PipeWire. Eles já sincronizam automaticamente.

## 🔧 Como Funciona

```
Você → redragon-volume → ALSA PCM[0]
                              ↓
                        Daemon detecta
                              ↓
                      Copia para PCM[1]
                              ↓
                     Ambos sincronizados! ✅
```

## ❓ FAQ

### Por que não usar os controles do sistema diretamente?

O PipeWire na saída analógica usa controle de volume em software (não ajusta ALSA). Ele mapeia volumes < 100% como PCM[0]=0, e o headset Redragon precisa dos controles ALSA ajustados para funcionar nos dois canais.

### O daemon está funcionando?

Sim! O daemon está sincronizando PCM[0] → PCM[1] perfeitamente em tempo real via eventos ALSA.

### Como usar os controles gráficos?

Use o applet do Cinnamon ou a extensão do GNOME! Ambos foram atualizados com controles de volume integrados que usam `redragon-volume` internamente.

### E na saída digital?

Na saída digital (USB, HDMI, etc), o PipeWire controla corretamente via hardware. Use os controles normais do sistema.

### Posso usar teclas multimídia?

Sim! Configure atalhos de teclado para chamar `redragon-volume up/down` ou use o applet/extensão que já integra os controles.

## 📊 Verificação

```bash
# Daemon rodando?
systemctl --user status redragon-volume-sync

# Sincronização funcionando?
redragon-volume 60
sleep 1
redragon-volume status
# Ambos devem estar em 60%

# Áudio funcionando nos dois lados?
# Teste com música/vídeo
```

## 💡 Dica Final

Configure os atalhos de teclado uma única vez e esqueça o problema! As teclas multimídia do seu teclado irão controlar o volume perfeitamente. 🎧
