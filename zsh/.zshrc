# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export JAVA_HOME=$(/usr/libexec/java_home)
export PATH=$JAVA_HOME/bin:$PATH
alias python=python3

# Added by Antigravity
export PATH="/Users/abhishek/.antigravity/antigravity/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/abhishek/.lmstudio/bin"
# End of LM Studio CLI section


# Added by Antigravity IDE
export PATH="/Users/abhishek/.antigravity-ide/antigravity-ide/bin:$PATH"

. "$HOME/.local/bin/env"
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/abhishek/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

# Clean, monotone mo status loop (strips colors and applies Dark Grey ANSI)
alias mostat='while true; do tput cup 0 0; printf "\e[38;5;244m"; mo status | perl -pe "s/\x1b\[[0-9;]*m//g"; printf "\e[0m"; sleep 2; done'
alias ymc="clear && ymc"
export PATH="$HOME/.cargo/bin:$PATH"
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# history setup
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
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---- Eza (better ls) -----

alias ls="eza --icons=always"

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"

alias cd="z"


# Added by Antigravity CLI installer
export PATH="/Users/abhishek/.local/bin:$PATH"

# Added by Antigravity IDE
export PATH="/Users/abhishek/.antigravity-ide/antigravity-ide/bin:$PATH"
