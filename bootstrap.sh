#!/usr/bin/env bash
# Bootstrap this dotfiles repo on macOS or Linux: install stow if missing, install
# packages (Brewfile on macOS, Archfile on Arch), then stow every package that
# applies to this OS.
#
# Idempotent — safe to re-run any time after editing a package, the Brewfile, or the
# Archfile.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --no-packages / --stow-only: skip the Brewfile/Archfile pass and just re-link the
# configs. This is the common case after the first run, and it turns a several-minute
# step into an instant one.
do_packages=yes
for arg in "$@"; do
  case "$arg" in
    --no-packages|--stow-only) do_packages=no ;;
    -h|--help)
      echo "usage: bootstrap.sh [--no-packages|--stow-only]"
      echo "  --no-packages   skip Brewfile/Archfile installation, only stow configs"
      exit 0 ;;
    *) echo "unknown argument: $arg (try --help)" >&2; exit 1 ;;
  esac
done

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
LINUX_ONLY_PKGS=(hypr ambxst rofi mako gtk) # Wayland desktop; meaningless on macOS

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

if [[ "$os" == macos ]] && [[ "$do_packages" == yes ]] && [[ -f "$here/Brewfile" ]]; then
  echo "installing Homebrew packages from Brewfile..."
  brew bundle install --file="$here/Brewfile"
fi

# Arch counterpart of `brew bundle`. Only runs where pacman exists — the Archfile is
# Arch-specific by design, and silently half-applying it on Debian would be worse than
# not running at all.
#
# The guiding rule for this whole block: **a package that fails to install must never
# stop the run.** Stowing the configs below is the part that actually makes a machine
# usable, and losing it because one AUR build broke or one package moved repos is the
# worst possible trade. Everything here collects failures and reports them at the end
# instead of aborting.
failed_pkgs=""

if [[ "$os" == linux ]] && [[ "$do_packages" == yes ]] && [[ -f "$here/Archfile" ]] && command -v pacman >/dev/null 2>&1; then
  echo "installing packages from Archfile..."

  # `set -e` is what turned a single missing package into a dead run: pacman exits 1 on
  # "target not found" and the shell takes the whole script down with it, before
  # anything gets stowed. Off for the package phase, restored immediately after.
  set +e

  # Parse once into four lists. `pac`/`aur`/`npm`/`cargo` mirror the Brewfile's
  # brew/cask/npm/cargo prefixes.
  pac_pkgs=$(  awk '$1=="pac"   {print $2}' "$here/Archfile")
  aur_pkgs=$(  awk '$1=="aur"   {print $2}' "$here/Archfile")
  npm_pkgs=$(  awk '$1=="npm"   {print $2}' "$here/Archfile")
  cargo_pkgs=$(awk '$1=="cargo" {print $2}' "$here/Archfile")

  # ── Route anything that isn't actually in a configured repo to the AUR ───────────
  # Packages move between the official repos and the AUR, and third-party repos like
  # [g14] are often not set up (or are down). Rather than fail on "target not found",
  # find out first and send the strays to yay. One `pacman -Slq` covers every package
  # in every configured repo; the per-package `-Si` second pass catches names that are
  # only satisfied virtually, via another package's `provides`.
  repo_list=$(pacman -Slq 2>/dev/null)
  pac_found=""
  pac_strays=""
  for p in $pac_pkgs; do
    if printf '%s\n' "$repo_list" | grep -qxF "$p"; then
      pac_found="$pac_found $p"
    elif pacman -Si "$p" >/dev/null 2>&1; then
      pac_found="$pac_found $p"
    else
      pac_strays="$pac_strays $p"
    fi
  done

  if [[ -n "$pac_strays" ]]; then
    echo "  not in any configured repo, trying the AUR instead:$pac_strays"
    aur_pkgs="$aur_pkgs $pac_strays"
  fi

  # ── Install, batch first and one-at-a-time on failure ───────────────────────────
  # The batch is one transaction and much faster. If it fails we don't know *which*
  # package caused it, so the retry loop installs individually to isolate the damage —
  # 100 packages still get installed when one of them is broken.
  #
  # --needed makes anything already present a no-op, which is what keeps re-runs cheap.
  # Not --noconfirm: package replacements and provider choices on Arch are decisions
  # worth seeing.
  pac_install() { sudo pacman -S --needed "$@"; }
  aur_install() { yay -S --needed "$@"; }

  try_install() {
    local label="$1"; shift
    local installer="$1"; shift
    [[ $# -gt 0 ]] || return 0
    echo "  $label: $# package(s)"
    if "$installer" "$@"; then
      return 0
    fi
    echo "  $label: batch failed — retrying one at a time so the rest still install" >&2
    local p
    for p in "$@"; do
      if ! "$installer" "$p"; then
        failed_pkgs="$failed_pkgs $p"
        echo "  FAILED: $p" >&2
      fi
    done
  }

  # shellcheck disable=SC2086
  try_install pacman pac_install $pac_found

  if [[ -n "${aur_pkgs// /}" ]]; then
    if ! command -v yay >/dev/null 2>&1; then
      echo "  yay not found, building it from the AUR..."
      sudo pacman -S --needed --noconfirm git base-devel
      tmp="$(mktemp -d)"
      if git clone https://aur.archlinux.org/yay.git "$tmp/yay" && (cd "$tmp/yay" && makepkg -si --noconfirm); then
        :
      else
        echo "  could not build yay — skipping all AUR packages" >&2
        failed_pkgs="$failed_pkgs $aur_pkgs"
        aur_pkgs=""
      fi
      rm -rf "$tmp"
    fi
    # shellcheck disable=SC2086
    [[ -n "${aur_pkgs// /}" ]] && try_install aur aur_install $aur_pkgs
  fi

  if [[ -n "$npm_pkgs" ]]; then
    if command -v npm >/dev/null 2>&1; then
      npm_install() { sudo npm install -g "$@"; }
      # shellcheck disable=SC2086
      try_install npm npm_install $npm_pkgs
    else
      echo "  npm not installed — skipping npm packages" >&2
    fi
  fi

  if [[ -n "$cargo_pkgs" ]]; then
    if command -v cargo >/dev/null 2>&1; then
      for p in $cargo_pkgs; do
        cargo install --locked "$p" || { failed_pkgs="$failed_pkgs $p"; echo "  FAILED: $p (cargo)" >&2; }
      done
    else
      echo "  cargo not installed — skipping cargo packages" >&2
    fi
  fi

  set -e
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
  mkdir -p "$HOME/Pictures/screenshots" "$HOME/Wallpaper"
fi

if [[ -n "${failed_pkgs// /}" ]]; then
  echo ""
  echo "bootstrap finished, but these packages did not install:"
  for p in $failed_pkgs; do echo "  - $p"; done
  echo ""
  echo "Your configs are stowed and usable regardless — install the above by hand"
  echo "once you know why each failed (a missing repo, a broken AUR build, a name that"
  echo "moved). Re-running with --no-packages skips straight to stowing next time."
else
  echo "bootstrap complete."
fi
