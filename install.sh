#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/enhanced-terminal"
LOG_FILE="$HOME/enhanced-terminal-$(date +%Y%m%d-%H%M%S).log"

AUTO_YES=false
DRY_RUN=false
INTERACTIVE=$([[ $# -eq 0 ]] && printf true || printf false)
UNINSTALL=false

DO_UPDATE=false
DO_REMOVE_SNAP=false
DO_FLATPAK=false
DO_GNOME_SOFTWARE=false
DO_FLATPAK_APPS=false
DO_CLEAN=false
DO_FCITX5=false
DO_REMOVE_IBUS_UNIKEY=false
DO_KITTY=false
DO_SHELL_STACK=false
DO_FASTFETCH=false
DO_NERD_FONT=false
PTYXIS_OPACITY=""
RESET_PTYXIS_OPACITY=false
FASTFETCH_IMAGE="$SCRIPT_DIR/fastfetch/assets/bg_terminal.png"

FLATPAK_APPS=(org.mozilla.firefox org.mozilla.thunderbird_esr)

if [[ -t 1 ]]; then
  RESET=$'\033[0m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'
else
  RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""
fi

info()    { printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()      { printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()     { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
section() { printf '\n%s== %s ==%s\n' "$BOLD" "$*" "$RESET"; }
has()     { command -v "$1" >/dev/null 2>&1; }
pkg_available() { apt-cache show "$1" >/dev/null 2>&1; }
pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

run() {
  printf '+ '; printf '%q ' "$@"; printf '\n'
  [[ "$DRY_RUN" == true ]] || "$@"
}

ask() {
  local answer
  read -r -p "$1 [y/N]: " answer
  [[ "${answer,,}" == y || "${answer,,}" == yes ]]
}

confirm() {
  [[ "$AUTO_YES" == true ]] || ask "$1"
}

record() {
  [[ "$DRY_RUN" == true ]] && return
  mkdir -p "$STATE_DIR"
  grep -Fqx "$2" "$STATE_DIR/$1" 2>/dev/null || printf '%s\n' "$2" >> "$STATE_DIR/$1"
}

install_packages() {
  local available=() new=() package
  for package in "$@"; do
    if pkg_installed "$package"; then
      info "$package is already installed; skipping."
    elif pkg_available "$package"; then
      available+=("$package")
      new+=("$package")
    else
      warn "Package not found: $package; skipping."
    fi
  done
  ((${#available[@]})) || return 0
  run sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${available[@]}"
  for package in "${new[@]}"; do record packages "$package"; done
}

backup_once() {
  local key="$1" file="$2" backup
  backup="$STATE_DIR/backups/$key"
  [[ -e "$backup" || -e "$backup.missing" ]] && return
  if [[ "$DRY_RUN" == true ]]; then
    printf '+ back up %q\n' "$file"
  elif [[ -e "$file" || -L "$file" ]]; then
    mkdir -p "$(dirname "$backup")"
    cp -a "$file" "$backup"
  else
    mkdir -p "$(dirname "$backup")"
    touch "$backup.missing"
  fi
}

restore_one() {
  local key="$1" file="$2" backup
  backup="$STATE_DIR/backups/$key"
  if [[ -e "$backup" || -L "$backup" ]]; then
    run mkdir -p "$(dirname "$file")"
    run rm -rf "$file"
    run cp -a "$backup" "$file"
  elif [[ -e "$backup.missing" ]]; then
    run rm -rf "$file"
  fi
}

ensure_line() {
  local line="$1" file="$2"
  run touch "$file"
  grep -Fqx "$line" "$file" 2>/dev/null && return
  if [[ "$DRY_RUN" == true ]]; then
    printf '+ append %q to %q\n' "$line" "$file"
  else
    printf '\n%s\n' "$line" >> "$file"
  fi
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

No options opens the interactive wizard. Every wizard choice defaults to No.

General:
  --interactive              Open the interactive wizard
  --yes, -y                  Skip the final confirmation
  --dry-run                  Print commands without changing the system
  --uninstall                Roll back changes recorded by this script
  --update                   Update and full-upgrade Ubuntu
  --remove-snap              Remove and block Snap (not fully reversible)
  --install-flatpak          Install Flatpak and add Flathub
  --install-gnome-software   Install GNOME Software and plugins
  --install-flatpak-apps     Install the configured Flatpak applications
  --clean                    Remove unused packages and caches

Desktop:
  --install-fcitx5           Install Fcitx5 with Unikey
  --remove-ibus-unikey       Remove ibus-unikey
  --switch-to-fcitx5         Install Fcitx5 and remove ibus-unikey
  --install-kitty            Install Kitty
  --ptyxis-opacity VALUE     Set Ptyxis opacity from 0.20 to 1.00
  --reset-ptyxis-opacity     Reset Ptyxis opacity
  --install-nerd-font        Install JetBrainsMono Nerd Font
  --install-fastfetch        Install Fastfetch and the bundled config/image
  --fastfetch-image FILE     Use a different Fastfetch image
  --install-shell-stack      Install Zsh, Oh My Zsh, plugins, and Starship
  --desktop-stack            Install font, Fastfetch, and shell stack
  --full                     Install the desktop stack and Kitty
EOF
}

valid_opacity() {
  [[ "$1" =~ ^(0\.[0-9]+|1(\.0+)?)$ ]] &&
    awk -v value="$1" 'BEGIN { exit !(value >= 0.20 && value <= 1.00) }'
}

wizard() {
  section "Interactive setup"
  ask "Update the system?" && DO_UPDATE=true
  ask "Remove Snap? This cannot be fully rolled back" && DO_REMOVE_SNAP=true
  ask "Install Flatpak and Flathub?" && DO_FLATPAK=true
  ask "Install GNOME Software?" && DO_GNOME_SOFTWARE=true
  ask "Install Firefox and Thunderbird from Flathub?" && DO_FLATPAK_APPS=true
  ask "Install JetBrainsMono Nerd Font?" && DO_NERD_FONT=true
  ask "Install Fastfetch with the bundled image?" && DO_FASTFETCH=true
  ask "Install Zsh, Oh My Zsh, plugins, and Starship?" && DO_SHELL_STACK=true

  printf '\nTerminal appearance:\n  1) Do nothing\n  2) Configure Ptyxis opacity\n  3) Install Kitty\n'
  local terminal_choice opacity
  read -r -p "Choose [1]: " terminal_choice
  case "${terminal_choice:-1}" in
    1) ;;
    2)
      while :; do
        read -r -p "Opacity (0.20-1.00) [0.75]: " opacity
        opacity="${opacity:-0.75}"
        valid_opacity "$opacity" && { PTYXIS_OPACITY="$opacity"; break; }
        warn "Enter a value from 0.20 to 1.00."
      done
      ;;
    3) DO_KITTY=true ;;
    *) die "Invalid terminal choice: $terminal_choice" ;;
  esac

  ask "Install Fcitx5 with Unikey?" && DO_FCITX5=true
  if [[ "$DO_FCITX5" == true ]]; then
    ask "Remove ibus-unikey after switching?" && DO_REMOVE_IBUS_UNIKEY=true
  fi
  ask "Clean unused packages and caches at the end?" && DO_CLEAN=true
  return 0
}

while (($#)); do
  case "$1" in
    --interactive) INTERACTIVE=true ;;
    --yes|-y) AUTO_YES=true ;;
    --dry-run) DRY_RUN=true ;;
    --uninstall) UNINSTALL=true ;;
    --update) DO_UPDATE=true ;;
    --remove-snap) DO_REMOVE_SNAP=true ;;
    --install-flatpak) DO_FLATPAK=true ;;
    --install-gnome-software) DO_GNOME_SOFTWARE=true ;;
    --install-flatpak-apps) DO_FLATPAK_APPS=true ;;
    --clean) DO_CLEAN=true ;;
    --install-fcitx5) DO_FCITX5=true ;;
    --remove-ibus-unikey) DO_REMOVE_IBUS_UNIKEY=true ;;
    --switch-to-fcitx5) DO_FCITX5=true; DO_REMOVE_IBUS_UNIKEY=true ;;
    --install-kitty) DO_KITTY=true ;;
    --install-nerd-font) DO_NERD_FONT=true ;;
    --install-fastfetch) DO_FASTFETCH=true ;;
    --fastfetch-image)
      shift
      (($#)) || die "--fastfetch-image requires a file."
      FASTFETCH_IMAGE="$1"; DO_FASTFETCH=true
      ;;
    --install-shell-stack) DO_SHELL_STACK=true ;;
    --ptyxis-opacity)
      shift
      (($#)) || die "--ptyxis-opacity requires a value."
      valid_opacity "$1" || die "Opacity must be from 0.20 to 1.00."
      PTYXIS_OPACITY="$1"
      ;;
    --reset-ptyxis-opacity) RESET_PTYXIS_OPACITY=true ;;
    --desktop-stack) DO_NERD_FONT=true; DO_FASTFETCH=true; DO_SHELL_STACK=true ;;
    --full)
      DO_NERD_FONT=true; DO_FASTFETCH=true; DO_SHELL_STACK=true; DO_KITTY=true
      ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

