# Minimal Windows bootstrap — this box is a bridge being phased out for Linux, so this
# deliberately does NOT stand up GNU Stow on Windows. It just symlinks the two files that
# are genuinely cross-platform: WezTerm and git identity.
#
# Requires Developer Mode (Settings > Privacy & Security > For developers) or an elevated
# PowerShell — creating symlinks on Windows needs one of the two.

$dotfiles = "$HOME\.dotfiles"

New-Item -ItemType SymbolicLink -Force `
  -Path "$env:USERPROFILE\.wezterm.lua" `
  -Target "$dotfiles\wezterm\.config\wezterm\wezterm.lua"

New-Item -ItemType SymbolicLink -Force `
  -Path "$env:USERPROFILE\.gitconfig" `
  -Target "$dotfiles\git\.gitconfig"

# Machine-specific credential helper, never tracked in the repo — same pattern as
# bootstrap.sh's ~/.gitconfig.local, read via git/.gitconfig's [include] directive.
$localGitconfig = "$env:USERPROFILE\.gitconfig.local"
if (-not (Test-Path $localGitconfig)) {
  "[credential]`n`thelper = manager" | Set-Content $localGitconfig
}

Write-Host "bootstrap complete: wezterm + git linked, gitconfig.local written."
