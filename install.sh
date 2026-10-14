#!/usr/bin/env bash
# Fedora Workstation (DNF5) - ambiente de desenvolvimento
# Execute como usuário comum: bash install.sh
set -Eeuo pipefail

trap 'printf "\n❌ Falha na linha %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
log() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
backup_dir() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local dest="${target}.bak.$(date +%Y%m%d-%H%M%S)"
    mv -- "$target" "$dest"
    printf '📁 Backup: %s\n' "$dest"
  fi
}

if [[ $EUID -eq 0 ]]; then
  echo 'Execute como usuário comum, não como root.' >&2
  exit 1
fi
if [[ ! -r /etc/fedora-release ]]; then
  echo 'Este script é exclusivo do Fedora tradicional (Workstation/Server com DNF).' >&2
  exit 1
fi
if ! command_exists dnf; then
  echo 'DNF não encontrado. Fedora Atomic/Bazzite não é suportado.' >&2
  exit 1
fi

log '🔐 Validando permissões sudo...'
sudo -v

log '🧹 Removendo aplicativos pré-instalados indesejados...'
# Primeira alteração no sistema, antes de atualizar ou instalar pacotes.
# Remove somente o que estiver instalado para evitar falhas em instalações mínimas.
remove_candidates=(
  gnome-tour yelp gnome-abrt gnome-maps gnome-connections
  gnome-contacts evince libreoffice-writer libreoffice-calc
  libreoffice-impress gnome-system-monitor simple-scan
)
remove_installed=()
for pkg in "${remove_candidates[@]}"; do
  if rpm -q --quiet "$pkg"; then
    remove_installed+=("$pkg")
  fi
