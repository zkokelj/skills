# Skills

A growing collection of [Claude Code](https://claude.com/claude-code) skills that
I use for my own work. Each one teaches Claude a specific job, like issuing an
invoice, and runs local scripts to do it.

Skills are grouped by category. For now there's one category, invoicing. I'll
add new skills and categories as I build them, so check the list below or run
`./install.sh --list`. Install everything, or pick only the skills you need.

## Skills

### [invoicing](skills/invoicing)

| Skill | What it does |
|-------|--------------|
| [`invoice`](skills/invoicing/invoice) | Create, issue, and pay invoices via the Cebelca.biz / InvoiceFox API |
| [`invoices-download`](skills/invoicing/invoices-download) | Download every issued invoice for a month as PDFs |

## Install

```bash
git clone https://github.com/zkokelj/skills.git && cd skills
./install.sh                          # every skill
./install.sh invoice invoices-download # only these
./install.sh --list                   # what's in the repo
```

Each skill is copied to `~/.claude/skills/<name>/`, where Claude Code finds it.
A skill's `setup.sh`, if it has one, runs straight after and may ask for an API
token. Re-run `install.sh` any time to update. It never overwrites a saved token
or `config.sh`. Set `CLAUDE_SKILLS_DIR` to install somewhere else.

Requires macOS or Linux and `bash`. Each skill's README lists anything else it
needs.

## Layout

```
skills/
  <category>/
    README.md          overview, setup, and shared docs for the category
    <skill>/
      SKILL.md         instructions Claude follows (frontmatter: name, description)
      README.md        for humans
      *.sh             scripts the skill runs
      setup.sh         optional: run by install.sh, not installed
install.sh             installs skills into ~/.claude/skills/
```

## Adding a skill

1. Create `skills/<category>/<name>/SKILL.md`. The folder name must match the
   `name:` in the frontmatter and be unique across all categories, because
   skills install flat into `~/.claude/skills/<name>/`.
2. In `SKILL.md`, call scripts by their installed path,
   `~/.claude/skills/<name>/<script>`, so permission allowlists match.
3. Keep secrets out of the repo: a skill reads them from `.token` or `config.sh`
   in its installed folder. Both names are git-ignored and never copied by
   `install.sh`. Commit a `config.example.sh` instead.
4. If the skill needs a token or other one-time setup, add a `setup.sh`. It
   gets the installed folder as `$1`.
5. Add a row to the table above, and to the category README.
