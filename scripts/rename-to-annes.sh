#!/data/data/com.termux/files/usr/bin/bash
# Anne's Office rename, end to end, from Termux (any bash with git, python3 and the GitHub CLI works):
# clones or updates the nine repositories, rewrites their display names with rename-to-annes.py,
# commits and pushes, then renames the GitHub descriptions and topics.
#
#   pkg install -y git python gh
#   gh auth login            # GitHub.com, HTTPS, log in with a browser; grant the "repo" scope
#   gh auth setup-git
#   bash rename-to-annes.sh --dry-run    # show what would change, touch nothing on GitHub
#   bash rename-to-annes.sh              # do it
#
# Environment: OWNER (socrtwo), WORK (~/annes-office: where the clones live), BRANCH (main: the branch
# to rewrite and push), SCRIPT_URL (where to fetch rename-to-annes.py from when the QuillOffice
# checkout does not carry it yet). Safe to re-run: a repository with nothing left to rename is skipped.
set -euo pipefail
OWNER="${OWNER:-socrtwo}"
WORK="${WORK:-$HOME/annes-office}"
BRANCH="${BRANCH:-main}"
SCRIPT_URL="${SCRIPT_URL:-https://raw.githubusercontent.com/$OWNER/QuillOffice/ccr-31d52d9f-rrlwpd/scripts/rename-to-annes.py}"
REPOS=(QuillOffice QuillPen QuillGrid QuillPost QuillStage QuillLoom QuillPress QuillFolio QuillTest)
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

mkdir -p "$WORK"; cd "$WORK"
echo "== Clones in $WORK (branch $BRANCH)"
for r in "${REPOS[@]}"; do
  if [ -d "$r/.git" ]; then
    git -C "$r" fetch -q origin "$BRANCH"
    git -C "$r" checkout -q "$BRANCH"
    git -C "$r" pull -q --ff-only origin "$BRANCH"
  else
    git clone -q "https://github.com/$OWNER/$r.git"
    git -C "$r" checkout -q "$BRANCH"
  fi
  echo "✓ $r"
done

SCRIPT="$WORK/QuillOffice/scripts/rename-to-annes.py"
if [ ! -f "$SCRIPT" ]; then
  SCRIPT="$WORK/rename-to-annes.py"
  curl -fsSL "$SCRIPT_URL" -o "$SCRIPT"
  echo "✓ fetched rename-to-annes.py"
fi

echo "== Rewriting display names"
args=(); [ $DRY = 1 ] && args+=(--dry-run)
python3 "$SCRIPT" "${args[@]}" "${REPOS[@]}"
[ $DRY = 1 ] && { echo "Dry run: nothing committed, pushed or changed on GitHub."; exit 0; }

# docs/COMMANDS.md lists commands alphabetically, so renamed labels change its order: regenerate it
# where the dependencies are installed (npm ci first), otherwise say so.
echo "== Command catalogs"
for r in QuillPen QuillGrid QuillStage QuillFolio; do
  if [ -d "$r/node_modules" ]; then (cd "$r" && npm run -s catalog) && echo "✓ $r catalog regenerated"
  else echo "· $r: run 'npm ci && npm run catalog' in $WORK/$r later (its test checks docs/COMMANDS.md is current)"; fi
done

# Commit identity: the global git config, else the GitHub login.
if ! git config --global user.email >/dev/null; then
  login="$(gh api user --jq .login)"
  git config --global user.name "$login"
  git config --global user.email "$(gh api user --jq .id)+$login@users.noreply.github.com"
fi

echo "== Committing and pushing"
for r in "${REPOS[@]}"; do
  if [ -z "$(git -C "$r" status --porcelain)" ]; then echo "· $r: nothing to rename"; continue; fi
  git -C "$r" add -A
  git -C "$r" commit -q -m "Rename the suite's display names from Quill to Anne's" \
    -m "Quill Office is now Anne's Office, QuillPen is Anne's Pen, and so on for Grid, Post, Stage, Loom, Press, Folio and Test, everywhere a name is shown or read as metadata. Identifiers (repository names and URLs, package and bundle ids, MIME types, release file names, executables, storage keys, the embed protocol) are unchanged. Done with QuillOffice/scripts/rename-to-annes.py."
  git -C "$r" push -q origin "$BRANCH"
  echo "✓ $r pushed"
done

echo "== GitHub descriptions and topics"
for r in "${REPOS[@]}"; do
  desc="$(gh repo view "$OWNER/$r" --json description --jq .description | python3 "$SCRIPT" --stdin)"
  topics="$(gh repo view "$OWNER/$r" --json repositoryTopics --jq '[.repositoryTopics[]?.name]|join(",")')"
  args=(repo edit "$OWNER/$r" --description "$desc")
  case ",$topics," in *,quill-suite,*) args+=(--remove-topic quill-suite);; esac
  case ",$topics," in *,annes-office-suite,*) ;; *) args+=(--add-topic annes-office-suite);; esac
  gh "${args[@]}" >/dev/null
  echo "✓ $r: $desc"
done
# Repositories that carry a full metadata file set every topic from it.
for r in QuillOffice QuillFolio; do
  [ -f "$WORK/$r/scripts/set-repo-metadata.sh" ] && REPO="$OWNER/$r" bash "$WORK/$r/scripts/set-repo-metadata.sh"
done
echo "Done."
