#!/bin/bash

# 1. System Update & RPM Fusion
echo "🔄 Atualizando sistema..."
sudo dnf upgrade --refresh -y

echo "📦 Instalando RPM Fusion..."
sudo dnf install -y \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo dnf install -y rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted 

sudo dnf install ncurses -y

# 2. Ferramentas Base
echo "🛠️ Instalando Ferramentas de Desenvolvimento..."
sudo dnf groupinstall "Development Tools" -y
sudo dnf install procps-ng curl file git -y

# 3. Oh My Bash
echo "🎨 Instalando Oh My Bash..."
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended

# 4. Docker (Configuração Robusta)
echo "🐳 Configurando Docker..."
sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine

sudo dnf -y install dnf-plugins-core
sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo systemctl enable --now docker

getent group docker || sudo groupadd docker
sudo usermod -aG docker $USER

# 5. Homebrew
echo "🍺 Instalando Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> ~/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 6. Pacotes Brew
echo "📦 Instalando pacotes via Brew..."
brew install gcc go java neovim node python lazygit lazydocker

# 7. Git Config
echo "⚙️ Configurando Git..."
git config --global user.name "Gabriel Veratti"
git config --global user.email "gabriel.veratti@outlook.com.br"
git config --global init.defaultBranch main
git config --global core.editor "nvim"
git config --global color.ui auto

# 8. Neovim Setup
echo "⚡ Configurando LazyVim..."

rm -rf ~/.config/nvim
rm -rf ~/.local/share/nvim

git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

cd ~/.config/nvim/lua/plugins/ || exit

git clone https://github.com/gmveratti/nvim-configs.git

mv nvim-configs/*.lua .
rm -rf nvim-configs

echo "✅ Instalação Completa! Reinicie o terminal.
