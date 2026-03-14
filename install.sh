#!/usr/bin/env bash
set -e

TARGET="${1:-.}"
BASE="https://raw.githubusercontent.com/deveshd7/PowerBI-Skill/main"

echo ""
echo "  Installing PBI-SKILL v3.0..."
echo ""

mkdir -p "$TARGET/.claude/skills/pbi/commands" "$TARGET/.claude/skills/pbi/shared"

curl -sL "$BASE/.claude/skills/pbi/SKILL.md" -o "$TARGET/.claude/skills/pbi/SKILL.md"

for cmd in explain format optimise comment error new load audit diff commit edit undo comment-batch changelog; do
  curl -sL "$BASE/.claude/skills/pbi/commands/$cmd.md" -o "$TARGET/.claude/skills/pbi/commands/$cmd.md"
done

curl -sL "$BASE/.claude/skills/pbi/shared/api-notes.md" -o "$TARGET/.claude/skills/pbi/shared/api-notes.md"

echo "  Done! Open Claude Code and type /pbi to get started."
echo ""
