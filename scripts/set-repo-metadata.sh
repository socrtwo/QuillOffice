#!/usr/bin/env bash
# Set the GitHub repository's description, homepage and topics from QuillOffice.meta.json.
# Needs git, node and the GitHub CLI logged in with "repo" scope:
#   gh auth login
#   bash scripts/set-repo-metadata.sh            # apply
#   bash scripts/set-repo-metadata.sh --dry-run  # only print the gh commands
# The topics end up exactly as listed in the file: missing ones are added, others removed.
# Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="${REPO:-socrtwo/QuillOffice}"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

field() { node -e "const m=JSON.parse(require('fs').readFileSync('QuillOffice.meta.json','utf8'));const v=m[process.argv[1]];process.stdout.write(Array.isArray(v)?v.join(','):String(v??''))" "$1"; }
DESC="$(field description)"
HOME_URL="$(field homepage)"
TOPICS="$(field topics)"

CURRENT=""
if [ $DRY -eq 0 ]; then
  CURRENT="$(gh repo view "$REPO" --json repositoryTopics --jq '[.repositoryTopics[]?.name]|join(",")' 2>/dev/null || true)"
fi
REMOVE="$(node -e "const want=new Set(process.argv[1].split(','));console.log(process.argv[2].split(',').filter(t=>t&&!want.has(t)).join(','))" "$TOPICS" "$CURRENT")"

args=(repo edit "$REPO" --description "$DESC" --homepage "$HOME_URL" --add-topic "$TOPICS")
[ -n "$REMOVE" ] && args+=(--remove-topic "$REMOVE")

if [ $DRY -eq 1 ]; then
  printf 'gh'; printf ' %q' "${args[@]}"; echo
  exit 0
fi
gh "${args[@]}"
echo "✓ $REPO: description, homepage and $(echo "$TOPICS" | tr ',' '\n' | wc -l | tr -d ' ') topics set${REMOVE:+ (removed: $REMOVE)}"
