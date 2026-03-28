#!/bin/bash
set -e

echo "Building ccusage..."
swift build -c release

echo "Creating app bundle..."
mkdir -p ccusage.app/Contents/MacOS
mkdir -p ccusage.app/Contents/Resources
cp .build/release/UsageIndicator ccusage.app/Contents/MacOS/ccusage
cp Sources/UsageIndicator/Info.plist ccusage.app/Contents/
cp ccusage.icns ccusage.app/Contents/Resources/

echo ""
echo "Done! Copy ccusage.app to /Applications to use it."
