---
name: invoices-download
description: "Use when the user wants to download, export, or collect all issued invoices (izdani računi) for a month from Cebelca.biz / InvoiceFox as PDFs — e.g. for the accountant (računovodja), monthly bookkeeping, or DDV. Triggers: \"download last month's invoices\", \"prenesi račune za julij\", \"export invoices for 2026-08\"."
---

# /invoices-download — PDFs of all issued invoices for a month

All work goes through `download.sh` in this skill's directory. It is
**read-only** (lists invoices, downloads PDFs) and calls the API through the
`invoice` skill's `cebelca.sh`, which holds the token and config.

**Always invoke it with its literal path** — `bash
~/.claude/skills/invoices-download/download.sh ...` — never via a shell
variable, so the user's permission allowlist matches.

## Command

```
bash ~/.claude/skills/invoices-download/download.sh [YYYY-MM] [lang=si] [out=DIR]
```

| Argument | Default | Meaning |
|----------|---------|---------|
| `YYYY-MM` | previous month | Month matched on the **issue date** (`date_sent`) |
| `lang=` | `si` | PDF language: `si`, `en`, `de`, `it`, `hr`, `fr`, … |
| `out=` | `~/Downloads` | Target folder |

Drafts (no invoice number yet) are skipped. Files are named by invoice number:
`26-007A.pdf`, or `26-007A-en.pdf` for other languages.

## Turning the request into a month

Resolve the month relative to today's date:

- No month / "last month" / "prejšnji mesec" → omit the argument.
- "this month" / "ta mesec" → the current `YYYY-MM`.
- A month name without a year ("July", "julij") → the most recent such month,
  counting the current one (in September 2026, "julij" = `2026-07`,
  "september" = `2026-09`, "november" = `2025-11`).
- A month with a year → use it as given.

Pass `lang=` only if the user asks for a language ("in English" → `lang=en`)
and `out=` only if they name a folder.

## Reporting

The script prints one `OK`/`FAIL` line per invoice and a final
`Downloaded N of M invoices for YYYY-MM to DIR` line. Relay the invoice
numbers, the folder, and any `FAIL` lines. `No issued invoices dated YYYY-MM.`
is a normal result — say so plainly, don't retry other months unasked.

## Errors

- `ERROR: no API token` (exit 3) → tell the user to save the token (from
  *Nastavitve > Nastavitve dostopa*) to `~/.claude/skills/invoice/.token`.
- `ERROR: needs the invoice skill` (exit 3) → the `invoice` skill must be
  installed at `~/.claude/skills/invoice/`.
- `ERROR: unexpected API response` (exit 5) → show the response; usually a bad
  or expired token. This is a failure, never report it as "no invoices".
- Non-zero exit after `FAIL` lines → show which invoices failed; re-running
  the same command is safe (a failed download never replaces an existing PDF).
