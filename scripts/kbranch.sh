#!/usr/bin/env bash
# kbranch.sh -- inspect a kernel branch without fighting cgit's Anubis wall.
#
# Two modes, because speed matters:
#   * default  : git ls-remote + GitHub REST API (seconds) -- works for trees
#                that have a GitHub mirror (torvalds/linux does)
#   * --git    : shallow `git fetch` (authoritative, but minutes on linux.git:
#                the pack is huge). Use it for trees with no mirror, and run it
#                in the background.
#
# Usage:
#   kbranch.sh <repo-url> <branch> [commits]
#   kbranch.sh --list <repo-url> 'refs/heads/*rcu*'
#   kbranch.sh --git <repo-url> <branch> [depth]
#   KB_GH=owner/repo kbranch.sh <repo-url> <branch>      # force a mirror
#
# Examples:
#   kbranch.sh https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git rcu-free-v3 12
#   kbranch.sh --list https://git.kernel.org/pub/scm/linux/kernel/git/kas/linux.git 'refs/heads/*rcu*'

set -euo pipefail

usage() {
  cat <<'EOF'
kbranch.sh -- inspect a kernel branch without fighting cgit's Anubis wall.

Usage:
  kbranch.sh <repo-url> <branch> [commits]      ls-remote + GitHub API (fast)
  kbranch.sh --list <repo-url> 'refs/heads/*kw*' list matching branches
  kbranch.sh --git  <repo-url> <branch> [depth]  shallow fetch (slow, authoritative)

Environment:
  KB_GH=owner/repo   force a specific GitHub mirror (default: torvalds/linux)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
[[ $# -ge 2 ]] || { usage; exit 2; }

mode="api"
if [[ "$1" == "--list" ]]; then
  git ls-remote --heads "${2:?repo url}" "${3:-refs/heads/*}"
  exit 0
fi
if [[ "$1" == "--git" ]]; then
  mode="git"; shift
fi

repo="$1"; branch="$2"; n="${3:-10}"

# ---------------------------------------------------------------- tip + branch
tip="$(git ls-remote "$repo" "refs/heads/$branch" | awk '{print $1}')"
if [[ -z "$tip" ]]; then
  echo "!! branch '$branch' not found in $repo" >&2
  echo "   try: $0 --list $repo 'refs/heads/*'" >&2
  exit 1
fi
echo "== $branch =="
echo "tip: $tip"
echo "    $repo  (web log is behind Anubis; use the API/git below)"

# ---------------------------------------------------------------- GitHub fast path
gh="${KB_GH:-}"
if [[ -z "$gh" && "$repo" == *torvalds/linux* ]]; then gh="torvalds/linux"; fi

if [[ "$mode" == "api" && -n "$gh" ]]; then
  # The GitHub mirror only carries master, so side branches have no objects
  # there: ask for the tip commit by SHA and walk parents on success.
  python3 - "$gh" "$tip" "$n" <<'PY'
import json, sys, urllib.error, urllib.request

gh, sha, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
tip = sha


def api(s):
    req = urllib.request.Request(
        "https://api.github.com/repos/%s/commits/%s" % (gh, s),
        headers={"Accept": "application/vnd.github+json", "User-Agent": "kbranch"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


first = None
try:
    for _ in range(n):
        c = api(sha)
        if first is None:
            first = c
        m = c["commit"]
        print("%s  %s  %s" % (c["sha"][:10], m["committer"]["date"][:10],
                              m["author"]["name"]))
        print("    " + m["message"].split("\n")[0])
        if not c.get("parents"):
            break
        sha = c["parents"][0]["sha"]
except urllib.error.HTTPError:
    if first is None:
        print("!! %s is not on the GitHub mirror (%s): side branches are not mirrored."
              % (tip, gh), file=sys.stderr)
        print("   use --git (shallow fetch; minutes on linux.git - run it in the background)",
              file=sys.stderr)
        print("   or read the cover letter from lore instead.", file=sys.stderr)
        sys.exit(1)

print()
print("== tip commit message (cover letter when the commit is empty) ==")
print(first["commit"]["message"].strip())
PY
  exit 0
fi

# ---------------------------------------------------------------- git fallback
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q repo
cd "$tmp/repo"
git remote add origin "$repo"
echo "!! shallow-fetching (this can take minutes on linux.git) ..." >&2
if ! git fetch -q --depth="$n" origin "refs/heads/$branch" 2>/dev/null; then
  git fetch -q --depth="$n" origin "$branch"
fi

echo
git log --format='%h  %ad  %an%n    %s' --date=short -n "$n" FETCH_HEAD
echo
echo "== tip commit message (cover letter when the commit is empty) =="
git log -1 --format='%B' FETCH_HEAD
if [[ -z "$(git show --stat --format='' FETCH_HEAD)" ]]; then
  echo
  echo ">> note: the tip commit is EMPTY -- it is a cover letter, not a patch."
fi
