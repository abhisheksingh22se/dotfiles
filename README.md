# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). One flat package per directory,
each mirroring its target path relative to `$HOME`.

Two machines: a Mac (AeroSpace + SketchyBar) and a ROG Zephyrus G14 running Arch + Hyprland.
They are deliberately the *same* setup rendered twice, not two setups — see
[Same workflow, two OSes](#same-workflow-two-oses).

## Branch layout

**This branch (`main`) is the shared base. It is not a machine.** It holds only the config that
is byte-for-byte identical on every box. Each machine gets its own branch that adds its own
desktop on top:

```
                    main  (shared base -- no OS-specific config)
                      |
                      |-- zsh/  git/  p10k/  wezterm/  yt-dlp/
                      |-- bootstrap.sh  bootstrap.ps1  README.md
                      |-- .gitignore  .gitattributes  .stow-local-ignore
                      |
        +-------------+-------------+
        |                           |
       mac                        linux
   + aerospace/                + hypr/  ambxst/  rofi/
   + sketchybar/               + mako/  gtk/  waybar/ (retired)
                               + install_ambxst.sh
                               + check-hyprland-config.lua
                               + README-linux.md
```

Each machine clones once and **stays on its own branch permanently.** The Mac never sits on
`linux`, the G14 never sits on `mac`.

### The two rules

**1. Shared config is edited on `main`, then merged outward.**

```sh
git switch main  && $EDITOR zsh/.zshrc && git commit -am "zsh: ..."
git switch mac   && git merge main
git switch linux && git merge main
```

Merges are **always** `main` → machine, never the reverse. `main` only ever touches files the
machine branches don't have, so these merges are clean every time — nothing to cherry-pick.

**2. Machine config is edited on its own branch and never merges back.**

```sh
git switch linux && $EDITOR hypr/.config/hypr/hyprland.lua && git commit -am "hypr: ..."
```

That commit lives on `linux` forever. This is what keeps `main` free of anything OS-specific.

The failure mode to watch for is editing a *shared* file while sitting on `mac` or `linux` —
the change is then invisible to the other machine and to `main`. There is no hook enforcing
this; the rule is: **if the package is in `ALL_PKGS`, edit it on `main`.**

### Why branches and not one tree

The alternative is a single branch carrying every machine's config, with `bootstrap.sh` picking
what to stow. That works, and it is what this repo did originally. Branches trade a merge step
for checkouts that contain only what the machine in front of you actually runs — no Hyprland
config on the Mac to wonder about, no chance of "fixing" a file that box never loads.

## Packages

Everything on `main`, and therefore on every machine:

| Package | Target | What it is |
| --- | --- | --- |
| `zsh` | `~/.zshrc`, `~/.zprofile`, `~/.profile` | shell config |
| `p10k` | `~/.p10k.zsh` | Powerlevel10k prompt theme |
| `git` | `~/.gitconfig`, `~/.gitignore_global` | identity + global ignores |
| `wezterm` | `~/.config/wezterm` | terminal (genuinely cross-platform) |
| `yt-dlp` | `~/.config/yt-dlp` | downloader config |

Machine-specific packages live on the machine branches: `aerospace` and `sketchybar` on `mac`;
`hypr`, `ambxst`, `rofi`, `mako` and `gtk` on `linux` (see `README-linux.md` there).

**`aerospace` and `sketchybar` will never run on Linux.** AeroSpace only exists on macOS, and
SketchyBar talks to macOS's private Mach/CoreFoundation IPC directly — there is no portable
equivalent to port to, ever. The Linux packages are not ports of that code; they are
independent configs that reproduce the same *behaviour and appearance* from scratch. Keeping
them looking alike is manual work, so the values that matter are cross-referenced in comments
on both sides.

### Shared files that still differ by OS

A file on `main` is stowed on every machine, so anything OS-specific inside it branches at
*runtime*, not in git:

- `zsh/.zshrc` sets `is_mac` / `is_linux` near the top and guards each block with
  `if (( is_mac ))` / `if (( is_linux ))`.
- `wezterm/.config/wezterm/wezterm.lua` derives `is_macos` / `is_linux` from
  `wezterm.target_triple` and branches on those — the external-monitor font fix and
  `window_decorations` are both handled this way.

That is the correct place for an OS difference in a shared package. Forking the file onto a
machine branch is not.

## Same workflow, two OSes

| Concern | macOS | Arch / Hyprland |
| --- | --- | --- |
| Window manager | AeroSpace | Hyprland |
| Keybindings | `aerospace.toml`, `alt` modifier | same map, `ALT` modifier |
| Status bar | SketchyBar | Ambxst bar |
| Dynamic island | (the notch itself) | Ambxst notch |
| Workspace + app icons | Rust plugin (`sbar-aerobar-plugin`) | Ambxst `workspaces.showAppIcons` |
| Now playing | `wnp-daemon/media_daemon.py` | Ambxst notch (MPRIS) |
| Window borders | `borders` (FelixKratz) | Ambxst `compositor.json` |
| Launcher | Raycast | rofi-wayland |
| Clipboard history | Raycast | `cliphist` + rofi (`SUPER+V`) |
| Swipe between spaces | SwipeAeroSpace | `hl.gesture()`, built into Hyprland |
| Terminal blur | `macos_window_background_blur` | Hyprland `decoration.blur` |
| Notifications | Notification Center | mako |
| Screen lock | macOS | hyprlock |
| Display sleep / idle | Energy Saver | hypridle |
| Display scaling | Retina, automatic | explicit per-panel `PANEL_SCALE` |

### Keybindings

`hyprland.lua` on the `linux` branch is a direct port of `aerospace.toml` on `mac`, not a fresh
Hyprland config, so the muscle memory transfers with no relearning:

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

Because this table spans both machines it lives here on `main`, even though neither file it
describes does.

## Bootstrapping a new machine

Clone, check out **that machine's branch**, then bootstrap:

```sh
git clone https://github.com/abhisheksingh22se/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
git switch mac        # or: git switch linux
./bootstrap.sh
```

Installs `stow` if missing, then stows every package present on this branch. Safe to re-run any
time — `stow -R` is a restow, so it repairs links rather than duplicating them.

```sh
./bootstrap.sh --no-packages     # skip the package pass, just re-link the configs
```

Bootstrapping straight from `main` is legal and gives you a working shell, prompt, git and
terminal with no desktop. That is genuinely useful on a server or a container.

**The package table in `bootstrap.sh` lists every package across both machines**, not just this
branch's. That is deliberate: the file is identical on all three branches, which is what stops
it conflicting on every merge. Each stow loop skips packages whose directory isn't checked out,
so `main` stows five packages, `mac` seven, `linux` ten, from one unmodified script.

**A package that won't install never stops the run.** The stow step is what actually makes a
machine usable, and the first version of this script lost it to a single `target not found`
because `set -e` took the whole thing down mid-`pacman`. Installs run as one batch for speed,
retry package-by-package if the batch fails, and collect failures into a list printed at the
end.

> **Note:** `Brewfile` and `Archfile` are currently not tracked. Both package phases are guarded
> on the manifest existing, so they no-op and the run goes straight to stowing. Drop either file
> back at the repo root and its phase starts working again with no other change.

**Windows:**
```
cd $HOME\.dotfiles
.\bootstrap.ps1
```
Deliberately minimal — this box is a bridge on its way to being replaced by Linux, so it only
symlinks WezTerm and git, not the full package set. It has no branch of its own for that reason;
run it from `main`. Creating symlinks on Windows requires **Developer Mode** (Settings → Privacy
& Security → For developers) or an elevated PowerShell.

### Switching branches on a live machine

Stow links point *into* this repo, so checking out a branch that lacks a package leaves the
symlinks in `$HOME` dangling — `~/.config/hypr` still pointing at a path that no longer exists.
Harmless while each machine stays on its own branch, and `./bootstrap.sh` cleans it up on the
next run. Don't branch-hop casually on a machine you're actually using.

## Git credential helper

`git/.gitconfig` ends with `[include] path = ~/.gitconfig.local`. That file is written by each
bootstrap script directly into `$HOME` — never inside the repo, never tracked, never symlinked
— with the one setting that's genuinely per-machine: `osxkeychain` on macOS, `manager` on
Windows, `libsecret` on Linux *if* the helper has actually been built (Arch ships its source,
not a binary — `sudo make -C /usr/share/git/credential/libsecret`). Left unset otherwise rather
than guessed.

This is the escape hatch for anything genuinely per-machine that isn't per-OS. Prefer it, and
untracked `*.local` files generally, over forking a shared file onto a machine branch.

## Adding a package

1. Decide where it belongs. Identical everywhere → `main`. Otherwise → `mac` or `linux`.
2. Create `<name>/` with the file(s) inside, mirroring their target path under `$HOME`
   (e.g. `<name>/.config/foo/config` → symlinks to `~/.config/foo/config`).
3. Add `<name>` to the right array in `bootstrap.sh` — `ALL_PKGS`, `MACOS_ONLY_PKGS` or
   `LINUX_ONLY_PKGS`. **Make that edit on `main` and merge it out**, even for a package that
   only exists on one machine: the table is shared, and the `-d` guard means naming a package
   that isn't on this branch is a no-op, not an error.
4. `stow -t ~ <name>` (or re-run `bootstrap.sh`).

## What's deliberately not here

`~/.ssh/` is never touched by anything in this repo — no package, no bootstrap step references
it. Secrets don't belong in a synced dotfiles repo; `.gitignore` has a small deny-list
(`.env`, `*.pem`, `id_rsa*`, `.netrc`, and Ambxst's `ai.json` API key) as a backstop, not an
invitation. That deny-list lives on `main` so every branch inherits it.

Wallpapers aren't here either. `hyprpaper.conf` points at `~/Wallpaper/current.png`, and
`bootstrap.sh` creates `~/Wallpaper` but does not populate it — binaries don't belong in a
config repo, and the file is one `cp` away.
