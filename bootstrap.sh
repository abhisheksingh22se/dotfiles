#!/usr/bin/env bash
# Bootstrap this dotfiles repo on macOS or Linux: install stow if missing, install
# Homebrew packages (macOS only), then stow every package that applies to this OS.
#
# Idempotent — safe to re-run any time after editing a package or the Brewfile.
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
MACOS_ONLY_PKGS=(aerospace sketchybar)   # no Linux/Windows port exists or ever will

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

for pkg in "${ALL_PKGS[@]}"; do
  echo "stowing $pkg"
  stow -d "$here" -t "$HOME" -R "$pkg"
done

if [[ "$os" == macos ]]; then
  for pkg in "${MACOS_ONLY_PKGS[@]}"; do
    echo "stowing $pkg"
    stow -d "$here" -t "$HOME" -R "$pkg"
  done
fi

if [[ ! -f "$HOME/.gitconfig.local" ]]; then
  echo "writing ~/.gitconfig.local (credential helper, machine-specific, never tracked)"
  if [[ "$os" == macos ]]; then
    helper=osxkeychain
  else
    # No safe universal default on Linux — libsecret needs a package that may not be
    # installed on every distro. Left unset; add credential.helper manually once you
    # know what your distro provides, e.g.:
    #   git config --global credential.helper 'cache --timeout=3600'
    helper=""
  fi
  {
    echo "[credential]"
    [[ -n "$helper" ]] && echo "	helper = $helper"
  } > "$HOME/.gitconfig.local"
fi

echo "bootstrap complete."
