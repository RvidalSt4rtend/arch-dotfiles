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
  starship
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
  grim slurp swappy wl-clipboard
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
  gtk4 gtk4-layer-shell python-gobject
  yazi
  tumbler
  mpv mpv-mpris yt-dlp
  cava
  imagemagick ffmpegthumbnailer
  gvfs gvfs-mtp xdg-user-dirs
  gtk-engine-murrine
)

# Theming: GTK3 dark port of libadwaita + Qt theme engine
PAC_THEME=(
  adw-gtk-theme
  kvantum kvantum-qt5
  qt5ct qt6ct
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

  step "Theming (GTK3 dark + Qt kvantum)"
  install_pacman "${PAC_THEME[@]}"

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
    swaync
    tmux
    waybar
    fastfetch
    qt5ct
    qt6ct
  )

  for cfg in "${configs[@]}"; do
    local src="$DOTFILES_DIR/.config/$cfg"
    local dst="$HOME/.config/$cfg"

    if [[ ! -d "$src" ]]; then
      warn "Source $src not found, skipping"
      continue
    fi

    # Some configs mix versioned files (symlinked from repo) with machine-local
    # data (kitty-themes/, tmux plugins/, hypr monitors.conf) that must NOT be
    # replaced by a dir-link. For those we stow PER FILE, leaving locals alone.
    # The rest are simple dirs that stow cleanly as a dir-link.
    local per_file="false"
    case "$cfg" in
      hypr)
        per_file="true"
        local vfiles=(hyprland.conf hypridle.conf)
        ;;
      kitty)
        per_file="true"
        local vfiles=(kitty.conf)
        ;;
      tmux)
        per_file="true"
        local vfiles=(tmux.conf sessions/dev.sh)
        mkdir -p "$dst/plugins" "$dst/sessions"
        ;;
      waybar)
        per_file="true"
        local vfiles=(config.jsonc style.css scripts)
        ;;
      nvim)
        per_file="true"
        local vfiles=(init.lua .stylua.toml lazy-lock.json lua)
        ;;
      swaync)
        per_file="true"
        local vfiles=(config.json style.css)
        ;;
    esac

    if [[ "$per_file" == "true" ]]; then
      # If dst is a dir-symlink (old whole-dir stow scheme), drop it so we can
      # build a real dir with per-file symlinks inside. Without this, `rm -f
      # "$dst/$vf"` would follow the symlink and delete files inside the repo.
      if [[ -L "$dst" ]]; then
        rm "$dst"
      fi
      mkdir -p "$dst"
      local vf
      for vf in "${vfiles[@]}"; do
        if [[ -e "$src/$vf" ]]; then
          mkdir -p "$dst/$(dirname "$vf")"
          rm -f "$dst/$vf"
          ln -sf "$src/$vf" "$dst/$vf"
          info "linked $dst/$vf -> $src/$vf"
        else
          warn "source $src/$vf missing, skipped"
        fi
      done
      # hypr: monitors.conf is machine-local — seed from .example on first install.
      if [[ "$cfg" == "hypr" && ! -e "$dst/monitors.conf" ]]; then
        if [[ -f "$src/monitors.conf.example" ]]; then
          cp "$src/monitors.conf.example" "$dst/monitors.conf"
          info "copied $src/monitors.conf.example -> $dst/monitors.conf (edit per machine)"
        else
          warn "monitors.conf.example missing; $dst/monitors.conf left unset"
        fi
      fi
      continue
    fi

    # Simple configs: stow the whole directory as a single symlink.
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

  # ~/.zshrc -> symlinked from repo root
  step "zshrc"
  local zshrc_src="$DOTFILES_DIR/.zshrc"
  local zshrc_dst="$HOME/.zshrc"
  if [[ -f "$zshrc_src" ]]; then
    if [[ -e "$zshrc_dst" && ! -L "$zshrc_dst" ]]; then
      warn "Backing up existing $zshrc_dst -> ${zshrc_dst}.bak"
      mv "$zshrc_dst" "${zshrc_dst}.bak"
    fi
    if [[ -L "$zshrc_dst" && ! -e "$zshrc_dst" ]]; then
      rm "$zshrc_dst"
    fi
    ln -sf "$zshrc_src" "$zshrc_dst"
    info "linked $zshrc_dst -> $zshrc_src"
  else
    warn "$zshrc_src not found, skipping"
  fi

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

  # Auto-install tmux plugins via TPM
  step "Installing tmux plugins"
  if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
    TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins" \
      "$tpm_dir/bin/install_plugins" 2>&1 | while read -r line; do info "$line"; done
    info "tmux plugins installed"
  else
    warn "TPM install_plugins script not found, skipping"
  fi

  # Pre-install nvim plugins (lazy.nvim auto-bootstrap + plugins sync)
  step "Pre-installing nvim plugins"
  if command -v nvim &>/dev/null; then
    nvim --headless "+Lazy! sync" +qa 2>&1 | tail -5 || true
    info "nvim plugins synced"
  else
    warn "nvim not found, skipping plugin sync"
  fi

  # Change default shell to zsh
  step "Setting default shell to zsh"
  local current_shell; current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current_shell" != "/usr/bin/zsh" ]]; then
    chsh -s /usr/bin/zsh 2>&1 || warn "chsh failed - run manually: chsh -s /usr/bin/zsh"
    info "Default shell changed to zsh"
  else
    info "Shell already zsh"
  fi
}

post_install() {
  step "Post-install notes"

  printf '\n'
  printf '%s\n' "$(color '1;32' 'Done! Everything is configured automatically:')"
  printf '\n'
  printf '  - tmux plugins installed (tmux-menus ready, trigger: \\)\n'
  printf '  - nvim plugins synced via lazy.nvim\n'
  printf '  - default shell set to zsh\n'
  printf '  - dotfiles symlinked into ~/.config\n'
  printf '  - Qt dark theme (kvantum + qt5ct/qt6ct) and GTK3 dark (adw-gtk3-dark) ready\n'
  printf '\n'
  printf '%s\n' "$(color '1;33' 'Manual steps remaining:')"
  printf '  1. Reload Hyprland:        hyprctl reload\n'
  printf '  2. Open dev environment:   cd <project> && run: tmux-dev\n'
  printf '  3. Log out and back in for shell change + yazi on workspace 0 to take effect\n'
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