preflight() {
  section "System check"
  [[ "$EUID" -ne 0 ]] || die "Do not run the whole script with sudo."
  source /etc/os-release
  [[ "${ID:-}" == ubuntu ]] || warn "Designed for Ubuntu; detected ${PRETTY_NAME:-unknown}."
  has apt-get || die "apt-get is required."
  run sudo -v
  ok "Log: $LOG_FILE"
}

update_system() {
  [[ "$DO_UPDATE" == true ]] || return 0
  section "Update system"
  run sudo apt-get update
  run sudo env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
  install_packages curl git unzip ca-certificates fontconfig
}

remove_snap() {
  [[ "$DO_REMOVE_SNAP" == true ]] || return 0
  section "Remove Snap"
  warn "Removed snaps and their data cannot be restored by --uninstall."
  if has snap; then
    mapfile -t snaps < <(snap list 2>/dev/null | awk 'NR>1 {print $1}' | tac || true)
    local snap_name
    for snap_name in "${snaps[@]:-}"; do
      [[ -n "$snap_name" ]] && run sudo snap remove --purge "$snap_name" || true
    done
  fi
  pkg_installed snapd && run sudo systemctl disable --now snapd.socket snapd.service snapd.seeded.service || true
  pkg_installed snapd && run sudo apt-get purge -y snapd
  run sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd
  run rm -rf "$HOME/snap"
  backup_once nosnap.pref /etc/apt/preferences.d/nosnap.pref
  if [[ "$DRY_RUN" == true ]]; then
    info "Would write /etc/apt/preferences.d/nosnap.pref."
  else
    sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null <<'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
  fi
}

