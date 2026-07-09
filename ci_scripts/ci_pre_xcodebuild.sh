#!/bin/sh

# Xcode Cloud pre-build hook.
#
# Xcode Cloud stamps CFBundleVersion with its own incrementing counter
# (CI_BUILD_NUMBER), ignoring the committed CURRENT_PROJECT_VERSION. Its
# counter started at 1, but builds 9–13 were already uploaded manually, so a
# low Cloud number is rejected by App Store Connect on delivery ("build must
# be higher than the current build").
#
# Force the project's build number to CI_BUILD_NUMBER + 20 so every Cloud
# build clears the existing history (>13) and keeps monotonically increasing.
# The app uses a generated Info.plist, so the build number lives in
# CURRENT_PROJECT_VERSION in project.pbxproj.
set -e

BUILD_NUMBER=$((CI_BUILD_NUMBER + 20))
echo "ci_pre_xcodebuild: setting build number to ${BUILD_NUMBER} (CI_BUILD_NUMBER=${CI_BUILD_NUMBER})"

cd "$CI_PRIMARY_REPOSITORY_PATH"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/g" \
  echolume.xcodeproj/project.pbxproj

echo "ci_pre_xcodebuild: CURRENT_PROJECT_VERSION is now:"
grep -m1 'CURRENT_PROJECT_VERSION' echolume.xcodeproj/project.pbxproj
