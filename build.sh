#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
app="$root/build/PortRadar.app"
# Release tags must agree with VERSION; an explicit argument also supports previews.
version="${1:-$(cat "$root/VERSION")}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo "Invalid version: $version" >&2
  exit 1
fi

# Build each slice separately so Command Line Tools are sufficient (SwiftPM's
# multi-architecture build backend requires the full Xcode installation).
# Each slice is copied out as it is built: newer SwiftPM writes every architecture
# to the same products directory.
slices="$(mktemp -d)"
trap 'rm -rf "$slices"' EXIT
binaries=()
for architecture in arm64 x86_64; do
  swift build -c release --product PortRadar --arch "$architecture" --package-path "$root"
  bin_dir="$(swift build -c release --arch "$architecture" --package-path "$root" --show-bin-path)"
  cp "$bin_dir/PortRadar" "$slices/PortRadar-$architecture"
  binaries+=("$slices/PortRadar-$architecture")
done

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/PortRadar"
# Prebuilt so a release build needs no SVG toolchain; see Resources/make-icon.sh.
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"

cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>PortRadar</string>
  <key>CFBundleDisplayName</key>     <string>PortRadar</string>
  <key>CFBundleIdentifier</key>      <string>local.portradar</string>
  <key>CFBundleExecutable</key>      <string>PortRadar</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <!-- LSUIElement hides the Dock icon, but Finder, the DMG, Get Info and any
       app-modal alert still ask for this one. -->
  <key>CFBundleIconFile</key>        <string>AppIcon</string>
  <key>CFBundleIconName</key>        <string>AppIcon</string>
  <key>CFBundleShortVersionString</key> <string>$version</string>
  <key>CFBundleVersion</key>        <string>$version</string>
  <key>LSMinimumSystemVersion</key>  <string>13.0</string>
  <!-- Menu bar only: no Dock icon, no app switcher entry. -->
  <key>LSUIElement</key>             <true/>
</dict>
</plist>
PLIST

# Seal the bundle: the launch-at-login ticket needs a properly signed bundle,
# and an unsealed ad-hoc one is exactly what SMAppService tends to reject.
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"

echo "built: $app"