ensure_flatpak() {
  install_packages flatpak
  has flatpak || [[ "$DRY_RUN" == true ]] || return 1
  run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_flatpak() {
  [[ "$DO_FLATPAK" == true ]] || return 0
  section "Flatpak and Flathub"
  ensure_flatpak
  run flatpak update --appstream -y
}

install_gnome_software() {
  [[ "$DO_GNOME_SOFTWARE" == true ]] || return 0
  section "GNOME Software"
  install_packages gnome-software gnome-software-plugin-flatpak gnome-software-plugin-fwupd fwupd
  pkg_available gnome-software-plugin-deb && install_packages gnome-software-plugin-deb
}

install_flatpak_apps() {
  [[ "$DO_FLATPAK_APPS" == true ]] || return 0
  section "Flatpak applications"
  ensure_flatpak
  local app
  for app in "${FLATPAK_APPS[@]}"; do
    if flatpak info "$app" >/dev/null 2>&1; then
      info "$app is already installed; skipping."
    elif flatpak remote-info flathub "$app" >/dev/null 2>&1 || [[ "$DRY_RUN" == true ]]; then
      run flatpak install -y flathub "$app"
      record flatpak-apps "$app"
    else
      warn "$app is unavailable on Flathub; skipping."
    fi
  done
}

install_nerd_font() {
  [[ "$DO_NERD_FONT" == true ]] || return 0
  section "JetBrainsMono Nerd Font"
  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont" tmp
  if find "$font_dir" -type f -iname '*NerdFont*' -print -quit 2>/dev/null | grep -q .; then
    info "JetBrainsMono Nerd Font is already installed; skipping."
    return
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"; trap - RETURN' RETURN
  run mkdir -p "$font_dir"
  run curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -o "$tmp/JetBrainsMono.zip"
  run unzip -o "$tmp/JetBrainsMono.zip" -d "$font_dir"
  run fc-cache -f
  record created "$font_dir"
}

install_fastfetch() {
  [[ "$DO_FASTFETCH" == true ]] || return 0
  section "Fastfetch"
  install_packages fastfetch chafa imagemagick
  [[ -f "$FASTFETCH_IMAGE" ]] || die "Fastfetch image not found: $FASTFETCH_IMAGE"

  local target="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
  local source="$SCRIPT_DIR/fastfetch"
  [[ -f "$source/config.jsonc" ]] || die "Missing $source/config.jsonc."
  backup_once fastfetch "$target"
  run mkdir -p "$target/assets"
  run cp "$source/config.jsonc" "$target/config.jsonc"
  run cp "$FASTFETCH_IMAGE" "$target/assets/bg_terminal.png"
  if [[ "$DRY_RUN" == true ]]; then
    printf '+ set logo path in %q\n' "$target/config.jsonc"
  else
    sed -i "s|assets/bg_terminal.png|$target/assets/bg_terminal.png|" "$target/config.jsonc"
  fi
  ok "Fastfetch config installed."
}

install_shell_stack() {
  [[ "$DO_SHELL_STACK" == true ]] || return 0
  section "Zsh, Oh My Zsh, and Starship"
  local zshrc="$HOME/.zshrc"
  backup_once zshrc "$zshrc"
  install_packages zsh git curl

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    info "Oh My Zsh is already installed; skipping."
  elif [[ "$DRY_RUN" == true ]]; then
    info "Would install Oh My Zsh."
  else
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    record created "$HOME/.oh-my-zsh"
  fi

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}" plugin repo
  declare -A plugins=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
  )
  for plugin in "${!plugins[@]}"; do
    repo="${plugins[$plugin]}"
    if [[ -d "$custom/plugins/$plugin" ]]; then
      info "$plugin is already installed; skipping."
    else
      run git clone --depth=1 "$repo" "$custom/plugins/$plugin"
      record created "$custom/plugins/$plugin"
    fi
  done

  if has starship; then
    info "Starship is already installed; skipping."
  else
    run mkdir -p "$HOME/.local/bin"
    if [[ "$DRY_RUN" == true ]]; then
      info "Would install Starship."
    else
      curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
      record created "$HOME/.local/bin/starship"
    fi
  fi

  local starship_target="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
  backup_once starship.toml "$starship_target"
  run mkdir -p "$(dirname "$starship_target")"
  run cp "$SCRIPT_DIR/configs/starship.toml" "$starship_target"
  run touch "$zshrc"
  if grep -qE '^[[:space:]]*plugins=' "$zshrc"; then
    [[ "$DRY_RUN" == true ]] || sed -i -E 's|^[[:space:]]*plugins=.*|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|' "$zshrc"
  else
    ensure_line 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' "$zshrc"
  fi
  ensure_line 'export PATH="$HOME/.local/bin:$PATH"' "$zshrc"
  ensure_line 'eval "$(starship init zsh)"' "$zshrc"
  [[ "$DO_FASTFETCH" == true ]] &&
    ensure_line '[[ -o interactive ]] && command -v fastfetch >/dev/null 2>&1 && fastfetch' "$zshrc"

  local zsh_path current_shell
  zsh_path="$(command -v zsh || true)"
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ -n "$zsh_path" && "$current_shell" != "$zsh_path" ]]; then
    record previous-shell "$current_shell"
    run chsh -s "$zsh_path"
  fi
}

