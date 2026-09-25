#!/usr/bin/env bash
#
# install.sh — install the `invoice` and `invoices-download` skills into
# ~/.claude/skills/ and set up the Cebelca.biz API token.
#
# Safe to re-run: it refreshes the skill files and never overwrites an existing
# token or config.sh. Set CLAUDE_SKILLS_DIR to install somewhere else.
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

for tool in curl python3; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "ERROR: $tool is required but not installed." >&2
    exit 1
  fi
done

# Copy by name so a local .token / config.sh is never distributed.
mkdir -p "$DEST/invoice" "$DEST/invoices-download"
cp "$SRC/invoice/"{SKILL.md,README.md,cebelca.sh,config.example.sh} "$DEST/invoice/"
cp "$SRC/invoices-download/"{SKILL.md,README.md,download.sh} "$DEST/invoices-download/"
chmod +x "$DEST/invoice/cebelca.sh" "$DEST/invoices-download/download.sh"
echo "Installed invoice and invoices-download to $DEST"

TOKEN_FILE="$DEST/invoice/.token"
if [ -s "$TOKEN_FILE" ]; then
  echo "Kept the existing API token in $TOKEN_FILE"
elif [ -t 0 ]; then
  echo
  echo "API token — Cebelca web app > Nastavitve > Nastavitve dostopa (bottom of the page)."
  printf 'Paste it here, or press Enter to skip: '
  read -rs token
  echo
  if [ -n "$token" ]; then
    printf '%s\n' "$token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo "Saved $TOKEN_FILE"
  else
    echo "Skipped. Add it later with:  echo 'YOUR_TOKEN' > $TOKEN_FILE"
  fi
else
  echo "No token yet. Add it with:  echo 'YOUR_TOKEN' > $TOKEN_FILE"
fi

cat <<EOF

Done. In Claude Code:
  /invoice            "make an invoice for Acme, 10 hours at 100 EUR, wire transfer"
  /invoices-download  "download last month's invoices"

Check the token works (lists your customers):
  bash $DEST/invoice/cebelca.sh partners
EOF
