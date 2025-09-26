#!/bin/bash

# Script to resolve entitlements placeholders for code signing outside Xcode
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <input_entitlements> <team_id> <output_entitlements>"
  exit 1
fi

INPUT_ENTITLEMENTS="$1"
TEAM_ID="$2"
OUTPUT_ENTITLEMENTS="$3"

if [[ ! -f "$INPUT_ENTITLEMENTS" ]]; then
  echo "Error: Input entitlements file not found: $INPUT_ENTITLEMENTS"
  exit 1
fi

echo "Resolving entitlements placeholders..."
echo "  Input: $INPUT_ENTITLEMENTS"
echo "  Team ID: $TEAM_ID"
echo "  Output: $OUTPUT_ENTITLEMENTS"

# Replace $(AppIdentifierPrefix) with the team ID followed by a dot
sed "s/\$(AppIdentifierPrefix)/${TEAM_ID}./g" "$INPUT_ENTITLEMENTS" > "$OUTPUT_ENTITLEMENTS"

echo "✅ Entitlements resolved successfully"
echo ""
echo "Original entitlements:"
cat "$INPUT_ENTITLEMENTS"
echo ""
echo "Resolved entitlements:"
cat "$OUTPUT_ENTITLEMENTS"