done
if (( ${#remove_installed[@]} > 0 )); then
  sudo dnf remove -y "${remove_installed[@]}"
else
  echo 'Nenhum dos aplicativos listados está instalado.'
fi

log '🔄 Atualizando o Fedora...'
sudo dnf upgrade --refresh -y

log '📦 Configurando RPM Fusion...'
fedora_ver="$(rpm -E %fedora)"
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
  sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm"
fi
if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
  sudo dnf install -y "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
fi
# Repositórios tainted são opcionais, habilite manualmente se precisar:
# sudo dnf install -y rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted

log '🛠️ Ferramentas essenciais e compiladores...'
sudo dnf group install -y development-tools
sudo dnf install -y \
  bash curl wget git git-lfs file procps-ng ncurses \
  ca-certificates gnupg2 tar unzip zip xz \
  gcc gcc-c++ make cmake pkgconf-pkg-config \
  openssl-devel zlib-devel readline-devel libffi-devel \
  ripgrep fd-find fzf tree-sitter-cli \
  python3-pip pipx jq ShellCheck dnf5-plugins flatpak distrobox

log '🚀 Kernel CachyOS e otimizações SCX/UKSMD...'
# Repositórios COPR de terceiros. O kernel padrão do Fedora permanece instalado
# como opção de recuperação no menu de inicialização.
warn 'Kernel CachyOS via COPR: confira compatibilidade e Secure Boot antes de reiniciar.'
sudo dnf copr enable -y bieszczaders/kernel-cachyos
sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons
sudo dnf install -y kernel-cachyos kernel-cachyos-devel-matched
# scx-tools inclui o scx_loader, separado do scx-scheds nas versões recentes.
sudo dnf install -y scx-scheds scx-tools uksmd

# A unidade pode não iniciar até que o novo kernel seja carregado no reboot.
if systemctl list-unit-files --no-legend scx_loader.service 2>/dev/null | grep -q '^scx_loader\.service'; then
  sudo systemctl enable scx_loader.service
  if [[ -d /sys/kernel/sched_ext ]]; then
    sudo systemctl start scx_loader.service || warn 'SCX não iniciou; confira após reiniciar com o novo kernel.'
  else
    warn 'O kernel em execução não oferece sched_ext; SCX iniciará após reiniciar com kernel compatível.'
  fi
else
  warn 'Unidade scx_loader.service não encontrada; confira scx-tools.'
fi

if systemctl list-unit-files --no-legend uksmd.service 2>/dev/null | grep -q '^uksmd\.service'; then
  sudo systemctl enable --now uksmd.service || warn 'UKSMD não pôde iniciar agora; confira journalctl -u uksmd.service.'
else
  warn 'Unidade uksmd.service não encontrada; o pacote foi instalado.'
fi
# Em alguns sistemas com SELinux será necessário permitir carga de módulos:
# sudo setsebool -P domain_kernel_load_modules on
# Não alteramos a política SELinux automaticamente por razões de segurança.

log '🎨 Oh My Bash...'
if [[ -d "$HOME/.oh-my-bash" ]]; then
  echo 'Oh My Bash já existe; mantendo configuração.'
else
  # O instalador remoto é oficial; revise-o se estiver em ambiente corporativo.
  curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh \
    -o /tmp/oh-my-bash-install-$$.sh
  bash /tmp/oh-my-bash-install-$$.sh --unattended
  rm -f /tmp/oh-my-bash-install-$$.sh
fi

log '🐳 Docker Engine + Compose + Buildx...'
# Interromper com mensagem clara em caso de pacote potencialmente conflitante.
if rpm -q podman-docker >/dev/null 2>&1; then
  warn 'podman-docker está instalado e conflita com Docker CLI oficial.'
  warn 'Revise antes: sudo dnf remove podman-docker'
  exit 1
fi
sudo dnf install -y dnf-plugins-core
if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
  sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
fi
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$(id -un)"
warn 'O grupo docker concede privilégios equivalentes a root. Use apenas em máquina confiável.'
warn 'Faça logout/login para aplicar o novo grupo docker.'

log '🍺 Homebrew (Linuxbrew)...'
if [[ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  # Instalação não interativa; o sudo acima já foi validado.
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [[ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  echo 'Homebrew não foi encontrado após a instalação.' >&2
  exit 1
fi
BREW_INIT='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
if ! grep -Fqx "$BREW_INIT" "$HOME/.bashrc" 2>/dev/null; then
  printf '\n# Homebrew Linux\n%s\n' "$BREW_INIT" >> "$HOME/.bashrc"
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

log '📦 Linguagens e utilitários via Homebrew...'
# gcc já é instalado pelo DNF. Não duplicar toolchain pesada via Brew.
brew install go openjdk neovim node python lazygit lazydocker

log '🤖 Instalando OpenAI Codex CLI via Homebrew...'
# Cask oficial com binários também para Linux (x86_64/aarch64).
if ! brew list --cask codex >/dev/null 2>&1; then
  brew install --cask codex
else
  echo 'Codex já instalado; mantendo a versão atual.'
fi

log '☕ Configurando Java do Homebrew...'
JAVA_INIT='export PATH="/home/linuxbrew/.linuxbrew/opt/openjdk/bin:$PATH"'
if ! grep -Fqx "$JAVA_INIT" "$HOME/.bashrc" 2>/dev/null; then
  printf '\n# OpenJDK via Homebrew\n%s\n' "$JAVA_INIT" >> "$HOME/.bashrc"
fi
export PATH="/home/linuxbrew/.linuxbrew/opt/openjdk/bin:$PATH"

log '📲 Instalando aplicativos Flatpak via Flathub...'
# Usamos um único cadastro Flathub e instalamos cada app separadamente para
# que eventual erro em um ID não impeça a instalação dos demais.
sudo flatpak remote-add --system --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
flatpak_apps=(
  com.github.tchx84.Flatseal
  com.mattjakeman.ExtensionManager
  com.visualstudio.code
  org.qbittorrent.qBittorrent
  io.github.flattool.Warehouse
  com.anydesk.Anydesk
  dev.qwery.AddWater
  com.getpostman.Postman
  io.dbeaver.DBeaverCommunity
  org.gnome.Papers
  com.ranfdev.DistroShelf
)
for flatpak_app in "${flatpak_apps[@]}"; do
  if flatpak info --system "$flatpak_app" >/dev/null 2>&1; then
    echo "✔️  Já instalado: $flatpak_app"
  elif ! sudo flatpak install --system -y --noninteractive flathub "$flatpak_app"; then
    warn "Falhou a instalação de $flatpak_app; os demais aplicativos continuarão."
  fi
done

log '⚙️ Configurando Git...'
git config --global user.name 'Gabriel Veratti'
git config --global user.email 'gabriel.veratti@outlook.com.br'
git config --global init.defaultBranch main
git config --global core.editor nvim
git config --global color.ui auto

git lfs install --skip-repo

log '⚡ Configurando LazyVim...'
mkdir -p "$HOME/.config"
if [[ ! -f "$HOME/.config/nvim/lua/config/lazy.lua" ]]; then
  backup_dir "$HOME/.config/nvim"
  backup_dir "$HOME/.local/share/nvim"
  backup_dir "$HOME/.local/state/nvim"
  backup_dir "$HOME/.cache/nvim"
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf -- "$HOME/.config/nvim/.git"
else
  echo 'Neovim configurado; preservando os arquivos atuais.'
fi

log '🔌 Aplicando plugins personalizados...'
plugins_dir="$HOME/.config/nvim/lua/plugins"
mkdir -p "$plugins_dir"
tmp_repo="$(mktemp -d)"
trap 'rm -rf -- "$tmp_repo"' EXIT
if git clone --depth 1 https://github.com/gmveratti/nvim-configs.git "$tmp_repo/nvim-configs"; then
  shopt -s nullglob
  for plugin_file in "$tmp_repo/nvim-configs"/*.lua; do
    file_name="$(basename "$plugin_file")"
    if [[ -e "$plugins_dir/$file_name" ]]; then
      warn "Plugin já existe, não sobrescrevendo: $file_name"
    else
      cp -- "$plugin_file" "$plugins_dir/$file_name"
    fi
  done
  shopt -u nullglob
else
  warn 'Não foi possível baixar os plugins personalizados; LazyVim padrão permanece disponível.'
fi

log '✅ Instalação finalizada!'
printf '%s\n' \
  'Abra um novo terminal e faça logout/login para usar Docker sem sudo.' \
  'Testes: docker compose version | brew --version | codex --version | nvim --version' \
  'No Neovim, execute :LazyHealth para verificar as dependências.'
