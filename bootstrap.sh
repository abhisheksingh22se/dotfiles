#!/usr/bin/env bash
# Bootstrap this dotfiles repo on macOS or Linux: install stow if missing, install
# packages (Brewfile on macOS, Archfile on Arch), then stow every package that
# applies to this OS.
#
# Idempotent — safe to re-run any time after editing a package, the Brewfile, or the
# Archfile.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin) os=macos ;;
  Linux)  os=linux ;;
  *) echo "unsupported OS: $(uname -s) — this script only handles macOS and Linux (use bootstrap.ps1 on Windows)" >&2; exit 1 ;;
esac
echo "detected OS: $os"

# Package -> OS applicability. Not an associative array on purpose: macOS ships bash 3.2
# at /bin/bash (no `declare -A` support, and no newer bash is guaranteed to be installed
# yet on a fresh machine), so this stays plain arrays for portability.
ALL_PKGS=(wezterm yt-dlp zsh git p10k)
MACOS_ONLY_PKGS=(aerospace sketchybar)      # no Linux/Windows port exists or ever will
LINUX_ONLY_PKGS=(hypr waybar rofi mako)     # Wayland desktop; meaningless on macOS

if ! command -v stow >/dev/null 2>&1; then
  echo "stow not found, installing..."
  if [[ "$os" == macos ]]; then
    command -v brew >/dev/null 2>&1 || { echo "Homebrew is required on macOS — install it first: https://brew.sh" >&2; exit 1; }
    brew install stow
  else
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y stow
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -S --noconfirm stow
    else
      echo "no known package manager (apt/pacman) found — install stow manually" >&2
      exit 1
    fi
  fi
fi

if [[ "$os" == macos ]] && [[ -f "$here/Brewfile" ]]; then
  echo "installing Homebrew packages from Brewfile..."
  brew bundle install --file="$here/Brewfile"
fi

# Arch counterpart of `brew bundle`. Only runs where pacman exists — the Archfile is
# Arch-specific by design, and silently half-applying it on Debian would be worse than
# not running at all.
if [[ "$os" == linux ]] && [[ -f "$here/Archfile" ]] && command -v pacman >/dev/null 2>&1; then
  echo "installing packages from Archfile..."

  # Parse once into four lists. `pac`/`aur`/`npm`/`cargo` mirror the Brewfile's
  # brew/cask/npm/cargo prefixes.
  pac_pkgs=$(  awk '$1=="pac"   {print $2}' "$here/Archfile")
  aur_pkgs=$(  awk '$1=="aur"   {print $2}' "$here/Archfile")
  npm_pkgs=$(  awk '$1=="npm"   {print $2}' "$here/Archfile")
  cargo_pkgs=$(awk '$1=="cargo" {print $2}' "$here/Archfile")

  # --needed makes this a no-op for anything already present, which is what keeps
  # re-runs cheap. Not --noconfirm: package replacements and provider choices on Arch
  # are decisions worth seeing.
  if [[ -n "$pac_pkgs" ]]; then
    # shellcheck disable=SC2086
    sudo pacman -S --needed $pac_pkgs
  fi

  if [[ -n "$aur_pkgs" ]]; then
    if ! command -v yay >/dev/null 2>&1; then
      echo "yay not found, building it from the AUR..."
      sudo pacman -S --needed --noconfirm git base-devel
      tmp="$(mktemp -d)"
      git clone https://aur.archlinux.org/yay.git "$tmp/yay"
      (cd "$tmp/yay" && makepkg -si --noconfirm)
      rm -rf "$tmp"
    fi
    # shellcheck disable=SC2086
    yay -S --needed $aur_pkgs
  fi

  if [[ -n "$npm_pkgs" ]] && command -v npm >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    sudo npm install -g $npm_pkgs
  fi

  if [[ -n "$cargo_pkgs" ]] && command -v cargo >/dev/null 2>&1; then
    for p in $cargo_pkgs; do
      cargo install --locked "$p" || echo "cargo install $p failed, continuing" >&2
    done
  fi
fi

for pkg in "${ALL_PKGS[@]}"; do
  echo "stowing $pkg"
  stow -d "$here" -t "$HOME" -R "$pkg"
done

if [[ "$os" == macos ]]; then
  for pkg in "${MACOS_ONLY_PKGS[@]}"; do
    echo "stowing $pkg"
    stow -d "$here" -t "$HOME" -R "$pkg"
  done
else
  for pkg in "${LINUX_ONLY_PKGS[@]}"; do
    echo "stowing $pkg"
    stow -d "$here" -t "$HOME" -R "$pkg"
  done
fi

if [[ ! -f "$HOME/.gitconfig.local" ]]; then
  echo "writing ~/.gitconfig.local (credential helper, machine-specific, never tracked)"
  if [[ "$os" == macos ]]; then
    helper=osxkeychain
  elif [[ -x /usr/lib/git-core/git-credential-libsecret ]]; then
    # The right answer wherever a Secret Service daemon is running, which under
    # Hyprland means gnome-keyring. Arch ships the *source* for this helper in
    # /usr/share/git/credential/libsecret and expects you to `make` it, so the check
    # is for the built binary, not for something on PATH — and it stays unset rather
    # than guessed if it isn't there.
    helper=libsecret
  else
    helper=""
    echo "  (no credential helper set — build one with:" >&2
    echo "     sudo make -C /usr/share/git/credential/libsecret" >&2
    echo "   then: git config --global credential.helper libsecret)" >&2
  fi
  {
    echo "[credential]"
    [[ -n "$helper" ]] && echo "	helper = $helper"
  } > "$HOME/.gitconfig.local"
fi

# Directories the configs assume exist. Cheap to create, annoying to debug when absent
# (hyprpaper silently shows nothing, grim fails with a bare "no such file").
if [[ "$os" == linux ]]; then
  mkdir -p "$HOME/Pictures/screenshots" "$HOME/Pictures/wallpapers"
fi

echo "bootstrap complete."
