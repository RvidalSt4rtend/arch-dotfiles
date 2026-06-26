#!/usr/bin/env bash
# /* ---- ardal dotfiles - bootstrap install ---- */  #
#
# Installs all packages needed to reproduce the full Hyprland + kitty + tmux
# + nvim + waybar desktop environment on a fresh Arch Linux install.
#
# Usage:
#   ./install.sh          # install everything
#   ./install.sh packages # only install packages
#   ./install.sh stow     # only symlink dotfiles into ~/.config
#
# Requirements:
#   - Arch Linux (pacman)
#   - paru or yay (AUR helper) - will be installed if missing
#   - Run as non-root user with sudo privileges

set -euo pipefail

#  Helpers 

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
info()  { printf '%s %s\n' "$(color '1;34' '==>')" "$*"; }
warn()  { printf '%s %s\n' "$(color '1;33' '!!')" "$*"; }
fail()  { printf '%s %s\n' "$(color '1;31' 'XX')" "$*"; exit 1; }

step() { printf '\n%s %s\n' "$(color '1;35' '::')" "$*"; }

check_aur_helper() {
  if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
  elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
  else
    warn "No AUR helper found. Installing paru..."
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    ( cd "$tmp/paru" && makepkg -si --noconfirm )
    rm -rf "$tmp"
    AUR_HELPER="paru"
  fi
  info "AUR helper: $AUR_HELPER"
}

