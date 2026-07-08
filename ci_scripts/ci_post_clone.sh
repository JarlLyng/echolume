#!/bin/sh

# Xcode Cloud post-clone hook.
#
# Xcode Cloud's environment (Xcode 26 / macOS Tahoe) does not ship the Metal
# toolchain by default, but the app's Shaders.metal must be compiled during
# the archive. Without this, the "Archive - macOS" action fails with:
#   cannot execute tool 'metal' due to missing Metal Toolchain
#
# Download it before the build runs. The command is idempotent — if the
# toolchain is already present it is a fast no-op.
set -e

echo "ci_post_clone: downloading Metal toolchain…"
xcodebuild -downloadComponent MetalToolchain
echo "ci_post_clone: done."
