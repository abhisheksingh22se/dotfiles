# dotfiles — Linux (Arch + Hyprland)

Machine-specific notes for the ROG Zephyrus G14. The shared setup, the branch model and the
cross-machine parity tables live in [`README.md`](README.md) on `main`.

## Packages on this branch

| Package | Target | What it is |
| --- | --- | --- |
| `hypr` | `~/.config/hypr` | Hyprland, hyprlock, hypridle, hyprpaper |
| `ambxst` | `~/.config/ambxst` | desktop shell: bar, dock, notch |
| `rofi` | `~/.config/rofi` | launcher (Raycast's replacement) |
| `mako` | `~/.config/mako` | notification daemon |
| `gtk` | `~/.config/gtk-3.0`, `gtk-4.0`, `qt6ct` | names the icon theme — see below |
| ~~`waybar`~~ | — | **retired**, superseded by Ambxst; files kept, no longer stowed |

Also here and not on `main`: `install_ambxst.sh` and `check-hyprland-config.lua`.

Run `luajit check-hyprland-config.lua --list` to print the full bind map. That script executes
`hyprland.lua` against a stubbed `hl` API, so a typo or a duplicate bind is caught before it
becomes a black screen with no working keys on the actual machine. It also flags config keys
Hyprland has removed or relocated — a dead key isn't fatal, Hyprland logs "unknown config key"
and carries on, which means the setting you wrote is silently doing nothing.

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

