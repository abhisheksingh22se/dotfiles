# ~/.zshrc — shared by macOS and Arch.
#
# The rule here: nothing may hard-code a Homebrew path or a macOS binary at top level.
# Everything OS-specific goes behind `$is_mac` / `$is_linux` or through the small
# `_source_first` helper, which sources the first file that actually exists out of a
# list of candidates. That's what lets one file cover /opt/homebrew (macOS) and
# /usr/share (Arch) without a second copy drifting out of sync.

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" && "$TERM" != "linux" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

case "$OSTYPE" in
  darwin*) is_mac=1; is_linux=0 ;;
  linux*)  is_mac=0; is_linux=1 ;;
  *)       is_mac=0; is_linux=0 ;;
esac

# Source the first candidate that exists; ignore the rest. Silent when none match, so
# a machine that simply doesn't have a plugin installed yet doesn't spew on every
# new shell.
_source_first() {
  local f
  for f in "$@"; do
    if [[ -r "$f" ]]; then
      source "$f"
      return 0
    fi
  done
  return 1
}

# Prepend to PATH only if the directory exists and isn't already there. Keeps PATH from
# growing on every `exec zsh`.
_path_prepend() {
  local d
  for d in "$@"; do
    [[ -d "$d" ]] || continue
    case ":$PATH:" in
      *":$d:"*) ;;
      *) PATH="$d:$PATH" ;;
    esac
  done
  export PATH
}

# ─────────────────────────────────────────────
# Java
# ─────────────────────────────────────────────
# macOS has /usr/libexec/java_home; Arch installs JDKs under /usr/lib/jvm with a
# `default` symlink maintained by archlinux-java.
if (( is_mac )) && [[ -x /usr/libexec/java_home ]]; then
  export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null)"
elif [[ -d /usr/lib/jvm/default ]]; then
  export JAVA_HOME=/usr/lib/jvm/default
fi
[[ -n "${JAVA_HOME:-}" ]] && _path_prepend "$JAVA_HOME/bin"

# ─────────────────────────────────────────────
# PATH
# ─────────────────────────────────────────────
_path_prepend \
  "$HOME/.cargo/bin" \
  "$HOME/.local/bin" \
  "$HOME/.antigravity/antigravity/bin" \
  "$HOME/.antigravity-ide/antigravity-ide/bin" \
  "$HOME/.lmstudio/bin"

if (( is_mac )); then
  _path_prepend "$HOME/Library/Python/3.9/bin"
fi

# uv / rye style env file, if present
[[ -r "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# ─────────────────────────────────────────────
# Completions
# ─────────────────────────────────────────────
[[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit

# ─────────────────────────────────────────────
# Prompt — Powerlevel10k
# ─────────────────────────────────────────────
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [[ "$TERM" == "linux" ]]; then
	PROMPT='[%n@%m]-(%~) %(#.#.$) '
else
	_source_first \
	  /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme \
	  /usr/local/share/powerlevel10k/powerlevel10k.zsh-theme \
	  /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

	[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

# ─────────────────────────────────────────────
# History
# ─────────────────────────────────────────────
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# ─────────────────────────────────────────────
# Plugins
# ─────────────────────────────────────────────
_source_first \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting must be sourced last of the plugins — it wraps the ZLE widgets
# that everything before it defines.
_source_first \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ─────────────────────────────────────────────
# Tools
# ─────────────────────────────────────────────
alias python=python3

# ---- Eza (better ls) -----
command -v eza >/dev/null 2>&1 && alias ls="eza --icons=always"

# ---- Zoxide (better cd) ----
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

# ─────────────────────────────────────────────
# Aliases
# ─────────────────────────────────────────────
alias ymc="clear && ymc"

if (( is_mac )); then
  # Clean, monotone mo status loop (strips colors and applies Dark Grey ANSI).
  # `mo` is macOS-only (Homebrew `mole`), so the alias is too.
  alias mostat='while true; do tput cup 0 0; printf "\e[38;5;244m"; mo status | perl -pe "s/\x1b\[[0-9;]*m//g"; printf "\e[0m"; sleep 2; done'
fi

if (( is_linux )); then
  # ── Starting the desktop ──
  # There is no display manager on this box; Hyprland is launched by name from the
  # TTY. These two aliases are the whole session picker.
  #
  # hyprland.lua branches on AMBXST_SESSION exactly once, near the top: it decides
  # whether `ambxst` is started, whether ~/.local/share/ambxst/hyprland.lua is
  # loaded, and whether this file or Ambxst's compositor.json owns rounding, gaps,
  # borders, shadow and blur. Bare `hypr` has no bar at all — waybar was retired
  # when Ambxst took over, so the fallback session is deliberately a clean screen.
  alias hypr='Hyprland'
  alias hypr-ambxst='AMBXST_SESSION=1 Hyprland'

  # Hyprland/Wayland conveniences. `hypr-reload` is the equivalent of AeroSpace's
  # `alt-shift-semicolon esc` service-mode reload, from a shell.
  #
  # Ambxst reloads itself when its JSON changes, so there is nothing to signal for
  # the bar the way `pkill -SIGUSR2 waybar` used to do.
  alias hypr-reload='hyprctl reload && makoctl reload'
  alias hypr-log='tail -f "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log"'
  alias ambxst-restart='pkill -f ambxst; (ambxst &) >/dev/null 2>&1'
  alias gpu='supergfxctl -g'
  alias gpu-int='supergfxctl -m Integrated'
  alias gpu-hyb='supergfxctl -m Hybrid'
  alias battery='cat /sys/class/power_supply/BAT0/capacity'
  # pbcopy/pbpaste muscle memory, backed by wl-clipboard.
  command -v wl-copy  >/dev/null 2>&1 && alias pbcopy='wl-copy'
  command -v wl-paste >/dev/null 2>&1 && alias pbpaste='wl-paste'
  alias open='xdg-open'
fi

unset -f _source_first _path_prepend
unset is_mac is_linux


# Added by Antigravity CLI installer
export PATH="/home/abhishek/.local/bin:$PATH"
