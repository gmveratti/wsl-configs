# Fedora Dev Setup 🐧

Instalador para preparar um **Fedora Workstation tradicional (DNF5)** para desenvolvimento, com Docker, Homebrew, Codex CLI, JetBrains Mono Nerd Font, LazyVim e aplicativos Flatpak.

## Instalação

```bash
git clone https://github.com/gmveratti/wsl-configs.git
cd wsl-configs
bash -n install.sh
chmod +x install.sh
./install.sh
```

Execute como usuário comum com permissão de `sudo` (não execute como `root`). Ao terminar, faça **logout e login** para atualizar a associação ao grupo Docker. Reinicie o computador para usar o novo kernel.

## O que o script configura

1. **Limpeza inicial:** remove aplicativos GNOME e LibreOffice listados no script.
2. **Atualização e repositórios:** atualiza o Fedora e configura RPM Fusion.
3. **Ferramentas de desenvolvimento:** compiladores, Git, Git LFS, utilitários e dependências do LazyVim.\n4. **Fonte para programação:** baixa a JetBrains Mono Nerd Font Mono, atualiza o cache e configura a fonte monoespaçada do GNOME e do Ptyxis (quando disponíveis).
4. **Kernel e otimizações opcionais do ambiente:** CachyOS via COPR, sched-ext (SCX) e UKSMD.
5. **Terminal:** Oh My Bash.
6. **Containers:** Docker Engine, Compose e Buildx.
7. **Homebrew:** Go, OpenJDK, Neovim, Node.js, Python, LazyGit, LazyDocker e **Codex CLI**.
8. **Flatpak:** Flathub e 11 aplicativos, incluindo VS Code, Postman, DBeaver, Flatseal, Extension Manager e Papers.
9. **Editor:** Git e LazyVim, com plugins de `gmveratti/nvim-configs`.

## Cuidados importantes

- **Revise o script antes de executar.** Ele remove pacotes instalados, atualiza o sistema, adiciona repositórios externos e instala outro kernel.
- O kernel CachyOS vem de um **COPR de terceiros**. Confira compatibilidade com hardware e **Secure Boot** antes de reiniciar. O kernel padrão do Fedora continua instalado.
- Associar um usuário ao grupo `docker` concede privilégios equivalentes a root.
- Configurações anteriores do Neovim são preservadas por meio de backups quando necessário.\n- A fonte é instalada somente para o usuário atual em `~/.local/share/fonts/JetBrainsMonoNerdFont`. Não altera a fonte da interface GNOME, apenas a monoespaçada; outras aplicações podem exigir seleção manual.
- Este instalador **não foi projetado para Fedora Atomic/Bazzite, WSL nem outras distribuições**.
- A sintaxe Bash foi validada com `bash -n`. A instalação completa não foi executada neste ambiente.

## Verificações

```bash
docker compose version
brew --version
codex --version
nvim --version
systemctl status scx_loader.service\nfc-match 'JetBrainsMono Nerd Font Mono'\ngsettings get org.gnome.desktop.interface monospace-font-name
```
