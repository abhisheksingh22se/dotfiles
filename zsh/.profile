# ~/.profile — POSIX login shells (and anything that reads it before zsh takes over).
# Kept minimal and guarded; the real configuration lives in ~/.zshrc.

[ -r "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Added by Antigravity CLI installer
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="/home/abhishek/.local/bin:$PATH"
