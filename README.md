# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). One flat package per directory,
each mirroring its target path relative to `$HOME`. OS applicability is declared once, as data,
in `bootstrap.sh` — not by branching or nesting packages into OS-named directories. If you're
adding a package or wondering why something is (or isn't) built, that file is the source of
truth.

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

**`aerospace` and `sketchybar` will never run on Linux or Windows.** AeroSpace only exists on
macOS, and SketchyBar talks to macOS's private Mach/CoreFoundation IPC directly
(`sketchybar/.config/sketchybar/src/sketchybar-aerospace-plugin/src/mach.c`) — there is no
portable equivalent to port to, ever. Don't spend time trying to make these two portable; the
goal for them is just not to silently break on the OS they do run on.

### Why not branch-per-device

Files like `wezterm.lua` and git identity should be identical on every machine. A branch per
device makes "is this common?" something you'd have to diff branches to find out, and every
shared edit needs to be cherry-picked across branches or it silently drifts. One branch + the
package table above keeps common-vs-different an explicit, always-current fact in one place.

## Bootstrapping a new machine

**macOS / Linux:**
```
git clone https://github.com/abhisheksingh22se/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./bootstrap.sh
```
Installs `stow` if missing, runs `brew bundle install` from `Brewfile` (macOS only), then stows
every package that applies to the detected OS. Safe to re-run any time.

**Windows:**
```
cd $HOME\.dotfiles
.\bootstrap.ps1
```
Deliberately minimal — this box is a bridge on its way to being replaced by Linux, so it only
symlinks WezTerm and git, not the full package set. Creating symlinks on Windows requires
**Developer Mode** (Settings → Privacy & Security → For developers) or an elevated PowerShell.

## Git credential helper

`git/.gitconfig` ends with `[include] path = ~/.gitconfig.local`. That file is written by each
bootstrap script directly into `$HOME` — never inside the repo, never tracked, never symlinked
— with the one setting that's genuinely per-machine: `osxkeychain` on macOS, `manager` on
Windows. Linux is left unset (no safe universal default — `libsecret` needs a package that may
not be on your distro) until there's a real box to test against; add it with
`git config --global credential.helper <value>` once you know what your distro provides.

## Adding a package

1. Create `<name>/` with the file(s) inside, mirroring their target path under `$HOME`
   (e.g. `<name>/.config/foo/config` → symlinks to `~/.config/foo/config`).
2. Add `<name>` to `ALL_PKGS` in `bootstrap.sh` if it's cross-platform, or to
   `MACOS_ONLY_PKGS` if it isn't — this is also where a future Linux-only array would go once
   there's a Linux WM/bar package to add.
3. `stow -t ~ <name>` (or re-run `bootstrap.sh`).

## What's deliberately not here

`~/.ssh/` is never touched by anything in this repo — no package, no bootstrap step references
it. Secrets don't belong in a synced dotfiles repo; `.gitignore` has a small deny-list
(`.env`, `*.pem`, `id_rsa*`, `.netrc`) as a backstop, not an invitation.
