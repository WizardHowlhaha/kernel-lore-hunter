#!/usr/bin/env bash
# install.sh -- install the kernel-lore-hunter skill for one or many AI agents.
#
# The skill is a single directory (SKILL.md + scripts/ + references/) that every
# agent that follows the Agent Skills standard can read. This script keeps ONE
# canonical copy and points each agent at it with a symlink, so updating the
# skill updates every agent at once.
#
# Usage:
#   ./install.sh                          # user scope, every detected agent
#   ./install.sh -a claude-code -a cursor # only these agents
#   ./install.sh --scope project          # into ./.agents/skills + ./.claude/skills
#   ./install.sh --copy                   # copy files instead of symlinking
#   ./install.sh --dry-run                # show what would happen, change nothing
#
# See ./install.sh --help for the full list.

set -euo pipefail

SKILL_NAME="kernel-lore-hunter"

# ------------------------------------------------------------------ defaults
SCOPE="user"
PROJECT_DIR="$PWD"
TARGETS=()
COPY_MODE=0
DRY_RUN=0
REPO=""
DEST=""
FORCE=0

# ------------------------------------------------------------------- helpers
say()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
install.sh -- install the kernel-lore-hunter skill for one or many AI agents.

Usage:
  ./install.sh [options]

Options:
  -a, --agent <name>   Install only for this agent. Repeatable.
                        Names: claude-code, codex, cursor, gemini-cli, opencode,
                               github-copilot, windsurf, cline, goose, amp, universal
      --scope <scope>   user (default) or project.
      --project-dir <p> Project root for --scope project (default: current dir).
      --copy            Copy files instead of symlinking (fork-friendly).
      --repo <owner/repo>
                        Install from a GitHub repo instead of this directory.
      --dest <dir>      Canonical location for the skill (default: ~/.agents/skills/<name>)
      --force           Replace an existing non-symlink installation.
      --dry-run         Print the plan without changing anything.
  -h, --help           Show this help.

Agent detection:
  By default every agent whose config directory exists on this machine is
  installed. The universal location ~/.agents/skills/ is always populated.

Examples:
  ./install.sh
  ./install.sh -a claude-code -a codex
  ./install.sh --scope project --project-dir ~/work/linux-mm
  ./install.sh --copy
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--agent)     TARGETS+=("${2:?--agent needs a name}"); shift 2 ;;
    --scope)        SCOPE="${2:?--scope needs user or project}"; shift 2 ;;
    --project-dir)  PROJECT_DIR="${2:?--project-dir needs a path}"; shift 2 ;;
    --copy)         COPY_MODE=1; shift ;;
    --repo)         REPO="${2:?--repo needs owner/repo}"; shift 2 ;;
    --dest)         DEST="${2:?--dest needs a path}"; shift 2 ;;
    --force)        FORCE=1; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "unknown option: $1 (try --help)" ;;
  esac
done

case "$SCOPE" in
  user|project) ;;
  *) die "--scope must be 'user' or 'project'" ;;
esac

# ------------------------------------------------------------------- layout
# HOME_BASE is where the agents actually live -- detection always looks here,
# even for a project-scope install (the project may be cloned by a teammate
# who runs a different agent).
HOME_BASE="$(cd "$HOME" 2>/dev/null && pwd -P)" || die "HOME is not accessible: $HOME"

if [[ "$SCOPE" == "user" ]]; then
  BASE="$HOME_BASE"
  CANONICAL="${DEST:-$BASE/.agents/skills/$SKILL_NAME}"
else
  BASE="$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P)" || die "project dir not found: $PROJECT_DIR"
  CANONICAL="${DEST:-$BASE/.agents/skills/$SKILL_NAME}"
fi

