#!/usr/bin/env bash
#
# cebelca.sh — thin wrapper around the InvoiceFox / Cebelca.biz API.
# Used by the `invoice` and `invoices-download` Claude skills. Every subcommand
# prints the raw API response; the create-* subcommands also print a parsed
# ID=<n> line so the orchestrator can chain calls.
#
# Config resolution (first match wins):
#   1. env vars (CEBELCA_TOKEN, BASE_URL, OP_TAX_ID, OP_NAME, ID_LOCATION, TEST_MODE)
#   2. ~/.claude/skills/invoice/config.sh   (sourced)
#   3. token file ~/.claude/skills/invoice/.token
#
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- load config -------------------------------------------------------------
[ -f "$SKILL_DIR/config.sh" ] && source "$SKILL_DIR/config.sh"

BASE_URL="${BASE_URL:-https://www.cebelca.biz}"
TEST_MODE="${TEST_MODE:-0}"

if [ -z "${CEBELCA_TOKEN:-}" ]; then
  if [ -f "$SKILL_DIR/.token" ]; then
    CEBELCA_TOKEN="$(tr -d ' \t\r\n' < "$SKILL_DIR/.token")"
  fi
fi
if [ -z "${CEBELCA_TOKEN:-}" ]; then
  echo "ERROR: no API token. Put it in $SKILL_DIR/.token or set CEBELCA_TOKEN." >&2
  exit 3
fi

# --- helpers -----------------------------------------------------------------

# api <resource> <method> [key=value ...]  — POST, url-encoding every field.
# With no fields it still sends an empty form body: the API rejects GET (401)
# and a body-less POST (400).
api() {
  local resource="$1" method="$2"; shift 2
  local args=(--data "")
  local kv
  [ "$#" -eq 0 ] || args=()
  for kv in "$@"; do
    args+=(--data-urlencode "$kv")
  done
  curl -sS -u "$CEBELCA_TOKEN:x" \
    "${args[@]}" \
    "$BASE_URL/API?_r=$resource&_m=$method"
}

# extract_id <api-response> — pulls the first id from either 'id':N or "id":N.
extract_id() {
  grep -oE "['\"]id['\"][[:space:]]*:[[:space:]]*[0-9]+" | grep -oE "[0-9]+" | head -1
}

# run a create call, print raw response, then a parsed ID= line.
run_create() {
  local resp; resp="$(api "$@")"
  printf '%s\n' "$resp"
  local id; id="$(printf '%s' "$resp" | extract_id || true)"
  [ -n "$id" ] && echo "ID=$id"
}

usage() {
  cat >&2 <<'EOF'
Usage: cebelca.sh <command> [key=value ...]

  partners  [page=0]              → list existing customers (for dedup / typo check)
  partner   name=.. street=.. postal=.. city=.. [country=..] [vatid=..]
                                  → assure partner, prints ID (partner id)
  head      date_sent=dd.mm.yyyy date_to_pay=.. date_served=.. id_partner=N
            [taxnum=..] [id_currency=..] [conv_rate=0] [id_document_ext=..] [doctype=0]
                                  → invoice head (insert-smart-2), prints ID (invoice id)
  line      title=.. qty=.. mu=.. price=.. vat=.. discount=0 id_invoice_sent=N
                                  → add an invoice line
  pay       date_of=dd.mm.yyyy id_invoice_sent=N id_payment_method=N [note=..]
                                  → mark invoice fully paid (mark-paid)
  issue-cash id=N                 → finalize + FISCALIZE (cash), uses config
                                    OP_TAX_ID / OP_NAME / ID_LOCATION / TEST_MODE
  issue     id=N [title=] [doctype=0]
                                  → finalize non-cash (wire/PayPal), regular numbering
  fiscal    id=N                  → get fiscal info (ZOI/EOR/QR)
  sent      month=YYYY-MM         → issued invoices dated that month (drafts skipped),
                                    one per line: id <TAB> number <TAB> date_sent
  pdf       id=N [lang=si|en|de|it|hr|fr|..] [out=FILE] [res=invoice-sent] [doctitle=..]
                                  → download PDF, default file invoice-<id>[-<lang>].pdf
  draft-rm  id=N                  → delete a DRAFT (refuses anything already issued)
  locations                       → list sales locations (select-all)
  raw       <resource> <method> [key=value ...]
                                  → escape hatch, only select-/get-/export-/insert-/assure methods

Config: $SKILL_DIR/config.sh  ·  Token: $SKILL_DIR/.token
EOF
  exit 2
}

# --- dispatch ----------------------------------------------------------------
cmd="${1:-}"; [ -n "$cmd" ] && shift || usage

case "$cmd" in
  partners)
    # select-all = customer contacts (as shown in the webapp contacts page).
    # NOT select-all-internal, which returns internal partners (warehouses).
    [ "$#" -gt 0 ] || set -- "page=0"
    api partner select-all "$@"; echo
    ;;
  partner)
    run_create partner assure "$@"
    ;;
  head)
    run_create invoice-sent insert-smart-2 "$@"
    ;;
  line)
    api invoice-sent-b insert-into "$@"; echo
    ;;
  pay)
    api invoice-sent-p mark-paid "$@"; echo
    ;;
  issue-cash)
    api invoice-sent finalize-invoice "$@" \
      "id_location=${ID_LOCATION:?set ID_LOCATION in config}" \
      "fiscalize=1" \
      "op-tax-id=${OP_TAX_ID:?set OP_TAX_ID in config}" \
      "op-name=${OP_NAME:?set OP_NAME in config}" \
      "test_mode=$TEST_MODE"
    echo
    ;;
  issue)
    api invoice-sent finalize-invoice-2015 "$@"; echo
    ;;
  fiscal)
    api invoice-sent get-fiscal-info "$@"; echo
    ;;
  sent)
    month=""
    for kv in "$@"; do
      case "$kv" in month=*) month="${kv#month=}" ;; esac
    done
    [[ "$month" =~ ^[0-9]{4}-(0[1-9]|1[0-2])$ ]] \
      || { echo "sent: month=YYYY-MM required, got '$month'" >&2; exit 2; }
    # select-all returns every issued invoice in one [[row, ...]] response.
    api invoice-sent select-all | python3 -c '
