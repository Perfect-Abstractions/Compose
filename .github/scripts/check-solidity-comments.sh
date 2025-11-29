#!/usr/bin/env bash
set -euo pipefail

# Script: check-solidity-comments.sh
# Only checks tracked .sol files for forbidden comment styles.
# Allowed:
#  - Any occurrence of SPDX-License-Identifier: (regardless of comment delimiters)
#  - URLs containing http:// or https:// (to avoid flagging links)
#  - Inline comments after code (e.g., `uint x = 1; // comment`)
#  - Block comments '/* */' and '/** */' (both styles allowed)
# Disallowed:
#  - Lines starting with '//' comments (including '///'), except SPDX or URLs

IFS=',' read -r -a GLOBS <<< "${CHECK_GLOBS:-*.sol}"

echo "Checking Solidity comment style in files matching: ${GLOBS[*]}"

# Gather tracked files matching globs
files=()
while IFS= read -r -d '' f; do
  files+=("$f")
done < <(git ls-files -z -- "${GLOBS[@]}" 2>/dev/null || true)

if [ "${#files[@]}" -eq 0 ]; then
  echo "No Solidity files matched globs; nothing to check."
  exit 0
fi

has_error=0

for f in "${files[@]}"; do
  # Skip deleted files
  if [ ! -f "$f" ]; then
    continue
  fi

  # Skip binary files (shouldn't be any .sol, but be defensive)
  if file --brief --mime "$f" | grep -q 'charset=binary'; then
    continue
  fi

  # AWK script:
  # - Allow any line that contains SPDX-License-Identifier: (in any comment form)
  # - Allow lines that contain http:// or https:// (common links)
  # - Allow inline comments after code (// not at start of line)
  # - Allow block comments (/* */ and /** */ are both allowed)
  # - Flag lines starting with '//' (single-line comments)
  if ! awk '
  BEGIN { bad=0 }
  {
    # If the line contains SPDX-License-Identifier: allow it (regardless of comment delimiters)
    if ($0 ~ /SPDX-License-Identifier:/) { next }
    # Allow URLs containing http:// or https:// to avoid flagging links
    if ($0 ~ /https?:\/\//) { next }
    # Detect single-line comments that start the line (with optional leading whitespace)
    # This allows inline comments after code like: uint x = 1; // comment
    if ($0 ~ /^[[:space:]]*\/\//) {
      print FILENAME ":" NR ": contains \"//\" at start of line (single-line comments are disallowed in Solidity per style guide)."
      bad=1
    }
  }
  END { if (bad) exit 1 }
  ' "$f"; then
    has_error=1
  fi
done

if [ "$has_error" -ne 0 ]; then
  echo
  echo "Solidity comment style check failed: only block comments (/* */ or /** */) are allowed." 
  echo "Allowed exceptions: SPDX identifier (SPDX-License-Identifier:) anywhere, URLs (http:// or https://), and inline comments after code."
  echo "Please replace single-line // comments at the start of lines with /* */ or /** */ block comments."
  exit 1
fi

echo "Solidity comment style check passed."
exit 0
