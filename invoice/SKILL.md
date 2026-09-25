---
name: invoice
description: "Create and issue invoices through the InvoiceFox / Cebelca.biz API. Use when the user wants to make an invoice, bill a customer, issue a receipt/račun (including FURS-fiscalized cash invoices), add a customer/partner, mark an invoice paid, or download a single invoice PDF."
---

# /invoice — make an invoice via the Cebelca.biz / InvoiceFox API

This skill drives the live **www.cebelca.biz** API to create real invoices. All
API calls go through the helper script `cebelca.sh` in this skill's directory.

**The helper prints the raw API response and, for create calls, a parsed
`ID=<n>` line. Read that ID and pass it to the next step.**

## Before doing anything — preflight

Run the helper once. If it complains about a missing token or config, stop and
tell the user exactly what to create:

- Token: `~/.claude/skills/invoice/.token` (one line, the API key from
  *Nastavitve > Nastavitve dostopa*).
- Config: `cp ~/.claude/skills/invoice/config.example.sh ~/.claude/skills/invoice/config.sh`
  then fill in `OP_TAX_ID`, `OP_NAME`, `ID_LOCATION`, `TEST_MODE`.

**Always invoke the helper with its literal path** — `bash
~/.claude/skills/invoice/cebelca.sh <command> key=value ...` — never via a shell
variable. The user's permission allowlist matches on that exact prefix, so a
`$SH` shorthand would re-trigger an approval prompt on every call.

## Conventions

- **Dates** are `dd.mm.yyyy`. Use today's date for `date_sent`/`date_served`
  unless the user says otherwise; default `date_to_pay` to +8 days (ask if
  unsure).
- **VAT** (Slovenia): `22`, `9.5`, or `0`. Ask if the user hasn't said.
- **Payment methods**: `1`=cash, `2`=credit card, `3`=wire/other.
- Money and qty are plain decimals (e.g. `price=50`, `qty=10`).

## The full flow

Gather from the user: customer details, line items (title, qty, unit, price,
VAT), and whether it's a **cash** invoice (cash/card → must be fiscalized) or
**non-cash** (wire transfer / PayPal → regular numbering). If anything essential
is missing, ask before touching the API.

1. **Ensure the customer exists — WITHOUT creating a typo-duplicate.**

   `partner assure` only deduplicates on an *exact* match, so "Acme d.o.o." vs
   "Acme d.o.o" would create two near-identical customers. Avoid that:

   a. **If the customer has a VAT / tax number, prefer it as the key.** You can
      skip partner creation entirely and let the invoice head resolve the
      customer by tax number — in step 2 pass `taxnum=SI12345678 id_partner=0`
      instead of an `id_partner`. VAT number is a stable unique key, immune to
      name typos.

   b. **Otherwise, check the existing list first.** Fetch current customers and
      look for a close match (same company modulo punctuation, casing, spacing,
      "d.o.o."/"d.o.o", a transposed letter, etc.):
      ```
      bash ~/.claude/skills/invoice/cebelca.sh partners
      ```
      (Uses `partner select-all` — the customer contacts, same as the webapp's
      contacts page — and returns the full list in one call.)
      - **Close match found** → show the user the candidate (`id` + name) and
        ask whether to **reuse it** (use its `id` as `id_partner`) or **create a
        new** customer anyway. Do not silently pick one.
      - **No match** → create it:
        ```
        bash ~/.claude/skills/invoice/cebelca.sh partner name="Acme d.o.o." street="Velika cesta 1" postal=1000 city=Ljubljana country=Slovenia vatid=SI12345678
        ```
   Capture `ID=` → this is `id_partner`.

2. **Create the invoice head** — returns the invoice id:
   ```
   bash ~/.claude/skills/invoice/cebelca.sh head date_sent=07.07.2026 date_to_pay=15.07.2026 date_served=07.07.2026 id_partner=<partnerId>
   ```
   Capture `ID=` → this is `id_invoice_sent` / `id` for later steps.
   (For a foreign-currency invoice add `id_currency=<n> conv_rate=0`; the API
   fetches the rate itself. For advance/credit/etc. add `doctype=` — see below.)

3. **Add each line item** (repeat per line):
   ```
   bash ~/.claude/skills/invoice/cebelca.sh line title="Programming" qty=10 mu=hour price=50 vat=22 discount=0 id_invoice_sent=<invoiceId>
   ```

