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
| `ambxst` | `~/.config/ambxst` | **Linux only** | desktop shell: bar, dock, notch |
| ~~`waybar`~~ | — | **retired** | superseded by Ambxst; files kept, no longer stowed |
| `rofi` | `~/.config/rofi` | **Linux only** | launcher (Raycast's replacement) |
| `mako` | `~/.config/mako` | **Linux only** | notification daemon |
| `gtk` | `~/.config/gtk-3.0`, `gtk-4.0`, `qt6ct` | **Linux only** | names the icon theme — see below |

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
| Status bar | SketchyBar | Ambxst bar | `ambxst/.config/ambxst/presets/Frost Glass/theme.json` |
| Dynamic island | (the notch itself) | Ambxst notch | `ambxst/.config/ambxst/config/notch.json` |
| Workspace + app icons | Rust plugin (`sbar-aerobar-plugin`) | Ambxst `workspaces.showAppIcons` | nothing to compile on Linux |
| Now playing | `wnp-daemon/media_daemon.py` | Ambxst notch (MPRIS) | Linux has MPRIS; the daemon existed only because macOS doesn't |
| Window borders | `borders` (FelixKratz) | Ambxst `compositor.json` | role names, not hex — see the Ambxst section |
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
becomes a black screen with no working keys on the actual machine. It also flags config keys
Hyprland has removed or relocated — a dead key isn't fatal, Hyprland logs "unknown config key"
and carries on, which means the setting you wrote is silently doing nothing. `DEAD_KEYS` at the
top of the script is the list; add to it whenever an upstream release drops one.

On the machine itself, `hyprctl configerrors` is the authority — the checker can prove the file
is structurally sound but not that this build accepts every option name.

## Ambxst and the Frost Glass preset

[Ambxst](https://github.com/Axenide/Ambxst) is the desktop shell on Linux — bar, dock, and the
notch that stands in for the MacBook's dynamic island. It is a Quickshell config, not a distro
package:

```
curl -L get.axeni.de/ambxst | sh
ambxst install hyprland
```

### How it is put together

A **preset** is a directory of JSON under `~/.config/ambxst/presets/<Name>/`, plus an
`info.json` holding `author` / `authorUrl`. `presets/active_preset` is a plain text file naming
the live one. Ambxst's `PresetsService` excludes `system.json`, `ai.json`, `prefix.json` and
`weather.json` from presets, which is why `config/system.json` here has no counterpart under
`presets/Frost Glass/`.

**Colours are a separate axis.** Presets never contain hex. `theme.json` refers to Material-3
role names (`background`, `surfaceBright`, `primary`, `overBackground`, `shadow`), and Ambxst
resolves them against whatever palette is active — by default one quantised from the wallpaper.
Transparency is not in the palette either; it comes from each surface role's `opacity`.

That split is the thing to internalise before editing: **geometry and alpha live in the preset,
hue lives in the palette.** Frost Glass is written so the Mac look survives a palette change —
the glass is defined by alpha over `background`, not by a particular grey.

### Where the Mac values went

`sketchybar/.config/sketchybar/sketchybarrc` is still the reference. The mapping:

| sketchybar | Frost Glass |
| --- | --- |
| `bar color=0x00000000` | `theme.json` `srBarBg.opacity: 0` |
| bracket `background.color=0x25000000` | `srBg.opacity` — see the caveat below; **not** reproduced exactly |
| bracket `background.border_color=0x20ffffff` | `srBg.border: ["surfaceBright", 1]` |
| bracket `background.corner_radius=10` | `roundness: 10` |
| `label.font "SF Pro:Semibold:13"` | `font: "Inter"`, `fontSize: 13` |
| `icon.font "Hack Nerd Font:Bold:14"` | `monoFont: "Hack Nerd Font Mono"` |
| `borders active_color=0x88ffffff` | `compositor.json` `activeBorderColor: ["outline", "primary"]` |
| `borders inactive_color=0x20ffffff` | `inactiveBorderColor: ["surfaceBright"]` |

Two places where an exact match is not reachable, both forced by Ambxst rather than chosen:

* **Border colours must be palette role names.** `CompositorConfig` resolves every entry through
  the palette and does not accept raw hex, so jankyborders' literal `0x88ffffff` cannot be
  written down. `outline` is the M3 role that lands where white-at-53% lands over a dark
  desktop, and `primary` supplies the mint second stop the old `hyprland.lua` gradient had.
* **Inactive borders are forced fully opaque.** `CompositorConfig` rebuilds them with
  `Qt.rgba(..., 1.0)` regardless of input, so `0x20ffffff` — white at 12.5% — is not
  expressible at all. A dark role approximates what that alpha looked like over the wallpaper.

### One role, three jobs

The bar's capsules and the notch are **the same surface role**. `Notch.qml` draws with
`StyledRect variant: "bg"` (collapsed and expanded, in both notch themes, with its border from
`Config.theme.srBg.border`), and so do the bar widgets — `ControlsButton.qml` uses
`variant: root.popupOpen ? "primary" : "bg"`, `BarContent.qml`'s pin button the same. Every one
of them resolves to `srBg`.

That has a consequence worth stating plainly, because it is the first thing anyone will try to
change: **the notch cannot be tinted differently from the bar.** `notch.json` exposes only
`theme`, `position`, `customText` and the hover keys — no colour of its own. Darkening the notch
darkens the bar capsules by exactly the same amount.

Separation therefore comes from **shape**, which is why `notch.json` sets `theme: "island"`.
`Notch.qml` draws the `default` theme as `notchFullBackground` — full height, corner-masked,
hanging off the top edge in imitation of a hardware cutout. `island` draws `notchIslandBg`
instead: a detached pill that renders its own border. Against a bar whose background strip is
fully transparent, a floating bordered pill reads as a separate object even at identical
opacity.

That border is why `srBg.border` is `["surfaceBright", 1]` and not zero width — under the
island theme a pill with no edge is a floating smudge. It doubles as sketchybar's
`background.border_width=1` / `border_color=0x20ffffff` hairline on the bar capsules, which an
earlier version of this file had wrongly placed on `srCommon`.

So one number serves three jobs with conflicting needs:

| Wants | Value it wants |
| --- | --- |
| Bar capsules matching sketchybar's `0x25000000` | `0.145` |
| Collapsed notch having any presence | mid |
| Expanded notch readable over a *bright* window | `0.68`+ |

`srBg` is set to **`0.45`** — a deliberate middle, not a match for any of them. At `0.145` the
expanded notch puts near-white `overBackground` text on a light wash of whatever is behind it
and disappears; blur softens a backdrop, it does not darken one. At `0.68` the bar reads far
heavier than the Mac's menu bar. `0.45` is the compromise; if the notch is hard to read on white
backgrounds, raise it, and accept a heavier bar as the price.

What keeps that workable is the surfaces *inside* it. `srInternalBg`, `srPane` and `srPopup`
stay at `0.68`, so expanded content and popups still land on a dark enough ground even with
`srBg` down at `0.45`.

`srCommon` is `0.45` as well. An earlier version of this file claimed it carried sketchybar's
capsule alpha; that was wrong — the capsules are `srBg`, and where "Common" is actually consumed
is not clear from the source. It is aligned with `srBg` so nothing ends up accidentally
invisible.

One more consequence, this one about blur. Hyprland's `ignorealpha X` means "do not blur pixels
whose alpha is below X". Ambxst emits `layerrule ignorealpha <v>,quickshell`, and with
`blurExplicitIgnoreAlpha: false` it derives `v` from `min(bar opacity, background opacity)` —
which for Frost Glass is `0.00`, because `srBarBg` is deliberately invisible. Nothing would ever
be ignored, so the empty strip where the bar lives would blur anyway: a visible blurred band
across the top of the screen with nothing drawn in it. `compositor.json` therefore pins
`blurExplicitIgnoreAlpha: true` and `blurIgnoreAlphaValue: 0.10`.

Blur on Ambxst's own surfaces needs nothing from `hyprland.lua`: `CompositorConfig` emits
`layerrule noanim,quickshell ; blur,quickshell ; blurpopups,quickshell ; ignorealpha …` at
runtime, unconditionally. The `hl.layer_rule` block in `hyprland.lua` covers rofi, mako and
swayosd, which Ambxst knows nothing about.

### Who owns window decoration

Ambxst applies `hyprctl keyword` at runtime for `general:{border_size, gaps_in, gaps_out,
col.active_border, col.inactive_border, layout}`, `decoration:rounding`, and the whole
`decoration:shadow:*` and `decoration:blur:*` trees. Those are live keywords issued after the
config is parsed, so **Ambxst wins whatever `hyprland.lua` sets.**

`hyprland.lua` therefore only sets them in the bare session, inside `if not ambxst_session`.
It keeps `rounding_power` and the opacity pair unconditionally, because Ambxst emits neither.

### The icon theme is not optional

`gtk/` exists for one reason: something has to *name* an icon theme. Installing
`papirus-icon-theme` only puts files in `/usr/share/icons` — it does not make anything use
them. With no theme named, every XDG lookup falls through to `hicolor`, which ships almost
nothing, and Ambxst's workspace indicators come up blank: `Workspaces.qml` resolves them with
`DesktopEntries.heuristicLookup(class)` → `Quickshell.iconPath(icon, "image-missing")`, and on
a bare install even `image-missing` is unresolvable.

Three places have to agree, because three different lookups happen:

| Consumer | Reads |
| --- | --- |
| GTK apps | `gtk/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini` |
| Qt apps | `gtk/.config/qt6ct/qt6ct.conf` (`QT_QPA_PLATFORMTHEME=qt6ct` is set in `hyprland.lua`) |
| Quickshell / Ambxst | the appearance portal, i.e. `gsettings` — written at startup in `hyprland.lua` |

Check with `gsettings get org.gnome.desktop.interface icon-theme`. If icons are missing for a
few specific apps only, that is the other half of the lookup: `heuristicLookup` needs a
matching `.desktop` file, which some Wayland-native apps do not install under their app-id.

### Idle and lock: exactly one stack per session

`hypr/.config/hypr/hypridle.conf` and `ambxst/.config/ambxst/config/system.json` describe the
same ladder — 150s dim, 300s lock, 330s screen off, 1800s suspend — through two different
daemons. hypridle locks with hyprlock; Ambxst locks with its own `LockScreen.qml` via
`ambxst lock`. Running both arms every timer twice, and at 300s both call
`loginctl lock-session`, racing two lockers for one session.

`hyprland.lua` therefore starts hypridle only in the bare session. The one capability lost
under Ambxst is hypridle's G14 keyboard-backlight listener, which `system.json` has no
equivalent for.

**Ambxst's lockscreen needs no preset.** Its entire config is `{"position": "bottom"}` —
everything else about its appearance comes from `theme.json`'s surface roles, so Frost Glass
themes it automatically. `hyprlock.conf` is written in the same vocabulary and stays as the
bare session's locker.

### Weather and AI

Neither is part of a preset: `PresetsService` excludes `ai.json`, `weather.json`,
`prefix.json` and `system.json` because they hold user or secret data.

* **Weather** needs no API key, only `config/weather.js`'s `location` — empty by default,
  which is why it renders nothing until set.
* **AI** defaults to `gemini-2.0-flash`, so it wants a Google AI Studio key held by Ambxst's
  `KeyStore`. `.gitignore` denies `ai.json` as a backstop; check where KeyStore writes before
  committing anything after you add a key.

### Starting a session

There is no display manager; Hyprland is launched by name from the TTY.

| Command | What you get |
| --- | --- |
| `hypr` | bare Hyprland. No bar, no dock. The fallback when an Ambxst update breaks something. |
| `hypr-ambxst` | Hyprland + Ambxst: bar, dock, notch, and Ambxst-owned window decoration. |

Both are aliases in `zsh/.zshrc`; the only difference is `AMBXST_SESSION=1`. `hyprland.lua`
branches on it once, near the top.

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

Wallpapers aren't here either. `hyprpaper.conf` points at `~/Wallpaper/current.png`, and
`bootstrap.sh` creates `~/Wallpaper` but does not populate it — binaries don't belong in a
config repo, and the file is one `cp` away. If you pick wallpapers through waypaper, point it
at the same folder; it rewrites `hyprpaper.conf` on every pick.