configure_ptyxis() {
  [[ -n "$PTYXIS_OPACITY" || "$RESET_PTYXIS_OPACITY" == true ]] || return 0
  section "Ptyxis opacity"
  has gsettings || { warn "gsettings is unavailable; skipping."; return; }
  local profile schema old_value
  profile="$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'" || true)"
  [[ -n "$profile" ]] || { warn "No Ptyxis profile found; skipping."; return; }
  schema="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$profile/"
  if [[ ! -f "$STATE_DIR/ptyxis-schema" && "$DRY_RUN" == false ]]; then
    mkdir -p "$STATE_DIR"
    old_value="$(gsettings get "$schema" opacity)"
    printf '%s\n' "$schema" > "$STATE_DIR/ptyxis-schema"
    printf '%s\n' "$old_value" > "$STATE_DIR/ptyxis-opacity"
  fi
  if [[ "$RESET_PTYXIS_OPACITY" == true ]]; then
    run gsettings reset "$schema" opacity
  else
    run gsettings set "$schema" opacity "$PTYXIS_OPACITY"
  fi
}

install_kitty() {
  [[ "$DO_KITTY" == true ]] || return 0
  section "Kitty"
  install_packages kitty
}

install_fcitx5() {
  [[ "$DO_FCITX5" == true || "$DO_REMOVE_IBUS_UNIKEY" == true ]] || return 0
  section "Fcitx5"
  if [[ "$DO_FCITX5" == true ]]; then
    install_packages fcitx5 fcitx5-unikey fcitx5-config-qt \
      fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 \
      fcitx5-frontend-qt6 im-config
    has im-config && run im-config -n fcitx5
    local autostart="$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
    backup_once fcitx5-autostart "$autostart"
    if [[ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]]; then
      run mkdir -p "$(dirname "$autostart")"
      run cp /usr/share/applications/org.fcitx.Fcitx5.desktop "$autostart"
    fi
  fi
  if [[ "$DO_REMOVE_IBUS_UNIKEY" == true ]] && pkg_installed ibus-unikey; then
    run sudo apt-get purge -y ibus-unikey
    record removed-packages ibus-unikey
  fi
}

