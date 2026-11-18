#!/bin/zsh
# Build Heeler for a device and install it (set DEVELOPMENT_TEAM in project.yml first).
set -o pipefail
cd "${0:A:h}/.."
DEV=${1:?usage: install-ipad.sh <device-id>}   # xcrun devicectl list devices
echo "== xcodegen"; xcodegen generate -q || exit 10
echo "== build (Debug, device $DEV)"
xcodebuild -project Heeler.xcodeproj -scheme Heeler -configuration Debug \
  -destination "id=$DEV" -derivedDataPath build/dd -allowProvisioningUpdates \
  -skipPackagePluginValidation -skipMacroValidation build 2>&1 \
  | grep -E '(error:|warning: .*provision|\*\* BUILD|Signing Identity|Provisioning Profile)' | tail -25
[ ${pipestatus[1]} -eq 0 ] || exit 20
APP=$(ls -d build/dd/Build/Products/Debug-iphoneos/Heeler.app | head -1); echo "== app: $APP"
echo "== install"; xcrun devicectl device install app --device $DEV "$APP" 2>&1 | tail -4 || exit 30
echo "== launch"; xcrun devicectl device process launch --device $DEV $(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist") 2>&1 | tail -2
echo "== done"
