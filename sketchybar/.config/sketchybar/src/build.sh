#!/usr/bin/env bash
# Rebuild the AeroSpace workspace plugin and install it into plugins/.
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
crate="$here/sketchybar-aerospace-plugin"

cargo build --release --manifest-path "$crate/Cargo.toml"
cp "$crate/target/release/sbar-aerobar-plugin" "$here/../plugins/aerospace_plugin"

sketchybar --reload
echo "installed: $(cd "$here/.." && pwd)/plugins/aerospace_plugin"
