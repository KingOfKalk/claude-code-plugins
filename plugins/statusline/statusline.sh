#!/bin/bash
input=$(cat)

# Extract fields from JSON stdin
MODEL=$(echo "$input" | jq -r '.model.display_name // "loading..."')
CWD=$(echo "$input" | jq -r '.cwd // "~"')
DIR="${CWD##*/}"
REMAINING=$(echo "$input" | jq -r '.context_window.remaining_percentage // 100' | cut -d. -f1)
STYLE=$(echo "$input" | jq -r '.output_style.name // "normal"')

# Git branch + dirty state (fast, direct git calls)
BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "none")
DIRTY=""
if [ "$BRANCH" != "none" ]; then
  if ! git -C "$CWD" diff --quiet HEAD 2>/dev/null; then
    DIRTY='\033[31m!\033[0m'
  elif [ -n "$(git -C "$CWD" ls-files --others --exclude-standard 2>/dev/null)" ]; then
    DIRTY='\033[31m!\033[0m'
  fi
fi

# Colors
CYAN='\033[36m'
GREEN='\033[32m'
MAGENTA='\033[35m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# Context color: green > 50%, yellow > 20%, red <= 20%
if [ "$REMAINING" -le 20 ]; then
  CTX_COLOR='\033[31m'
elif [ "$REMAINING" -le 50 ]; then
  CTX_COLOR='\033[33m'
else
  CTX_COLOR='\033[32m'
fi

# Progress bar (10 chars, based on remaining %)
USED=$((100 - REMAINING))
FILLED=$((USED / 10))
EMPTY=$((10 - FILLED))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="█"; done
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done

echo -e "${CYAN}${MODEL}${RESET}  ${GREEN}${DIR}${RESET}  ${MAGENTA}${BRANCH}${DIRTY}${RESET}  ${CTX_COLOR}${BAR} ${USED}%${RESET}  ${BLUE}${STYLE}${RESET}"