install_pacman() {
  local pkgs=("$@")
  info "pacman: ${pkgs[*]}"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

install_aur() {
  local pkgs=("$@")
  info "AUR: ${pkgs[*]}"
  "$AUR_HELPER" -S --needed --noconfirm "${pkgs[@]}"
}

#  Package lists 

# Core system: kernel, firmware, base tools
PAC_CORE=(
  base base-devel linux linux-firmware linux-headers
  amd-ucode
  grub efibootmgr
  network-manager-applet iwd
  bluez bluez-utils blueman
  pipewire pipewire-alsa pipewire-audio pipewire-pulse wireplumber
  pavucontrol pamixer playerctl
  brightnessctl
  ufw
  git wget curl jq fzf ripgrep less unzip
  zsh zsh-completions
  zoxide
  lsd
  fastfetch
  btop
  nano
)

# Hyprland ecosystem
PAC_HYPRLAND=(
  hyprland
  hypridle hyprlock hyprpolkitagent
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  hyprcursor
  nwg-displays nwg-look
  grim swappy
  wallust waypaper
  wlogout
  swaync
  cliphist
  wl-gammarelay-rs
  gammastep
)

# Terminal + multiplexer + editor
PAC_TERMINAL=(
  kitty
  tmux
  neovim
  lazygit
)

# Bar + launcher + misc GUI
PAC_GUI=(
  waybar
  thunar thunar-archive-plugin thunar-volman tumbler
  mpv mpv-mpris yt-dlp
  cava
  imagemagick ffmpegthumbnailer
  gvfs gvfs-mtp xdg-user-dirs
  gtk-engine-murrine
)

# Fonts
PAC_FONTS=(
  ttf-jetbrains-mono-nerd
  ttf-fantasque-nerd
  ttf-fira-code
  ttf-droid
  noto-fonts noto-fonts-emoji
  adobe-source-code-pro-fonts
  woff2-font-awesome
)

# Dev tools
PAC_DEV=(
  docker docker-compose
  npm
  pyenv
  mercurial
)

# Graphics / drivers (AMD)
PAC_GRAPHICS=(
  mesa-utils
  vulkan-radeon lib32-vulkan-radeon
  vulkan-tools
  nvtop
)

# AUR-only packages
AUR_PKGS=(
  zen-browser-bin
  ttf-material-design-icons-git
  ttf-ms-fonts
  ttf-victor-mono
  wl-gammarelay-rs
  wallust
  waypaper
  wlogout
  nwg-displays
  nwg-look
  paru
)

#  Phases 

install_packages() {
  step "Core system"
  install_pacman "${PAC_CORE[@]}"

  step "Hyprland ecosystem"
  install_pacman "${PAC_HYPRLAND[@]}"

  step "Terminal + tmux + editor"
  install_pacman "${PAC_TERMINAL[@]}"

  step "GUI apps"
  install_pacman "${PAC_GUI[@]}"

  step "Fonts"
  install_pacman "${PAC_FONTS[@]}"

  step "Dev tools"
  install_pacman "${PAC_DEV[@]}"

  step "Graphics drivers - AMD"
  install_pacman "${PAC_GRAPHICS[@]}"

  step "AUR packages"
  check_aur_helper
  install_aur "${AUR_PKGS[@]}"
}

stow_dotfiles() {
  step "Symlinking dotfiles into ~/.config"

  local configs=(
    hypr
    kitty
    nvim
    tmux
    waybar
  )

  for cfg in "${configs[@]}"; do
    local src="$DOTFILES_DIR/.config/$cfg"
    local dst="$HOME/.config/$cfg"

    if [[ ! -d "$src" ]]; then
      warn "Source $src not found, skipping"
      continue
    fi

    # Back up existing non-symlink config
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      warn "Backing up existing $dst -> ${dst}.bak"
      mv "$dst" "${dst}.bak"
    fi

    # Remove broken symlink if present
    if [[ -L "$dst" && ! -e "$dst" ]]; then
      rm "$dst"
    fi

    mkdir -p "$HOME/.config"
    ln -sf "$src" "$dst"
    info "linked $dst -> $src"
  done

  # tmux dev session script -> ~/.local/bin
  step "Dev session script"
  mkdir -p "$HOME/.local/bin"
  local dev_script="$DOTFILES_DIR/.config/tmux/sessions/dev.sh"
  if [[ -f "$dev_script" ]]; then
    chmod +x "$dev_script"
    ln -sf "$dev_script" "$HOME/.local/bin/tmux-dev"
    info "linked $HOME/.local/bin/tmux-dev -> $dev_script"
  fi

  # Clone TPM for tmux plugins
  step "Tmux Plugin Manager - TPM"
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"
  if [[ ! -d "$tpm_dir" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    info "TPM cloned to $tpm_dir"
  else
    info "TPM already present"
  fi
}

post_install() {
  step "Post-install notes"

  printf '\n'
  printf '%s\n' "$(color '1;32' 'Done! Next steps:')"
  printf '\n'
  printf '  1. Reload Hyprland:        hyprctl reload\n'
  printf '  2. Start tmux plugins:     tmux, then press Ctrl-a + I - capital i\n'
  printf '  3. Open dev environment:   Super+D  - or run: tmux-dev\n'
  printf '  4. Open nvim plugins:      nvim - lazy.nvim will auto-install\n'
  printf '  5. Change shell to zsh:    chsh -s /usr/bin/zsh\n'
  printf '\n'
  printf '%s\n' "$(color '1;33' 'Note: AUR packages need paru or yay.')"
  printf '%s\n' "$(color '1;33' 'Note: Some packages - metasploit, ffuf, etc - are not')"
  printf '%s\n' "$(color '1;33' '      included as they are niche security tools. Install manually if needed.')"
  printf '\n'
}

#  Main 

main() {
  printf '%s\n' "$(color '1;36' '================================================')"
  printf '%s\n' "$(color '1;36' '   ardal-dotfiles bootstrap installer')"
  printf '%s\n' "$(color '1;36' '================================================')"
  printf '\n'

  [[ "$(id -u)" -eq 0 ]] && fail "Do not run this as root. Run as your user with sudo."

  local phase="${1:-all}"

  case "$phase" in
    packages) install_packages ;;
    stow)     stow_dotfiles ;;
    all)
      install_packages
      stow_dotfiles
      ;;
    *)
      fail "Unknown phase: $phase. Use: packages | stow | all"
      ;;
  esac

  post_install
}

main "$@"
