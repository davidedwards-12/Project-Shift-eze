#!/bin/sh
# Xcode Cloud runs this before each build.
#
# Every upload to App Store Connect needs a higher build number than the last.
# Use Xcode Cloud's own counter, which goes up by one per build, plus an offset
# so it stays above the builds uploaded by hand before Xcode Cloud (1 and 2).
set -eu

OFFSET=100

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
    echo "CI_BUILD_NUMBER isn't set; leaving the build number as it is."
    exit 0
fi

BUILD=$((CI_BUILD_NUMBER + OFFSET))
PROJECT="$CI_PRIMARY_REPOSITORY_PATH/ios/ShiftEze.xcodeproj/project.pbxproj"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD;/" "$PROJECT"
echo "Build number set to $BUILD (Xcode Cloud build $CI_BUILD_NUMBER + $OFFSET)."
grep -m1 "CURRENT_PROJECT_VERSION" "$PROJECT"
