#!/usr/bin/env bash
#
# install.sh — install skills from this repo into ~/.claude/skills/.
#
#   ./install.sh                  install every skill
#   ./install.sh invoice ...      install only the named skills
#   ./install.sh --list           list the skills in this repo
#
# Skills live in skills/<category>/<name>/ (any folder with a SKILL.md) and are
# installed flat to ~/.claude/skills/<name>/, the path their SKILL.md refers to.
# A skill's optional setup.sh runs after it is copied, with the installed folder
# as its argument (e.g. to ask for an API token); it is not itself installed.
#
# Safe to re-run: it refreshes skill files and never touches local secrets
# (.token, config.sh) in an installed skill. Set CLAUDE_SKILLS_DIR to install
# somewhere else.
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

# Every skill folder, as "<name> <path>" lines, sorted by name.
skills="$(find "$SRC/skills" -mindepth 3 -maxdepth 3 -name SKILL.md -print \
  | while read -r f; do d="$(dirname "$f")"; echo "$(basename "$d") $d"; done | sort)"

dupes="$(echo "$skills" | cut -d' ' -f1 | uniq -d)"
if [ -n "$dupes" ]; then
  echo "ERROR: skill names must be unique across categories: $dupes" >&2
  exit 1
fi

if [ "${1:-}" = "--list" ]; then
  echo "$skills" | while read -r name dir; do
    printf '%-24s %s\n' "$name" "${dir#"$SRC"/}"
  done
  exit 0
fi

# Pick the requested skills, or all of them.
selected="$skills"
if [ "$#" -gt 0 ]; then
  selected=""
  for want in "$@"; do
    line="$(echo "$skills" | awk -v n="$want" '$1 == n')"
    if [ -z "$line" ]; then
      echo "ERROR: no skill named '$want'. See ./install.sh --list" >&2
      exit 1
    fi
    selected="$selected$line"$'\n'
  done
fi

# The list is read on fd 3 so stdin stays the terminal for setup.sh prompts.
while read -r name dir <&3; do
  [ -n "$name" ] || continue
  mkdir -p "$DEST/$name"
  # Copy the skill's files, never local secrets or the setup hook.
  (cd "$dir" && find . -type f ! -name .token ! -name config.sh ! -name setup.sh \
                 ! -name .DS_Store -print) \
    | while read -r f; do
        mkdir -p "$DEST/$name/$(dirname "$f")"
        cp "$dir/$f" "$DEST/$name/$f"
        if [ -x "$dir/$f" ]; then chmod +x "$DEST/$name/$f"; fi
      done
  echo "Installed $name → $DEST/$name"
  if [ -f "$dir/setup.sh" ]; then
    bash "$dir/setup.sh" "$DEST/$name"
  fi
done 3<<< "$selected"
