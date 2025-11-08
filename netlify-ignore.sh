#!/bin/bash
# Netlify ignore script - Skip builds if website/ directory hasn't changed
# Based on official Netlify documentation: https://docs.netlify.com/configure-builds/ignore-builds/
# Exit code: 0 = skip build, 1 = proceed with build

# Base branch name (adjust if your default branch is named differently)
BASE_BRANCH="main"

# First, try using Netlify's environment variables (works for regular PRs)
if [ -n "$CACHED_COMMIT_REF" ] && [ -n "$COMMIT_REF" ]; then
  if git diff --quiet $CACHED_COMMIT_REF $COMMIT_REF -- 'website/' 2>/dev/null; then
    # No changes in website/ directory - skip build
    exit 0
  else
    # Changes detected in website/ - proceed with build
    exit 1
  fi
fi

# For forked PRs or when env vars aren't available, fetch base branch and compare
# Fetch the latest commit on the base branch
git fetch origin $BASE_BRANCH:$BASE_BRANCH 2>/dev/null || true

# Check for changes in the website/ directory using three-dot syntax (merge base comparison)
# The three-dot syntax (BASE_BRANCH...HEAD) compares the merge base to HEAD
if git diff --quiet origin/$BASE_BRANCH...HEAD -- 'website/' 2>/dev/null; then
  # No changes detected in website/ directory - skip build
  exit 0
else
  # Changes detected in website/ directory - proceed with build
  exit 1
fi