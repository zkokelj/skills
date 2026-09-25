#!/usr/bin/env bash
#
# download.sh — download PDFs of all issued invoices for one month.
# Used by the `invoices-download` Claude skill. Read-only. All API access,
# including the token and config, goes through the `invoice` skill's cebelca.sh.
#
set -euo pipefail

CEBELCA="$(dirname "${BASH_SOURCE[0]}")/../invoice/cebelca.sh"

usage() {
  cat >&2 <<'EOF'
Usage: download.sh [YYYY-MM] [lang=si|en|de|it|hr|fr|..] [out=DIR]

  YYYY-MM   month, matched on the invoice issue date (date_sent);
            defaults to the previous month
  lang      PDF language, default si
  out       target folder, default ~/Downloads

Drafts (invoices without a number) are skipped. Files are named by invoice
number, e.g. 26-007A.pdf (or 26-007A-en.pdf for non-Slovenian PDFs).
EOF
  exit 2
}

if [ ! -f "$CEBELCA" ]; then
  echo "ERROR: needs the invoice skill installed next to this one (~/.claude/skills/invoice/cebelca.sh)." >&2
  exit 3
fi

month=""; lang="si"; out=""
for arg in "$@"; do
  case "$arg" in
    lang=*) lang="${arg#lang=}" ;;
    out=*)  out="${arg#out=}" ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]) month="$arg" ;;
    -h|--help|help) usage ;;
    *) echo "Unknown argument: $arg" >&2; usage ;;
  esac
done

if [ -z "$month" ]; then
  y="$(date +%Y)"; m=$((10#$(date +%m) - 1))
  if [ "$m" -eq 0 ]; then y=$((y - 1)); m=12; fi
  month="$(printf '%04d-%02d' "$y" "$m")"
fi

[ -n "$out" ] || out="$HOME/Downloads"
out="${out/#\~/$HOME}"

rows="$(bash "$CEBELCA" sent "month=$month")"
if [ -z "$rows" ]; then
  echo "No issued invoices dated $month."
  exit 0
fi

mkdir -p "$out"
total=0; failed=0
while IFS=$'\t' read -r id title date_sent; do
  total=$((total + 1))
  name="${title//\//-}"
  if [ "$lang" = "si" ]; then file="$out/$name.pdf"; else file="$out/$name-$lang.pdf"; fi
  if bash "$CEBELCA" pdf "id=$id" "lang=$lang" "out=$file" > /dev/null; then
    echo "OK    $title  ($date_sent)  → $file"
  else
    failed=$((failed + 1))
    echo "FAIL  $title  ($date_sent)  id=$id" >&2
  fi
done <<< "$rows"

echo "Downloaded $((total - failed)) of $total invoices for $month to $out"
[ "$failed" -eq 0 ]
