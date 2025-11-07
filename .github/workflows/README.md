# GitHub Actions Workflows

Este diretório contém os workflows de CI/CD para automatizar builds e releases do Redragon Volume Sync.

## Workflows Disponíveis

### 1. `flatpak.yml` - Build Flatpak

**Quando executa:**
- Push para `main`
- Tags `v*`
- Pull requests
- Manualmente via workflow_dispatch

**O que faz:**
- ✅ Build do bundle Flatpak
- ✅ Upload como artifact (30 dias)
- ✅ Testa instalação
- ✅ Publica em GitHub Releases (em tags)

**Uso:**
```bash
# Baixar do release
wget https://github.com/cristiano/h878-fixer/releases/latest/download/redragon-volume-sync.flatpak

# Instalar
flatpak install --user redragon-volume-sync.flatpak
```

**Limitações:**
⚠️ O Flatpak tem limitações significativas para este projeto. Veja [DISTRIBUTION.md](../../DISTRIBUTION.md) para detalhes.

---

### 2. `debian-package.yml` - Build Pacote .deb

**Quando executa:**
- Push para `main`
- Tags `v*`
- Pull requests
- Manualmente via workflow_dispatch

**O que faz:**
- ✅ Cria estrutura de pacote Debian
- ✅ Gera arquivo .deb
- ✅ Upload como artifact (30 dias)
- ✅ Publica em GitHub Releases (em tags)

**Uso:**
```bash
# Baixar do release
wget https://github.com/cristiano/h878-fixer/releases/latest/download/redragon-volume-sync_VERSION_all.deb

# Instalar
sudo dpkg -i redragon-volume-sync_VERSION_all.deb
sudo apt-get install -f  # resolver dependências

# Ativar
systemctl --user enable --now redragon-volume-sync.service
```

**Vantagens:**
- ✅ Instalação nativa no Ubuntu/Debian/Mint
- ✅ Integração perfeita com systemd
- ✅ Gerenciamento de dependências automático
- ✅ Atualização via apt

---

### 3. `desktop-extensions.yml` - Empacotar Extensões Desktop

**Quando executa:**
- Push para `main`
- Tags `v*`
- Pull requests
- Manualmente via workflow_dispatch

**O que faz:**
- ✅ Compila schemas GNOME
- ✅ Cria pacote .zip da extensão GNOME
- ✅ Cria pacote .zip do applet Cinnamon
- ✅ Upload como artifacts (30 dias)
- ✅ Publica em GitHub Releases (em tags)

**Extensão GNOME:**
```bash
# Instalar manualmente
mkdir -p ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano
unzip redragon-volume-sync-gnome-extension.zip -d ~/.local/share/gnome-shell/extensions/redragon-volume-sync@cristiano/

# Habilitar
gnome-extensions enable redragon-volume-sync@cristiano
```

**Applet Cinnamon:**
```bash
# Instalar manualmente
mkdir -p ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano
unzip redragon-volume-sync-cinnamon-applet.zip -d ~/.local/share/cinnamon/applets/redragon-volume-sync@cristiano/
```

**Publicação nas Lojas:**
- 📦 GNOME: https://extensions.gnome.org/upload/
- 📦 Cinnamon: https://github.com/linuxmint/cinnamon-spices-applets

---

## Como Criar um Release

### 1. Criar e Push da Tag

```bash
# Atualizar versão nos arquivos (metadata.json, etc.)
git add .
git commit -m "Bump version to 1.0.0"

# Criar tag
git tag v1.0.0

# Push
git push origin main
git push origin v1.0.0
```

### 2. Workflows Executam Automaticamente

Os três workflows irão executar automaticamente e:
1. Build de todos os formatos
2. Upload como artifacts
3. Criar GitHub Release com:
   - `redragon-volume-sync.flatpak`
   - `redragon-volume-sync_VERSION_all.deb`
   - `redragon-volume-sync-gnome-extension.zip`
   - `redragon-volume-sync-cinnamon-applet.zip`
   - Release notes automáticas

### 3. Verificar Release

Acesse: https://github.com/cristiano/h878-fixer/releases

---

## Executar Workflows Manualmente

Via GitHub UI:
1. Acesse: **Actions** → Escolha o workflow
2. Clique em **Run workflow**
3. Selecione branch
4. Clique em **Run workflow**

Via GitHub CLI:
```bash
# Flatpak
gh workflow run flatpak.yml

# Pacote Debian
gh workflow run debian-package.yml

# Extensões Desktop
gh workflow run desktop-extensions.yml
```

---

## Troubleshooting

### Workflow falhou?

**Verificar logs:**
1. Acesse: **Actions** → Workflow falhado
2. Clique no job que falhou
3. Expanda os steps para ver erros

**Problemas comuns:**

**1. Flatpak build falhou**
- Verificar se o manifest está válido
- Conferir permissões no `finish-args`

**2. .deb build falhou**
- Verificar se o `control` está correto
- Conferir dependências

**3. Extensões falharam**
- Verificar se schemas compilam
- Conferir estrutura dos arquivos

### Re-executar Workflow

1. Acesse o workflow falhado
2. Clique em **Re-run jobs**
3. Selecione quais jobs re-executar

---

## Secrets Necessários

Atualmente não são necessários secrets customizados. Os workflows usam apenas:
- `GITHUB_TOKEN` (automático)

---

## Adicionar Novo Workflow

1. Criar arquivo `.github/workflows/nome.yml`
2. Definir triggers (on:)
3. Definir jobs e steps
4. Fazer commit e push
5. Workflow aparecerá em **Actions**

**Exemplo mínimo:**
```yaml
name: Meu Workflow
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Hello World"
```

---

## Badges para README

Adicione badges ao README.md principal:

```markdown
[![Build Flatpak](https://github.com/cristiano/h878-fixer/actions/workflows/flatpak.yml/badge.svg)](https://github.com/cristiano/h878-fixer/actions/workflows/flatpak.yml)
[![Build Debian](https://github.com/cristiano/h878-fixer/actions/workflows/debian-package.yml/badge.svg)](https://github.com/cristiano/h878-fixer/actions/workflows/debian-package.yml)
[![Package Extensions](https://github.com/cristiano/h878-fixer/actions/workflows/desktop-extensions.yml/badge.svg)](https://github.com/cristiano/h878-fixer/actions/workflows/desktop-extensions.yml)
```

---

## Recursos

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flatpak Builder Action](https://github.com/flatpak/flatpak-github-actions)
- [action-gh-release](https://github.com/softprops/action-gh-release)
- [Debian Packaging Guide](https://www.debian.org/doc/manuals/maint-guide/)
