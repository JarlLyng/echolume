#!/bin/sh

# Xcode Cloud post-clone hook.
#
# The app compiles Shaders.metal, and some Xcode Cloud images (Xcode 26 /
# Tahoe) may not ship the Metal toolchain. Try to fetch it — but BEST-EFFORT:
# if the download is unnecessary (already present) or unsupported here it can
# exit non-zero, and we must NOT fail the whole build on that. If Metal truly
# is missing, the archive step will surface the real compile error instead of
# this script masking it.

echo "ci_post_clone: attempting Metal toolchain download (best-effort)…"
if xcodebuild -downloadComponent MetalToolchain; then
  echo "ci_post_clone: Metal toolchain ready."
else
  echo "ci_post_clone: download returned $? — continuing (toolchain may already be present)."
fi

exit 0
