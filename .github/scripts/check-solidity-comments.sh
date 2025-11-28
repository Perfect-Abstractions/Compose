#!/usr/bin/env bash
set -euo pipefail

# Script: check-solidity-comments.sh
# Only checks tracked .sol files for forbidden comment styles.
# Allowed exceptions:
#  - Any occurrence of SPDX-License-Identifier: (regardless of comment delimiters)
#  - URLs containing http:// or https:// (to avoid flagging links)
# Disallowed:
#  - Any single-line '//' comments (including '///'), except SPDX or URLs
#  - Block comments '/*' that are not documentation comments starting with '/**'

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
  # - Flag lines with '//' (single-line comments) otherwise
  # - Flag occurrences of '/*' that are not '/**'
  if ! awk '
  BEGIN { bad=0 }
  {
    # If the line contains SPDX-License-Identifier: allow it (regardless of comment delimiters)
    if ($0 ~ /SPDX-License-Identifier:/) { next }
    # Allow URLs containing http:// or https:// to avoid flagging links
    if ($0 ~ /https?:\/\//) { next }
    # Detect single-line comments: // (this also catches ///)
    if ($0 ~ /\/\//) {
      print FILENAME ":" NR ": contains \"//\" (single-line comments are disallowed in Solidity per style guide)."
      bad=1
    }
    # Detect block comment starts /* that are not /**
    if ($0 ~ /\/\*/ && $0 !~ /\/\*\*/) {
      print FILENAME ":" NR ": contains \"/*\" (non-documentation block comments are disallowed)."
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
  echo "Solidity comment style check failed: only documentation block comments starting with /** ... */ are allowed." 
  echo "Allowed exceptions: SPDX identifier (SPDX-License-Identifier:) anywhere and URLs (http:// or https://)."
  echo "Please replace single-line // comments and non-/** block comments with /** ... */ documentation comments."
  exit 1
fi

echo "Solidity comment style check passed."
exit 0