# id | user-scope skills dir | project-scope skills dir | detection dir (always HOME)
AGENTS=(
  "claude-code|$HOME_BASE/.claude/skills|.claude/skills|$HOME_BASE/.claude"
  "codex|$HOME_BASE/.codex/skills|.codex/skills|$HOME_BASE/.codex"
  "cursor|$HOME_BASE/.cursor/skills|.cursor/skills|$HOME_BASE/.cursor"
  "gemini-cli|$HOME_BASE/.gemini/skills|.gemini/skills|$HOME_BASE/.gemini"
  "opencode|$HOME_BASE/.config/opencode/skills|.opencode/skills|$HOME_BASE/.config/opencode"
  "github-copilot|$HOME_BASE/.copilot/skills|.github/skills|$HOME_BASE/.copilot"
  "windsurf|$HOME_BASE/.windsurf/skills|.windsurf/skills|$HOME_BASE/.windsurf"
  "cline|$HOME_BASE/.cline/skills|.cline/skills|$HOME_BASE/.cline"
  "goose|$HOME_BASE/.goose/skills|.goose/skills|$HOME_BASE/.goose"
)

# ------------------------------------------------------------------- source
SRC=""
CLEANUP_SRC=""
if [[ -n "$REPO" ]]; then
  command -v git >/dev/null 2>&1 || die "git is required to install from --repo"
  CLEANUP_SRC="$(mktemp -d)"
  say ">> cloning $REPO"
  git clone --depth=1 -q "https://github.com/$REPO.git" "$CLEANUP_SRC/src" \
    || die "failed to clone $REPO"
  SRC="$CLEANUP_SRC/src"
else
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  [[ -f "$SRC/SKILL.md" ]] || die "no SKILL.md next to this script -- run it from the repo, or use --repo"
fi
cleanup() { [[ -n "$CLEANUP_SRC" && -d "$CLEANUP_SRC" ]] && rm -rf "$CLEANUP_SRC"; return 0; }
trap cleanup EXIT

# ------------------------------------------------------------------ helpers
abspath() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }

