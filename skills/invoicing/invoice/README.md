# invoice — issue invoices from Claude Code

A [Claude Code](https://claude.com/claude-code) skill that creates and issues real
invoices through the [InvoiceFox](https://www.invoicefox.com) / [Cebelca.biz](https://www.cebelca.biz)
API — in plain language.

> *"Make an invoice for Acme d.o.o., 10 hours of consulting at €100, 22% VAT, paid by wire transfer."*

Claude handles the whole flow: find or create the customer, build the invoice,
add the line items, issue it, and download the PDF.

## What it does

- **Customer dedup** — checks your existing contacts (and matches by VAT ID)
  before creating anyone, so a typo doesn't spawn a duplicate.
- **Full invoice flow** — partner → invoice head → line items → issue → mark paid → PDF.
- **Cash & non-cash** — non-cash (wire/PayPal) with regular numbering, or cash/card
  with FURS fiscalization (Slovenia).
- **PDF download in any language** — get the invoice in Slovenian, English,
  German, Italian, Croatian, French, … saved locally.
- **Draft fixes** — a draft is corrected by re-creating it and deleting the old
  one, which is invisible since drafts carry no invoice number.
- **Safe by design** — deletes nothing but drafts you approve (issued invoices are
  refused), and always asks for explicit confirmation before the irreversible
  "issue" step.

## Setup

Run `./install.sh invoice` in the repo root — it copies this skill into
`~/.claude/skills/invoice/` and asks for your API token (see
[Install](../README.md#install)).

Wire-transfer invoices need only the token. Cash and card invoices additionally
need `config.sh` for FURS fiscalization; see
[Cash invoices](../README.md#cash-invoices-optional).

## Usage

Just ask Claude in natural language, or drive the helper directly:

```bash
SH=~/.claude/skills/invoice/cebelca.sh

bash $SH partners                       # list existing customers
bash $SH partner name="Acme d.o.o." street="Cesta 1" postal=1000 city=Ljubljana
bash $SH head date_sent=07.07.2026 date_to_pay=15.07.2026 date_served=07.07.2026 id_partner=12
bash $SH line title="Consulting" qty=10 mu=hour price=100 vat=22 discount=0 id_invoice_sent=49
bash $SH issue id=49 title= doctype=0   # non-cash, assigns the invoice number
bash $SH pay date_of=07.07.2026 id_invoice_sent=49 id_payment_method=3
bash $SH pdf id=49                       # → invoice-49.pdf (Slovenian)
bash $SH pdf id=49 lang=en               # → invoice-49-en.pdf (English)
```

The PDF comes out in the language you pick — `lang=` accepts `si` (default),
`en`, `de`, `it`, `hr`, `fr`, and more.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Instructions Claude follows (the orchestration + safety rules) |
| `cebelca.sh` | Thin curl wrapper around the API |
| `config.example.sh` | Template for fiscalization defaults |
| `setup.sh` | Run by `install.sh`: checks requirements, asks for the token (not installed) |

## Safety

- Reads, creates, and finalizes. The one delete is `draft-rm`, which **refuses
  any invoice that already has a number**.
- Issuing an invoice is gated behind an explicit confirmation, since it assigns a
  permanent number and (for cash) files with the tax office.
- Keep `TEST_MODE=1` until you've verified a full run end-to-end.

## Credit

Built on the [InvoiceFox / Cebelca.biz API](https://github.com/InvoiceFox).
Not affiliated with or endorsed by InvoiceFox.
