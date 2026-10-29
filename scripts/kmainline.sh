#!/usr/bin/env bash
# kmainline.sh -- is a symbol / subject already in mainline?
#
# cgit search is bot-walled, so use the GitHub mirror's commit search API.
# Caveat: the API tokenises commit messages, so a merge commit whose body
# merely mentions the word can show up. Merge hits are flagged below.
#
# Set GITHUB_TOKEN to raise the rate limit: the commit *search* API allows
# 10 requests/minute unauthenticated (30 with a token), the core API 60/hour
# (5000 with a token).
#
# Usage:
#   kmainline.sh <symbol-or-subject> [author-email-or-name]
#   kmainline.sh PG_rcu_free
#   kmainline.sh "read from the page cache without folio references"

set -euo pipefail

usage() {
  cat <<'EOF'
kmainline.sh -- is a symbol / subject already in mainline?

Usage:
  kmainline.sh <symbol-or-subject> [author-email-or-name]

Examples:
  kmainline.sh PG_rcu_free
  kmainline.sh "read from the page cache without folio references"

A total_count of 0 means "not in mainline" and is trustworthy.
A hit that looks like a Merge/Revert commit is a tokenised false positive --
re-run with the exact subject in quotes before believing it.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
[[ $# -ge 1 ]] || { usage; exit 2; }

query="repo:torvalds/linux \"$1\""
[[ $# -ge 2 ]] && query="$query author:$2"

auth=()
[[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

curl -sG -m 40 \
    -H "Accept: application/vnd.github+json" \
    "${auth[@]+"${auth[@]}"}" \
    --data-urlencode "q=$query" \
    "https://api.github.com/search/commits" \
| python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    print("!! bad API response (rate limited?)"); sys.exit(1)
if "items" not in d:
    print("!! " + d.get("message", "unknown error")[:120]); sys.exit(1)
n = d.get("total_count", 0)
print("total_count = %d" % n)
suspect = 0
for it in d.get("items", [])[:10]:
    msg = it["commit"]["message"].split("\n")[0]
    day = it["commit"]["committer"]["date"][:10]
    flag = ""
    if msg.startswith("Merge") or msg.startswith("Revert"):
        flag = "  <-- likely false positive (merge/tokenised match)"
        suspect += 1
    print("  %s %s %s%s" % (it["sha"][:10], day, msg[:78], flag))
if n == 0:
    print("=> not in mainline (as of the mirror tip)")
elif suspect and suspect == min(n, 10):
    print("=> inconclusive: every hit looks like a merge commit; try the exact subject in quotes")
'
