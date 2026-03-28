#!/bin/bash
set -e

echo "Building UsageIndicator..."
swift build -c release

echo "Creating app bundle..."
mkdir -p UsageIndicator.app/Contents/MacOS
mkdir -p UsageIndicator.app/Contents/Resources
cp .build/release/UsageIndicator UsageIndicator.app/Contents/MacOS/
cp Sources/UsageIndicator/Info.plist UsageIndicator.app/Contents/

echo "Creating zip for sharing..."
zip -r UsageIndicator.zip UsageIndicator.app

echo ""
echo "Done! Share UsageIndicator.zip or copy UsageIndicator.app to /Applications"
