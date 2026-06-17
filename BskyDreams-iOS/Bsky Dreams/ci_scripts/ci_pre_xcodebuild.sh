#!/bin/sh

# ci_pre_xcodebuild.sh
#
# Xcode Cloud runs this automatically before `xcodebuild`. It stamps the
# Xcode Cloud build number (CI_BUILD_NUMBER) into AppVersion.xcconfig so every
# TestFlight / App Store build gets a unique, monotonically increasing
# CURRENT_PROJECT_VERSION without a manual bump. MARKETING_VERSION (the
# user-facing version, e.g. 1.36) is intentionally left untouched — bump that
# by hand in AppVersion.xcconfig when you ship a new release.
#
# Location matters: this folder must sit next to the .xcodeproj
# (BskyDreams-iOS/Bsky Dreams/ci_scripts/) for Xcode Cloud to find it.

set -e

# CI_BUILD_NUMBER is only set inside Xcode Cloud. When run locally (or by any
# other tool) we no-op so the working copy is never mutated unexpectedly.
if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "CI_BUILD_NUMBER not set — not running in Xcode Cloud. Skipping version stamp."
  exit 0
fi

# Resolve AppVersion.xcconfig as a sibling of this ci_scripts folder, so the
# script does not depend on the current working directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCCONFIG="$SCRIPT_DIR/../AppVersion.xcconfig"

if [ ! -f "$XCCONFIG" ]; then
  echo "error: AppVersion.xcconfig not found at: $XCCONFIG"
  exit 1
fi

echo "Stamping CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER into AppVersion.xcconfig"

# Replace only the CURRENT_PROJECT_VERSION line, in place.
/usr/bin/sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER}/" "$XCCONFIG"

echo "----- AppVersion.xcconfig after stamping -----"
cat "$XCCONFIG"
