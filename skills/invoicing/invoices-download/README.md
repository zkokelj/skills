# invoices-download — monthly invoice PDFs from Claude Code

A [Claude Code](https://claude.com/claude-code) skill that downloads the PDFs of
all issued invoices for a month from the [InvoiceFox](https://www.invoicefox.com) /
[Cebelca.biz](https://www.cebelca.biz) API.

> *"Download last month's invoices."* · *"Prenesi račune za julij, v angleščini."*

## What it does

- Lists issued invoices whose **issue date** falls in the chosen month
  (default: the previous month) and skips drafts.
- Saves each one as `<invoice number>.pdf` in `~/Downloads` (`out=DIR` for somewhere else).
- Any PDF language: `si` (default), `en`, `de`, `it`, `hr`, `fr`, …
- Read-only: it never creates, changes, or deletes anything in Cebelca.

## Setup

Run `./install.sh invoice invoices-download` in the repo root (see
[Install](../README.md#install)). This skill needs [`invoice`](../invoice): all
API calls go through that skill's `cebelca.sh`, so the token lives in one place.

Requires `curl` and `python3` (standard library only).

## Usage

Ask Claude in plain language, or run the script yourself:

```bash
bash ~/.claude/skills/invoices-download/download.sh                  # previous month
bash ~/.claude/skills/invoices-download/download.sh 2026-07          # July 2026
bash ~/.claude/skills/invoices-download/download.sh 2026-07 lang=en  # English PDFs
bash ~/.claude/skills/invoices-download/download.sh 2026-07 out=~/Desktop/july
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Instructions Claude follows |
| `download.sh` | Picks the month and folder, then lists and downloads via `../invoice/cebelca.sh` |
