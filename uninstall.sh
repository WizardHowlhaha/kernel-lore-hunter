#!/usr/bin/env bash
# uninstall.sh -- remove the kernel-lore-hunter skill from every agent.
#
# Removes the symlinks this skill installed and, with --purge, the canonical
# copy as well. Real directories are never deleted unless --purge is given.
#
# Usage:
#   ./uninstall.sh                 # remove agent links only
#   ./uninstall.sh --purge         # also delete the canonical copy
#   ./uninstall.sh --scope project --project-dir ~/work/linux-mm

set -euo pipefail

SKILL_NAME="kernel-lore-hunter"
SCOPE="user"
PROJECT_DIR="$PWD"
PURGE=0
DRY_RUN=0

say()  { printf '%s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
uninstall.sh -- remove the kernel-lore-hunter skill from every agent.

Options:
      --scope <scope>   user (default) or project.
      --project-dir <p> Project root for --scope project (default: current dir).
      --purge           Also delete the canonical copy of the skill.
      --dry-run         Print the plan without changing anything.
  -h, --help           Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)       SCOPE="${2:?--scope needs user or project}"; shift 2 ;;
    --project-dir) PROJECT_DIR="${2:?--project-dir needs a path}"; shift 2 ;;
    --purge)       PURGE=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "error: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$SCOPE" == "user" ]]; then
  BASE="$(cd "$HOME" && pwd -P)"
  CANONICAL="$BASE/.agents/skills/$SKILL_NAME"
else
  BASE="$(cd "$PROJECT_DIR" && pwd -P)"
  CANONICAL="$BASE/.agents/skills/$SKILL_NAME"
fi

AGENTS=(
  "claude-code|$BASE/.claude/skills|.claude/skills"
  "codex|$BASE/.codex/skills|.codex/skills"
  "cursor|$BASE/.cursor/skills|.cursor/skills"
  "gemini-cli|$BASE/.gemini/skills|.gemini/skills"
  "opencode|$BASE/.config/opencode/skills|.opencode/skills"
  "github-copilot|$BASE/.copilot/skills|.github/skills"
  "windsurf|$BASE/.windsurf/skills|.windsurf/skills"
  "cline|$BASE/.cline/skills|.cline/skills"
  "goose|$BASE/.goose/skills|.goose/skills"
)

echo "kernel-lore-hunter uninstaller"
echo "  scope     : $SCOPE"
echo "  canonical : $CANONICAL"
echo ""

removed=0
for row in "${AGENTS[@]}"; do
  IFS='|' read -r aid upath ppath <<<"$row"
  if [[ "$SCOPE" == "user" ]]; then parent="$upath"; else parent="$BASE/$ppath"; fi
  target="$parent/$SKILL_NAME"
  if [[ -L "$target" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "  would unlink $target"
    else
      # unlink, not rm: it refuses to touch a real directory
      unlink "$target"
      echo "  unlinked  $target"
    fi
    removed=$((removed + 1))
  elif [[ -e "$target" ]]; then
    echo "  ! $target is a real directory -- left alone (remove it by hand if you want)"
  fi
done

if [[ $PURGE -eq 1 ]]; then
  if [[ -d "$CANONICAL" ]]; then
    # Safety gate: only ever delete a directory that really is this skill.
    if [[ ! -f "$CANONICAL/SKILL.md" ]] \
       || ! grep -q '^name: *kernel-lore-hunter' "$CANONICAL/SKILL.md" 2>/dev/null; then
      warn "$CANONICAL does not look like the kernel-lore-hunter skill -- left alone"
    elif [[ $DRY_RUN -eq 1 ]]; then
      echo "  would purge $CANONICAL"
    else
      rm -rf "$CANONICAL"
      echo "  purged    $CANONICAL"
    fi
  else
    echo "  canonical not present, nothing to purge"
  fi
else
  echo "  canonical kept at $CANONICAL (use --purge to delete it)"
fi

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo "dry run -- nothing was changed."
else
  echo "done ($removed link(s) removed). restart your agent to drop the skill."
fi
