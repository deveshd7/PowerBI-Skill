#!/usr/bin/env bash
set -e

TARGET="${1:-.}"
VERSION="4.0.0"
BASE="https://raw.githubusercontent.com/deveshd7/PowerBI-Skill/main"

echo ""
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║                                                   ║"
echo "  ║   ██████  ██████  ██                              ║"
echo "  ║   ██   ██ ██   ██ ██                              ║"
echo "  ║   ██████  ██████  ██      Power BI DAX Co-pilot   ║"
echo "  ║   ██      ██   ██ ██      for Claude Code         ║"
echo "  ║   ██      ██████  ██                              ║"
echo "  ║                                          v$VERSION   ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo ""

mkdir -p "$TARGET/.claude/skills/pbi/commands" "$TARGET/.claude/skills/pbi/shared"

echo "  [1/3] Downloading skill router..."
curl -sL "$BASE/.claude/skills/pbi/SKILL.md" -o "$TARGET/.claude/skills/pbi/SKILL.md"

echo "  [2/3] Downloading commands..."
commands=(explain format optimise comment error new load audit diff commit edit undo comment-batch changelog extract help)
total=${#commands[@]}
i=0
for cmd in "${commands[@]}"; do
  i=$((i + 1))
  pct=$((i * 100 / total))
  filled=$((pct / 5))
  empty=$((20 - filled))
  bar=$(printf '%0.s=' $(seq 1 $filled 2>/dev/null) 2>/dev/null || true)
  space=$(printf '%0.s ' $(seq 1 $empty 2>/dev/null) 2>/dev/null || true)
  printf "\r        [%-20s] %d/%d  " "$bar" "$i" "$total"
  curl -sL "$BASE/.claude/skills/pbi/commands/$cmd.md" -o "$TARGET/.claude/skills/pbi/commands/$cmd.md"
done
echo ""

echo "  [3/3] Downloading shared resources..."
curl -sL "$BASE/.claude/skills/pbi/shared/api-notes.md" -o "$TARGET/.claude/skills/pbi/shared/api-notes.md"

resolved=$(cd "$TARGET/.claude/skills/pbi" && pwd)
echo ""
echo "  Installed to: $resolved"
echo ""
echo "  Ready! Open Claude Code and type /pbi to get started."
echo ""
