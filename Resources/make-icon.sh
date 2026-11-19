#!/bin/bash
# Regenerates Resources/AppIcon.icns from Resources/AppIcon.svg.
#
# Not run by build.sh: the .icns is committed, so a build needs no SVG renderer.
# Run this by hand when the artwork changes. The SVG uses filters, so it is rendered
# by a Chromium-based browser in headless mode; sips and iconutil ship with macOS.
#   BROWSER=/path/to/browser/binary Resources/make-icon.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/Resources/AppIcon.svg"
out="$root/Resources/AppIcon.icns"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

browser="${BROWSER:-}"
if [[ -z "$browser" ]]; then
  for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Helium.app/Contents/MacOS/Helium" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
    [[ -x "$candidate" ]] && browser="$candidate" && break
  done
fi
[[ -x "$browser" ]] || { echo "need a Chromium-based browser; set BROWSER" >&2; exit 1; }

"$browser" --headless=new --user-data-dir="$work/profile" --disable-gpu --hide-scrollbars \
  --default-background-color=00000000 --force-device-scale-factor=1 --window-size=1024,1024 \
  --screenshot="$work/master.png" "file://$src" >/dev/null 2>&1
[[ -s "$work/master.png" ]] || { echo "rendering failed" >&2; exit 1; }

set="$work/AppIcon.iconset"
mkdir "$set"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$work/master.png" --out "$set/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$work/master.png" --out "$set/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$set" -o "$out"
echo "wrote: $out"
