# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). One flat package per directory,
each mirroring its target path relative to `$HOME`. OS applicability is declared once, as data,
in `bootstrap.sh` — not by branching or nesting packages into OS-named directories. If you're
adding a package or wondering why something is (or isn't) built, that file is the source of
truth.

Two machines: a Mac (AeroSpace + SketchyBar) and a ROG Zephyrus G14 running Arch + Hyprland.
They are deliberately the *same* setup rendered twice, not two setups — see
[Same workflow, two OSes](#same-workflow-two-oses).

## Packages

| Package | Target | OS | What it is |
| --- | --- | --- | --- |
| `zsh` | `~/.zshrc`, `~/.zprofile`, `~/.profile` | all | shell config |
| `p10k` | `~/.p10k.zsh` | all | Powerlevel10k prompt theme |
| `git` | `~/.gitconfig`, `~/.gitignore_global` | all | identity + global ignores |
| `wezterm` | `~/.config/wezterm` | all | terminal (genuinely cross-platform) |
| `yt-dlp` | `~/.config/yt-dlp` | all | downloader config |
| `aerospace` | `~/.config/aerospace` | **macOS only** | tiling window manager |
| `sketchybar` | `~/.config/sketchybar` | **macOS only** | status bar |
| `hypr` | `~/.config/hypr` | **Linux only** | Hyprland, hyprlock, hypridle, hyprpaper |
| `waybar` | `~/.config/waybar` | **Linux only** | status bar |
| `rofi` | `~/.config/rofi` | **Linux only** | launcher (Raycast's replacement) |
| `mako` | `~/.config/mako` | **Linux only** | notification daemon |

**`aerospace` and `sketchybar` will never run on Linux or Windows.** AeroSpace only exists on
macOS, and SketchyBar talks to macOS's private Mach/CoreFoundation IPC directly
(`sketchybar/.config/sketchybar/src/sketchybar-aerospace-plugin/src/mach.c`) — there is no
portable equivalent to port to, ever. The Linux packages are not ports of that code; they are
independent configs that reproduce the same *behaviour and appearance* from scratch. Keeping
them looking alike is manual work, so the values that matter are cross-referenced in comments
on both sides.

### Why not branch-per-device

Files like `wezterm.lua` and git identity should be identical on every machine. A branch per
device makes "is this common?" something you'd have to diff branches to find out, and every
shared edit needs to be cherry-picked across branches or it silently drifts. One branch + the
package table above keeps common-vs-different an explicit, always-current fact in one place.

## Same workflow, two OSes

| Concern | macOS | Arch / Hyprland | Where the parity lives |
| --- | --- | --- | --- |
| Window manager | AeroSpace | Hyprland | `hypr/.config/hypr/hyprland.lua` |
| Keybindings | `aerospace.toml`, `alt` modifier | same map, `ALT` modifier | ported one-for-one, see below |
| Status bar | SketchyBar | Waybar | `waybar/.config/waybar/style.css` copies the exact colours |
| Workspace + app icons | Rust plugin (`sbar-aerobar-plugin`) | Waybar `window-rewrite` | nothing to compile on Linux |
| Now playing | `wnp-daemon/media_daemon.py` | Waybar `mpris` module | Linux has MPRIS; the daemon existed only because macOS doesn't |
| Window borders | `borders` (FelixKratz) | Hyprland `general.col` | same `0x88ffffff` / `0x20ffffff` |
| Launcher | Raycast | rofi-wayland | `rofi/.config/rofi/glass.rasi` |
| Clipboard history | Raycast | `cliphist` + rofi | `SUPER+V` |
| Swipe between spaces | SwipeAeroSpace | `hl.gesture()` | built into Hyprland |
| Terminal blur | `macos_window_background_blur` | Hyprland `decoration.blur` | WezTerm renders translucent on both; the compositor differs |
| Notifications | Notification Center | mako | `mako/.config/mako/config` |
| Screen lock | macOS | hyprlock | `hypr/.config/hypr/hyprlock.conf` |
| Display sleep / idle | Energy Saver | hypridle | `hypr/.config/hypr/hypridle.conf` — Hyprland has no idle timer of its own |
| Display scaling | Retina, automatic | explicit per-panel scale | `PANEL_SCALE` at the top of `hyprland.lua`; see `upc-plans/linux-setup.md` §12 |
| Packages | `Brewfile` | `Archfile` | every Brewfile line is ported or explained |

### Keybindings

`hyprland.lua` is a direct port of `aerospace.toml`, not a fresh Hyprland config, so the
muscle memory transfers with no relearning:

| | AeroSpace | Hyprland |
| --- | --- | --- |
| Focus | `alt-h/j/k/l` | `ALT+h/j/k/l` |
| Move window | `alt-shift-h/j/k/l` | `ALT+SHIFT+h/j/k/l` |
| Workspaces 1–9 | `alt-1..9` / `alt-shift-1..9` | identical |
| Lettered workspaces | `alt-a..z` | identical (Hyprland *named* workspaces, `name:A`) |
| Resize | `alt-minus` / `alt-equal` | identical |
| Split / stack / float | `alt-slash` / `alt-comma` / `alt-shift-f` | `togglesplit` / group toggle / `togglefloating` |
| Last workspace | `alt-tab` | identical |
| Workspace → next monitor | `alt-shift-tab` | identical |
| Service mode | `alt-shift-semicolon` | identical (a Hyprland submap) |

`SUPER` is unbound in AeroSpace — macOS handled launching with `CMD` and Raycast. On Linux it
takes that role: `SUPER+return` terminal, `SUPER+space` launcher, `SUPER+V` clipboard,
`SUPER+L` lock, `SUPER+SHIFT+3/4/5` screenshots (the macOS numbers, deliberately).

Run `luajit check-hyprland-config.lua --list` to print the full bind map. That script executes
`hyprland.lua` against a stubbed `hl` API, so a typo or a duplicate bind is caught before it
becomes a black screen with no working keys on the actual machine.

## Bootstrapping a new machine

**macOS / Linux:**
```
git clone https://github.com/abhisheksingh22se/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./bootstrap.sh
```
Installs `stow` if missing, installs packages (`brew bundle` from `Brewfile` on macOS,
`pacman`/`yay` from `Archfile` on Arch), then stows every package that applies to the detected
OS. Safe to re-run any time.

```
./bootstrap.sh --no-packages     # skip the package pass, just re-link the configs
```

**A package that won't install never stops the run.** That matters more than it sounds: the
stow step is what actually makes a machine usable, and the first version of this script lost it
to a single `target not found` because `set -e` took the whole thing down mid-`pacman`. Now:

- Anything in the `Archfile` as `pac` that isn't in a configured repo is **automatically routed
  to the AUR** rather than failing. This is what happens to `asusctl` / `supergfxctl` when the
  asus-linux `[g14]` repo isn't set up or is down — you no longer need that repo at all.
- Installs run as one batch for speed, then **retry package-by-package** if the batch fails, so
  one broken build doesn't take the other hundred with it.
- Failures are collected and printed as a list at the end, after everything else has completed.

**Windows:**
```
cd $HOME\.dotfiles
.\bootstrap.ps1
```
Deliberately minimal — this box is a bridge on its way to being replaced by Linux, so it only
symlinks WezTerm and git, not the full package set. Creating symlinks on Windows requires
**Developer Mode** (Settings → Privacy & Security → For developers) or an elevated PowerShell.

## Package manifests

`Brewfile` and `Archfile` are peers. The `Archfile` uses the same one-line-per-package shape
with a source prefix (`pac` / `aur` / `npm` / `cargo`), and ends with a **Deliberately not
ported** section listing every Brewfile entry that has no Linux counterpart and why. When you
add something to one, decide its fate in the other in the same commit — that section is what
stops the two drifting into "which machine has what?" archaeology.

## Git credential helper

`git/.gitconfig` ends with `[include] path = ~/.gitconfig.local`. That file is written by each
bootstrap script directly into `$HOME` — never inside the repo, never tracked, never symlinked
— with the one setting that's genuinely per-machine: `osxkeychain` on macOS, `manager` on
Windows, `libsecret` on Linux *if* the helper has actually been built (Arch ships its source,
not a binary — `sudo make -C /usr/share/git/credential/libsecret`). Left unset otherwise rather
than guessed.

## Adding a package

1. Create `<name>/` with the file(s) inside, mirroring their target path under `$HOME`
   (e.g. `<name>/.config/foo/config` → symlinks to `~/.config/foo/config`).
2. Add `<name>` to `ALL_PKGS` in `bootstrap.sh` if it's cross-platform, or to
   `MACOS_ONLY_PKGS` / `LINUX_ONLY_PKGS` if it isn't.
3. `stow -t ~ <name>` (or re-run `bootstrap.sh`).

## What's deliberately not here

`~/.ssh/` is never touched by anything in this repo — no package, no bootstrap step references
it. Secrets don't belong in a synced dotfiles repo; `.gitignore` has a small deny-list
(`.env`, `*.pem`, `id_rsa*`, `.netrc`) as a backstop, not an invitation.

Wallpapers aren't here either. `hyprpaper.conf` points at `~/Pictures/wallpapers/current.png`,
which `bootstrap.sh` creates the directory for but does not populate — binaries don't belong in
a config repo, and the file is one `cp` away.
