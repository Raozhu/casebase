#!/bin/zsh
# Builds the README demo renderer: the app's own sources plus tools/readme-demos/*.swift,
# placed inside a copy of the Debug app bundle so asset catalog images resolve.
set -euo pipefail

ROOT=${0:A:h:h:h}
OUT=$ROOT/build/readme-demos
APP=$OUT/DemoRenderer.app
SRC=$OUT/src

xcodebuild -project "$ROOT/casebase.xcodeproj" -scheme casebase -configuration Debug \
    -derivedDataPath "$ROOT/build/demo-dd" CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
    build -quiet

rm -rf "$APP" "$SRC"
mkdir -p "$OUT"
ditto "$ROOT/build/demo-dd/Build/Products/Debug/casebase.app" "$APP"
rm -f "$APP/Contents/MacOS/"*
# Separate bundle id so the renderer never touches the real app's defaults or permissions.
plutil -replace CFBundleIdentifier -string Celve.casebase.readme-demos "$APP/Contents/Info.plist"
plutil -replace CFBundleExecutable -string DemoRenderer "$APP/Contents/Info.plist"

# Compile a copy of the app sources with three non-visual tweaks:
# - the renderer has no Accessibility / Screen Recording grant, so report them as granted;
# - expose the capture flight and screenshot overlay views so the stage can host them.
ditto "$ROOT/casebase" "$SRC"
rm "$SRC/main.swift"
sed -i '' \
    -e 's/selectionCaptureAuthorized = AXIsProcessTrusted()/selectionCaptureAuthorized = true/' \
    -e 's/screenshotCaptureAuthorized = CGPreflightScreenCaptureAccess()/screenshotCaptureAuthorized = true/' \
    "$SRC/Notch/NotchViewModel.swift"
sed -i '' -E \
    -e 's/^private (final class SelectionCaptureAnimationModel|struct SelectionCaptureAnimationRootView|enum SelectionCaptureFlightContent|struct SelectionCaptureFlight[: ])/\1/' \
    "$SRC/Notch/SelectionCaptureAnimationWindowController.swift"
sed -i '' \
    -e 's/^private final class ScreenshotCaptureOverlayView/final class ScreenshotCaptureOverlayView/' \
    -e 's/^    private var selectionRect: CGRect?/    var selectionRect: CGRect?/' \
    "$SRC/App/ScreenshotCaptureOverlayWindowController.swift"

sources=(${(f)"$(find "$SRC" -name '*.swift')"})
xcrun swiftc -Onone -D DEBUG -swift-version 5 -module-name casebase \
    -target arm64-apple-macos14.0 -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
    "${sources[@]}" "$ROOT"/tools/readme-demos/*.swift \
    -o "$APP/Contents/MacOS/DemoRenderer"

codesign --force --sign - "$APP"
echo "$APP"