import html, json, sys
month, raw = sys.argv[1], sys.stdin.read()
try:
    rows = json.loads(raw)[0]
    if not (isinstance(rows, list) and all(isinstance(r, dict) for r in rows)):
        raise ValueError
except (ValueError, IndexError, KeyError, TypeError):
    sys.stderr.write("ERROR: unexpected API response (bad or expired token?):\n%s\n" % raw[:500])
    sys.exit(5)
for r in sorted(rows, key=lambda r: (r["date_sent"], r["id"])):
    # Drafts have no invoice number yet; numbers come HTML-encoded (021&#47;26).
    if r["title"] and r["date_sent"].startswith(month):
        print("%s\t%s\t%s" % (r["id"], html.unescape(r["title"]), r["date_sent"]))
' "$month"
    ;;
  draft-rm)
    id=""
    for kv in "$@"; do
      case "$kv" in id=*) id="${kv#id=}" ;; esac
    done
    # The API deletes nothing but still answers OK when the id is missing.
    [[ "$id" =~ ^[0-9]+$ ]] || { echo "draft-rm: id=N required" >&2; exit 2; }
    # Only drafts may go: an issued invoice has a number and is permanent.
    title="$(api invoice-sent select-one "id=$id" | python3 -c '
import html, json, sys
raw = sys.stdin.read()
try:
    rows = json.loads(raw)[0]
    if not (isinstance(rows, list) and rows and isinstance(rows[0], dict)):
        raise ValueError
except (ValueError, IndexError, KeyError, TypeError):
    sys.stderr.write("ERROR: no invoice %s, or unexpected response:\n%s\n" % (sys.argv[1], raw[:500]))
    sys.exit(5)
print(html.unescape(rows[0]["title"]))
' "$id")"
    if [ -n "$title" ]; then
      echo "REFUSED: invoice $id is issued as '$title'. Only drafts can be deleted." >&2
      exit 4
    fi
    # delete answers 500 even when it worked, so ignore it and re-read instead.
    api invoice-sent delete "id=$id" > /dev/null 2>&1 || true
    left="$(api invoice-sent select-one "id=$id" | python3 -c '
import json, sys
try:
    print(len(json.loads(sys.stdin.read())[0]))
except Exception:
    print("?")
')"
    if [ "$left" = "0" ]; then
      echo "Deleted draft $id"
    else
      echo "ERROR: draft $id is still there" >&2
      exit 6
    fi
    ;;
  locations)
    api sales-location select-all; echo
    ;;
  pdf)
    id=""; res="invoice-sent"; lang="si"; doctitle=""; out=""
    for kv in "$@"; do
      case "$kv" in
        id=*)       id="${kv#id=}" ;;
        res=*)      res="${kv#res=}" ;;
        lang=*)     lang="${kv#lang=}" ;;
        doctitle=*) doctitle="${kv#doctitle=}" ;;
        out=*)      out="${kv#out=}" ;;
      esac
    done
    [ -n "$id" ] || { echo "pdf: id=N required" >&2; exit 2; }
    # Default the document title (URL-encoded) to the chosen language unless
    # the caller passed one explicitly. Unknown langs fall back to English.
    if [ -z "$doctitle" ]; then
      case "$lang" in
        si) doctitle="Ra%C4%8Dun%20%C5%A1t." ;;   # Račun št.
        hr) doctitle="Ra%C4%8Dun%20br." ;;         # Račun br.
        de) doctitle="Rechnung%20Nr." ;;
        it) doctitle="Fattura%20n." ;;
        fr) doctitle="Facture%20n%C2%B0" ;;         # Facture n°
        *)  doctitle="Invoice%20no." ;;             # en + fallback
      esac
    fi
    # Suffix the filename with the language so versions don't clobber (si stays bare).
    if [ -z "$out" ]; then
      if [ "$lang" = "si" ]; then out="invoice-${id}.pdf"; else out="invoice-${id}-${lang}.pdf"; fi
    fi
    # Download next to the target and only replace it with a real PDF, so a
    # failed download never leaves an error page or wipes a good copy.
    if curl -sS -f -u "$CEBELCA_TOKEN:x" -o "$out.part" \
         "$BASE_URL/API-pdf?id=$id&format=PDF&doctitle=$doctitle&lang=$lang&disposition=inline&res=$res&preview=0" \
       && [ "$(head -c 4 "$out.part")" = "%PDF" ]; then
      mv "$out.part" "$out"
      echo "Saved $out"
    else
      rm -f "$out.part"
      echo "ERROR: no PDF for id=$id (bad token or id?)" >&2
      exit 6
    fi
    ;;
  raw)
    r="${1:?resource}"; m="${2:?method}"; shift 2 || true
    # Safety: the escape hatch may read and create drafts, nothing else.
    # Issuing, paying, updating, cancelling and deleting all go through
    # dedicated commands (or not at all).
    case "$m" in
      select-*|get-*|export-*|insert-*|assure*) ;;
      *)
        echo "REFUSED: raw only allows select-/get-/export-/insert-/assure methods, not '$m'." >&2
        exit 4
        ;;
    esac
    api "$r" "$m" "$@"; echo
    ;;
  -h|--help|help) usage ;;
  *) echo "Unknown command: $cmd" >&2; usage ;;
esac
