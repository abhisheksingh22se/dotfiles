#!/usr/bin/env bash
# Update sketchybar-app-font. Pulls icon_map.json and the .ttf from the SAME release tag so
# the map can never reference glyphs the installed font lacks, and records the tag in VERSION.
#
# Usage: ./update-app-font.sh [tag]    (defaults to the latest release)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dist="$here/../sketchybar-app-font/dist"
repo="kvndrsslr/sketchybar-app-font"

tag="${1:-$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
  | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)}"

[ -n "$tag" ] || { echo "could not resolve a release tag" >&2; exit 1; }
echo "installing sketchybar-app-font $tag"

base="https://github.com/$repo/releases/download/$tag"
mkdir -p "$dist"
curl -fsSL -o "$dist/icon_map.json" "$base/icon_map.json"
curl -fsSL -o "$HOME/Library/Fonts/sketchybar-app-font.ttf" "$base/sketchybar-app-font.ttf"
echo "$tag" > "$dist/VERSION"

sketchybar --reload
echo "done: map and font both at $tag"
