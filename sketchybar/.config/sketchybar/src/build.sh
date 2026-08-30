#!/usr/bin/env bash
# Rebuild the AeroSpace workspace plugin and install it into plugins/.
set -euo pipefail

if [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:$PATH"
else
  export PATH="/usr/local/bin:$PATH"
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
crate="$here/sketchybar-aerospace-plugin"

cargo build --release --manifest-path "$crate/Cargo.toml"
cp "$crate/target/release/sbar-aerobar-plugin" "$here/../plugins/aerospace_plugin"

sketchybar --reload
echo "installed: $(cd "$here/.." && pwd)/plugins/aerospace_plugin"