install_payload() {
  # $1 = source root, $2 = destination root
  local src="$1" dst="$2"
  mkdir -p "$dst"
  local item
  for item in SKILL.md scripts references assets LICENSE README.md; do
    [[ -e "$src/$item" ]] || continue
    rm -rf "$dst/$item"
    cp -R "$src/$item" "$dst/$item"
  done
  # executables keep their bit
  if [[ -d "$dst/scripts" ]]; then
    chmod +x "$dst/scripts"/* 2>/dev/null || true
  fi
}

link_agent() {
  # $1 = agent id, $2 = parent skills dir
  local id="$1" parent="$2"
  local target="$parent/$SKILL_NAME"
  local created=""

  if [[ -L "$target" ]]; then
    local current
    current="$(readlink "$target")"
    if [[ "$current" == "$CANONICAL" ]]; then
      info "$id: already linked"
      return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
      info "$id: would relink $target -> $CANONICAL"
      return 0
    fi
    rm -f "$target" 2>/dev/null || unlink "$target" 2>/dev/null || true
    created="relinked"
  elif [[ -e "$target" ]]; then
    if [[ $FORCE -eq 1 ]]; then
      local backup="$target.bak.$(date +%Y%m%d%H%M%S)"
      if [[ $DRY_RUN -eq 1 ]]; then
        info "$id: would back up $target and replace it"
        return 0
      fi
      mv "$target" "$backup"
      warn "$id: existing installation moved to $backup"
      created="replaced"
    else
      warn "$id: $target exists and is not a symlink -- skipped (use --force to replace)"
      return 1
    fi
  else
    created="linked"
  fi

  # Nothing above this line may touch the filesystem in dry-run mode.
  if [[ $DRY_RUN -eq 1 ]]; then
    info "$id: would link $target -> $CANONICAL"
    return 0
  fi

  if ! mkdir -p "$parent" 2>/dev/null; then
    warn "$id: cannot create $parent -- skipped (permissions?)"
    return 1
  fi
  if ! ln -s "$CANONICAL" "$target" 2>/dev/null; then
    warn "$id: cannot create the symlink at $target -- skipped"
    return 1
  fi
  info "$id: $created $target"
}

# -------------------------------------------------------------------- plan
say "kernel-lore-hunter installer"
say "  scope     : $SCOPE"
say "  canonical : $CANONICAL"
say "  source    : $SRC"
say "  mode      : $([[ $COPY_MODE -eq 1 ]] && echo copy || echo symlink)"
say ""

# 1. canonical copy
if [[ "$(abspath "$SRC")" == "$(abspath "$CANONICAL" 2>/dev/null || echo "$CANONICAL")" ]]; then
  info "canonical: already in place (running from the installed copy)"
else
  if [[ $DRY_RUN -eq 1 ]]; then
    info "canonical: would copy skill payload into $CANONICAL"
  else
    install_payload "$SRC" "$CANONICAL" || die "could not write the canonical copy at $CANONICAL"
    info "canonical: skill payload installed"
  fi
fi
say ""

# 2. per-agent links
installed=()
if [[ ${#TARGETS[@]} -gt 0 ]]; then
  # explicit targets: install regardless of detection
  for id in "${TARGETS[@]}"; do
    found=""
    for row in "${AGENTS[@]}"; do
      IFS='|' read -r aid upath ppath _ <<<"$row"
      [[ "$aid" == "$id" ]] && found="$row" && break
    done
    case "$id" in
      universal|amp)
        info "$id: served by the canonical location -- nothing to link"
        installed+=("$id")
        continue ;;
    esac
    [[ -n "$found" ]] || die "unknown agent: $id (try --help for the list)"
    IFS='|' read -r aid upath ppath _ <<<"$found"
    if [[ "$SCOPE" == "user" ]]; then parent="$upath"; else parent="$BASE/$ppath"; fi
    if link_agent "$id" "$parent"; then installed+=("$id"); fi
  done
else
  if [[ "$SCOPE" == "user" ]]; then
    say "detected agents:"
  else
    say "agents (a project-scope install covers every agent, whoever clones it):"
  fi
  for row in "${AGENTS[@]}"; do
    IFS='|' read -r aid upath ppath detect <<<"$row"
    if [[ "$SCOPE" == "user" && ! -d "$detect" ]]; then
      info "$aid: not detected (skipped)"
      continue
    fi
    if [[ "$SCOPE" == "user" ]]; then parent="$upath"; else parent="$BASE/$ppath"; fi
    if link_agent "$aid" "$parent"; then installed+=("$aid"); fi
  done
fi

# 3. verify
say ""
if [[ $DRY_RUN -eq 1 ]]; then
  say "dry run -- nothing was changed."
  exit 0
fi

say "verification:"
ok=1
for row in "${AGENTS[@]}"; do
  IFS='|' read -r aid upath ppath _ <<<"$row"
  [[ " ${installed[*]} " == *" $aid "* ]] || continue
  if [[ "$SCOPE" == "user" ]]; then parent="$upath"; else parent="$BASE/$ppath"; fi
  if [[ -r "$parent/$SKILL_NAME/SKILL.md" ]]; then
    info "$aid: SKILL.md reachable"
  else
    warn "$aid: SKILL.md NOT reachable at $parent/$SKILL_NAME/SKILL.md"
    ok=0
  fi
done
if [[ -r "$CANONICAL/SKILL.md" ]]; then
  info "universal ($CANONICAL): SKILL.md reachable"
else
  warn "universal: SKILL.md NOT reachable at $CANONICAL/SKILL.md"
  ok=0
fi

say ""
if [[ $ok -eq 1 ]]; then
  say "installed for: ${installed[*]:-none}"
  say ""
  say "Next steps:"
  say "  * restart your agent so it picks the skill up"
  say "  * verify:  bash $CANONICAL/scripts/selftest.sh"
  say "  * try it:  \"find the kernel patchset behind <article/commit>\""
else
  warn "some links did not resolve -- check the paths above"
  exit 1
fi
