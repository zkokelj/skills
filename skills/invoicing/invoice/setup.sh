#!/usr/bin/env bash
#
# setup.sh <installed-skill-dir> — run by the repo's install.sh after copying
# the `invoice` skill. Checks requirements and asks for the Cebelca.biz API
# token unless one is already saved. Never overwrites an existing token.
#
set -euo pipefail

DIR="$1"

for tool in curl python3; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "ERROR: $tool is required by the invoice skill but not installed." >&2
    exit 1
  fi
done

TOKEN_FILE="$DIR/.token"
if [ -s "$TOKEN_FILE" ]; then
  echo "  Kept the existing API token in $TOKEN_FILE"
elif [ -t 0 ]; then
  echo "  API token — Cebelca web app > Nastavitve > Nastavitve dostopa (bottom of the page)."
  printf '  Paste it here, or press Enter to skip: '
  read -rs token
  echo
  if [ -n "$token" ]; then
    printf '%s\n' "$token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo "  Saved $TOKEN_FILE"
  else
    echo "  Skipped. Add it later with:  echo 'YOUR_TOKEN' > $TOKEN_FILE"
  fi
else
  echo "  No token yet. Add it with:  echo 'YOUR_TOKEN' > $TOKEN_FILE"
fi
echo "  Check it works (lists your customers):  bash $DIR/cebelca.sh partners"