4. **Issue the invoice.** ⚠️ This is the irreversible step on the production
   server — it assigns a permanent number and, for cash invoices, files with the
   tax office. **Always show the user a summary (customer, lines, total,
   cash/non-cash) and get an explicit "yes" before running this.**

   - Cash (must fiscalize) — uses `OP_TAX_ID` / `OP_NAME` / `ID_LOCATION` /
     `TEST_MODE` from config:
     ```
     bash ~/.claude/skills/invoice/cebelca.sh issue-cash id=<invoiceId>
     ```
     Returns `{"docnum":"P1-B1-42","eor":"..."}`.
   - Non-cash (wire/PayPal, regular numbering):
     ```
     bash ~/.claude/skills/invoice/cebelca.sh issue id=<invoiceId> title= doctype=0
     ```
     Returns `{"new_title":"26-0005"}`.

5. **Mark paid** (optional, if already paid):
   ```
   bash ~/.claude/skills/invoice/cebelca.sh pay date_of=07.07.2026 id_invoice_sent=<invoiceId> id_payment_method=1 note=""
   ```

6. **PDF** (optional):
   ```
   bash ~/.claude/skills/invoice/cebelca.sh pdf id=<invoiceId>              # Slovenian (default)
   bash ~/.claude/skills/invoice/cebelca.sh pdf id=<invoiceId> lang=en      # English
   ```
   `lang=` accepts `si` (default), `en`, `de`, `it`, `hr`, `fr`, … — the API
   returns the invoice with localized labels. Saves `invoice-<id>.pdf` for
   Slovenian, or `invoice-<id>-<lang>.pdf` for other languages, in the current
   directory (`out=<file>` to choose the path). If the user asks for the
   invoice "in English/German/…", pass the matching `lang`. A non-zero exit
   means no PDF was saved.

## Fixing a draft — re-create, then delete

There is no safe update method: sending `insert-smart-2` with an `id` creates a
*second* draft instead of editing the first. So a draft is corrected by
replacing it. A draft has no invoice number, so nothing is lost or renumbered.

1. **Read the old draft's lines** (so the new one matches):
   ```
   bash ~/.claude/skills/invoice/cebelca.sh raw invoice-sent-b select-of-more id_invoice_sent=<oldId>
   ```
2. **Build the corrected draft** with `head` + `line`, as in the normal flow.
3. **Verify it** — read it back or fetch the PDF.
4. **Delete the old draft**, only after the new one is confirmed good and the
   user has explicitly approved deleting that specific id:
   ```
   bash ~/.claude/skills/invoice/cebelca.sh draft-rm id=<oldId>
   ```

Always create before deleting: if a step fails, the original is still there.

`draft-rm` refuses any invoice that already has a number. **An issued invoice
is never edited or deleted** — correct it with a credit note (`doctype=2`) or a
cancellation (`doctype=3`) instead.

## Other commands

- `bash ~/.claude/skills/invoice/cebelca.sh locations` — list registered sales locations (to find `ID_LOCATION`).
- `bash ~/.claude/skills/invoice/cebelca.sh fiscal id=<invoiceId>` — retrieve ZOI / EOR / QR / barcode.
- `bash ~/.claude/skills/invoice/cebelca.sh sent month=YYYY-MM` — issued invoices dated that month
  (`id`, number, date; drafts skipped). For downloading a whole month, use the
  `invoices-download` skill.
- `bash ~/.claude/skills/invoice/cebelca.sh raw <resource> <method> key=value ...` — escape hatch for
  other read or draft-creating API methods (`select-*`, `get-*`, `export-*`,
  `insert-*`, `assure*`), e.g. a proforma `preinvoice`.

## doctypes (for `head` and `issue`)

`0` regular · `1` advance · `2` credit note (dobropis) · `3` cancellation (storno) · `10` final invoice.

## Safety rules

- The only thing this skill deletes is a draft, via `draft-rm`, and only when
  the user has approved that specific id. Issued invoices are permanent: the
  command refuses anything with a number. The `raw` escape hatch allows only
  reading and creating drafts; issuing, paying, updating, cancelling, and
  deleting are refused there.
- Never run `issue-cash` / `issue` without an explicit confirmation for that
  specific invoice. Creating the head + lines is a reversible draft; issuing is not.
- If a call returns a validation error (JSON with field errors) or a non-`ok`
  response, stop, show it to the user, and fix the inputs — do not retry blindly.
- Keep `TEST_MODE=1` until a full run has been verified end-to-end, then the
  user can flip it to `0` in `config.sh` for real fiscalization.