clean_system() {
  [[ "$DO_CLEAN" == true ]] || return 0
  section "Clean system"
  warn "Cache cleanup and autoremove cannot be rolled back."
  run sudo apt-get autoremove --purge -y
  run sudo apt-get autoclean
  run sudo apt-get clean
  has flatpak && run flatpak uninstall --unused -y
  run sudo journalctl --vacuum-time=7d
}

uninstall_all() {
  section "Roll back managed changes"
  [[ -d "$STATE_DIR" ]] || { info "No recorded installation state; nothing to do."; return; }
  confirm "Restore configs and remove items installed by this script?" || return 0

  restore_one fastfetch "${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
  restore_one starship.toml "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
  restore_one zshrc "$HOME/.zshrc"
  restore_one fcitx5-autostart "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
  if [[ -e "$STATE_DIR/backups/nosnap.pref" ]]; then
    run sudo cp -a "$STATE_DIR/backups/nosnap.pref" /etc/apt/preferences.d/nosnap.pref
  elif [[ -e "$STATE_DIR/backups/nosnap.pref.missing" ]]; then
    run sudo rm -f /etc/apt/preferences.d/nosnap.pref
  fi

  if [[ -f "$STATE_DIR/ptyxis-schema" && -f "$STATE_DIR/ptyxis-opacity" ]]; then
    run gsettings set "$(<"$STATE_DIR/ptyxis-schema")" opacity "$(<"$STATE_DIR/ptyxis-opacity")"
  fi
  if [[ -s "$STATE_DIR/previous-shell" ]]; then
    run chsh -s "$(head -n1 "$STATE_DIR/previous-shell")"
  fi
  if [[ -f "$STATE_DIR/created" ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] && run rm -rf "$path"
    done < "$STATE_DIR/created"
  fi
  if [[ -f "$STATE_DIR/flatpak-apps" ]]; then
    while IFS= read -r app; do run flatpak uninstall -y "$app"; done < "$STATE_DIR/flatpak-apps"
  fi
  if [[ -f "$STATE_DIR/removed-packages" ]]; then
    while IFS= read -r package; do
      run sudo apt-get install -y "$package"
    done < "$STATE_DIR/removed-packages"
  fi
  if [[ -f "$STATE_DIR/packages" ]]; then
    mapfile -t packages < "$STATE_DIR/packages"
    ((${#packages[@]})) && run sudo apt-get purge -y "${packages[@]}"
  fi
  [[ "$DRY_RUN" == true ]] || rm -rf "$STATE_DIR"
  ok "Managed changes were rolled back."
}

main() {
  [[ "$INTERACTIVE" == true && "$UNINSTALL" == false ]] && wizard
  exec > >(tee -a "$LOG_FILE") 2>&1
  trap 'die "Error on line $LINENO. See $LOG_FILE"' ERR
  preflight
  if [[ "$UNINSTALL" == true ]]; then
    uninstall_all
    return
  fi
  confirm "Apply the selected changes?" || return 0
  update_system
  remove_snap
  install_flatpak
  install_gnome_software
  install_flatpak_apps
  install_nerd_font
  install_fastfetch
  install_shell_stack
  configure_ptyxis
  install_kitty
  install_fcitx5
  clean_system
  section "Done"
  info "Log: $LOG_FILE"
  info "Log out or reboot to apply shell and input-method changes."
}

main "$@"
