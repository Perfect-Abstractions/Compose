#!/bin/bash
# Netlify ignore script - Skip builds if website/ directory hasn't changed
# Based on official Netlify documentation: https://docs.netlify.com/configure-builds/ignore-builds/
# Exit code: 0 = skip build, 1 = proceed with build

# This script runs from the base directory (website/) but needs to check
# changes relative to the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
BASE_BRANCH="main"

# First, try using Netlify's environment variables (works for regular PRs)
if [ -n "$CACHED_COMMIT_REF" ] && [ -n "$COMMIT_REF" ]; then
  if git diff --quiet $CACHED_COMMIT_REF $COMMIT_REF -- "$REPO_ROOT/website/" 2>/dev/null; then
    exit 0
  else
    exit 1
  fi
fi

# For forked PRs or when env vars aren't available, fetch base branch and compare
git fetch origin $BASE_BRANCH 2>/dev/null || true

# Check for changes in the website/ directory using three-dot syntax (merge base comparison)
if git diff --quiet origin/$BASE_BRANCH...HEAD -- "$REPO_ROOT/website/" 2>/dev/null; then
  exit 0
else
  exit 1
fi