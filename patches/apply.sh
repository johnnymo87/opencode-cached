#!/usr/bin/env bash
# Apply caching.patch to opencode source
# Usage: ./apply.sh <path-to-opencode-source>

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Error: Missing argument"
  echo "Usage: $0 <path-to-opencode-source>"
  exit 1
fi

SOURCE_DIR="$1"
PATCH_FILE="$(dirname "$0")/caching.patch"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory not found: $SOURCE_DIR"
  exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
  echo "Error: Patch file not found: $PATCH_FILE"
  exit 1
fi

echo "Applying patch: $PATCH_FILE"
echo "To directory: $SOURCE_DIR"

cd "$SOURCE_DIR"

# Check if patch applies cleanly
if ! git apply --check "$PATCH_FILE" 2>/dev/null; then
  echo ""
  echo "❌ PATCH FAILED TO APPLY"
  echo ""
  echo "Attempting to apply patch to identify conflicts..."
  
  # Try to apply and capture errors
  if git apply "$PATCH_FILE" 2>&1 | tee /tmp/patch-error.log; then
    echo "✓ Patch applied successfully (unexpected success after check failed)"
    exit 0
  fi
  
  echo ""
  echo "Failed files:"
  grep -E "^error: .* does not apply" /tmp/patch-error.log || echo "  (see above errors)"
  
  echo ""
  echo "Checking for .rej files..."
  find . -name "*.rej" -type f 2>/dev/null || echo "  None found"
  
  echo ""
  echo "This likely means the upstream opencode version has changed."
  echo "The patch was created for opencode v1.2.6."
  echo "Please check the upstream release and update the patch if needed."
  
  exit 1
fi

# Apply the patch
if git apply "$PATCH_FILE"; then
  echo ""
  echo "✓ Patch applied successfully"
  
  # Show what was applied
  echo ""
  echo "Files modified:"
  git status --short
  
  exit 0
else
  echo ""
  echo "❌ Unexpected error applying patch"
  exit 1
fi
