#!/usr/bin/env bash
# Default Claude Code status line.
# Renders: [Model] 📁 folder | NN% ctx | 🌿 branch
# Install: cp to ~/.claude/statusline.sh, chmod +x, reference in settings.json.

set -u

input=$(cat)

MODEL=$(jq -r '.model.display_name // "Claude"' <<<"$input")
DIR=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
PCT=$(jq -r '.context_window.used_percentage // 0' <<<"$input" | cut -d. -f1)

BRANCH=""
if [ -n "$DIR" ] && git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  B=$(git -C "$DIR" branch --show-current 2>/dev/null)
  [ -n "$B" ] && BRANCH=" | 🌿 $B"
fi

FOLDER="${DIR##*/}"
[ -z "$FOLDER" ] && FOLDER="(no dir)"

echo "[$MODEL] 📁 $FOLDER | ${PCT}% ctx${BRANCH}"
