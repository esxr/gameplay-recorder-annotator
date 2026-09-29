#!/bin/zsh
# Build + sign with stable identity so the Screen Recording permission survives rebuilds.
set -e
cd "$(dirname "$0")"
xcodegen generate -q
xcodebuild -project GameplayRecorder.xcodeproj -scheme GameplayRecorder -configuration Debug -derivedDataPath ../build/DerivedData build 2>&1 | tee ../build/build.log | grep -E "error:|warning: unre|BUILD (SUCCEEDED|FAILED)" || true
APP=../build/DerivedData/Build/Products/Debug/GameplayRecorder.app
rm -rf ../build/GameplayRecorder.app && cp -R "$APP" ../build/GameplayRecorder.app
codesign --force --deep -s 3F8BA5CBC60D0C247A27C6824881D280D4C679B2 ../build/GameplayRecorder.app
tail -1 ../build/build.log
