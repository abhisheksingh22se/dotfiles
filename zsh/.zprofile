# ~/.zprofile — login shells.
#
# Homebrew only exists on macOS (and on Linuxbrew, which this setup doesn't use), so
# shellenv is guarded rather than assumed. Without the guard every login shell on Arch
# starts with a "no such file or directory" before the prompt even draws.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Added by Antigravity CLI installer
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="/home/abhishek/.local/bin:$PATH"
