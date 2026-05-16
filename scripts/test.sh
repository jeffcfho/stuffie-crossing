#!/usr/bin/env bash
# Internal test gate — run before any manual testing.
# Covers everything verifiable without a device.
set -e

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
SWIFT_FILES=(
  "$REPO/StuffieCrossing/App/AppDelegate.swift"
  "$REPO/StuffieCrossing/App/Constants.swift"
  "$REPO/StuffieCrossing/App/GameViewController.swift"
  "$REPO/StuffieCrossing/Models/Stuffie.swift"
  "$REPO/StuffieCrossing/Models/Level.swift"
  "$REPO/StuffieCrossing/Models/GameStateManager.swift"
  "$REPO/StuffieCrossing/Data/Levels.swift"
  "$REPO/StuffieCrossing/Nodes/BankNode.swift"
  "$REPO/StuffieCrossing/Nodes/BridgeNode.swift"
  "$REPO/StuffieCrossing/Nodes/StuffieNode.swift"
  "$REPO/StuffieCrossing/Scenes/MenuScene.swift"
  "$REPO/StuffieCrossing/Scenes/GameScene.swift"
)

echo "=== Step 1: Unit tests (logic layer) ==="
cd "$REPO"
swift test --filter StuffieCrossingCoreTests

echo ""
echo "=== Step 2: Full type-check (UIKit + SpriteKit files) ==="
xcrun -sdk iphonesimulator swiftc \
  -target arm64-apple-ios16.0-simulator \
  -sdk "$SDK" \
  -typecheck \
  "${SWIFT_FILES[@]}"
echo "Type-check passed."

echo ""
echo "=== Step 3: Generate Xcode project ==="
if ! command -v xcodegen &>/dev/null; then
  echo "xcodegen not found. Install it: brew install xcodegen"
  echo "Skipping steps 3 and 4."
  echo ""
  echo "Steps 1-2 passed. Install xcodegen to enable full build verification."
  exit 0
fi
xcodegen --spec "$REPO/project.yml" --project "$REPO"
echo "Xcode project generated."

echo ""
echo "=== Step 4: xcodebuild compile check ==="
xcodebuild \
  -project "$REPO/StuffieCrossing.xcodeproj" \
  -scheme StuffieCrossing \
  -destination 'generic/platform=iOS Simulator' \
  build \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "^(Build|error:|warning: .*\.swift)" | grep -v "^warning: .*no rule" || true

# Re-run to get the exit code (grep swallows it above)
xcodebuild \
  -project "$REPO/StuffieCrossing.xcodeproj" \
  -scheme StuffieCrossing \
  -destination 'generic/platform=iOS Simulator' \
  build \
  CODE_SIGNING_ALLOWED=NO \
  > /dev/null 2>&1
echo "xcodebuild passed."

echo ""
echo "All internal checks passed. Remaining: simulator launch + manual game-feel testing."
