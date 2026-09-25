# Cebelca.biz skills for Claude Code

Two [Claude Code](https://claude.com/claude-code) skills that drive the
[InvoiceFox](https://www.invoicefox.com) / [Cebelca.biz](https://www.cebelca.biz)
invoicing API in plain language.

| Skill | What it does |
|-------|--------------|
| [`invoice`](invoice) | Create a customer, build an invoice, issue it, mark it paid, download its PDF |
| [`invoices-download`](invoices-download) | Download every issued invoice for a month as PDFs |

> *"Make an invoice for Acme d.o.o., 10 hours of consulting at €100, 22% VAT, wire transfer."*
>
> *"Download last month's invoices."* · *"Prenesi račune za julij, v angleščini."*

## Requirements

- Claude Code (these are not claude.ai skills — they run local scripts)
- `bash`, `curl`, and `python3` (standard library only, no packages)
- A Cebelca.biz / InvoiceFox account and its API token
- macOS or Linux

## Install

```bash
git clone <this-repo> skills && cd skills
./install.sh
```

`install.sh` copies both skills into `~/.claude/skills/` and asks for your API
token (input is hidden, saved to `~/.claude/skills/invoice/.token` with mode
600). It never overwrites a token or config you already have, so re-run it any
time to update the skills.

**Where to find the token:** in the Cebelca web app under *Nastavitve →
Nastavitve dostopa*, at the bottom of the page.

To install by hand instead: copy the `invoice/` and `invoices-download/`
folders into `~/.claude/skills/`, then write the token to
`~/.claude/skills/invoice/.token`.

Verify it works — this lists your existing customers:

```bash
bash ~/.claude/skills/invoice/cebelca.sh partners
```

## Use

Ask Claude in plain language, or type the skill name:

- `/invoice` — "make an invoice for Acme, 10 hours at €100, wire transfer"
- `/invoices-download` — "download last month's invoices"

Or drive the scripts yourself:

```bash
SH=~/.claude/skills/invoice/cebelca.sh
bash $SH partners                                    # existing customers
bash $SH head date_sent=16.09.2026 date_to_pay=24.09.2026 \
        date_served=16.09.2026 id_partner=12         # draft, prints ID=
bash $SH line title="Consulting" qty=10 mu=hour price=100 vat=22 \
        discount=0 id_invoice_sent=61
bash $SH issue id=61 title= doctype=0                # assigns the number
bash $SH pdf id=61 lang=en                           # → invoice-61-en.pdf

bash ~/.claude/skills/invoices-download/download.sh            # last month → ~/Downloads
bash ~/.claude/skills/invoices-download/download.sh 2026-07 lang=en
```

Each script prints its own usage with `--help`.

## Safety

The irreversible steps are gated, deliberately:

- **Issuing** assigns a permanent invoice number. Claude always shows a full
  summary and waits for an explicit yes. You can also make your terminal ask
  every time by adding this to `~/.claude/settings.json`:
  ```json
  { "permissions": { "ask": ["Bash(bash ~/.claude/skills/invoice/cebelca.sh issue:*)"] } }
  ```
- **Deleting** only ever touches a draft. `draft-rm` refuses any invoice that
  already has a number; issued invoices are corrected with a credit note or
  cancellation instead.
- **The `raw` escape hatch** allows only reads and draft creation
  (`select-*`, `get-*`, `export-*`, `insert-*`, `assure*`).
- **Editing a draft** means re-creating it and deleting the old one — the new
  draft is verified before the old one goes.
- `invoices-download` is read-only.

## Cash invoices (optional)

Cash and card invoices must be fiscalized with FURS, which needs extra config:

```bash
cp ~/.claude/skills/invoice/config.example.sh ~/.claude/skills/invoice/config.sh
# fill in OP_TAX_ID, OP_NAME, ID_LOCATION (from `cebelca.sh locations`)
# keep TEST_MODE=1 until a full run is verified against the FURS test server
```

Wire-transfer invoices need none of this — only the token.

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| `ERROR: no API token` | No `.token` file; run `install.sh` or create it by hand |
| `ERROR: unexpected API response (bad or expired token?)` | Wrong or expired token — reissue it in the web app |
| `ERROR: needs the invoice skill` | `invoices-download` requires `invoice` installed beside it |
| `REFUSED: invoice N is issued` | Working as intended: issued invoices can't be deleted |
| `set ID_LOCATION in config` | A cash invoice was attempted without `config.sh` (see above) |
| Downloads folder "looks empty" on macOS | Privacy protection blocks listing it; open the folder in Finder |

## Files

```
invoice/              SKILL.md · cebelca.sh · config.example.sh · README.md
invoices-download/    SKILL.md · download.sh · README.md
install.sh            copies both into ~/.claude/skills/ and sets up the token
```

Your token and `config.sh` stay out of git (see `.gitignore`).

## Credit

Built on the [InvoiceFox / Cebelca.biz API](https://github.com/InvoiceFox).
Not affiliated with or endorsed by InvoiceFox. Slovenian tax rules
(DDV, FURS fiscalization) are your responsibility — verify what you issue.
