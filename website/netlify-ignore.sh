#!/bin/bash
# Netlify ignore script - Skip builds if website/ directory hasn't changed
# Based on official Netlify documentation: https://docs.netlify.com/configure-builds/ignore-builds/
# Exit code: 0 = skip build, 1 = proceed with build

# This script runs from the base directory (website/) but compares paths from
# the repository root.
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT" || exit 1

# A missing cache can make both refs point to the current commit. In that case
# there is no trustworthy baseline, so run the build.
if [ -z "$CACHED_COMMIT_REF" ] || [ -z "$COMMIT_REF" ] || [ "$CACHED_COMMIT_REF" = "$COMMIT_REF" ]; then
  exit 1
fi

# Skip only when Netlify provides a valid baseline and website content is unchanged.
if git diff --quiet "$CACHED_COMMIT_REF" "$COMMIT_REF" -- website/ 2>/dev/null; then
  exit 0
fi

exit 1
