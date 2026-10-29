#!/usr/bin/env bash
# smoke.sh -- check that the five channels still answer.
#
# Unlike selftest.sh this one DOES hit the network. Use it when a channel
# starts returning garbage, or to confirm the channels work from your machine
# before blaming the skill.
#
# Usage: bash scripts/smoke.sh
# Exit code: 0 if every channel answered, 1 otherwise.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# A well-known, long-lived thread on the page-cache work.
KNOWN_MSGID="CAHk-=wjLjgfwgSZ1RDk4YdNFcV0ntosMO5AmBoHD76Zb3HFY7Q@mail.gmail.com"
TORVALDS="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

printf 'channel smoke test\n\n'

# 1. git protocol (never behind Anubis)
printf 'git protocol (ls-remote torvalds/linux): '
if git ls-remote --heads "$TORVALDS" refs/heads/master >/dev/null 2>&1; then
  ok "responded"
else
  bad "no answer -- is the network enabled?"
fi

# 2. GitHub mirror API
printf 'github mirror api (commit search): '
if bash scripts/kmainline.sh PG_rcu_free >/dev/null 2>&1; then
  ok "responded"
else
  bad "no answer -- rate limited? set GITHUB_TOKEN"
fi

# 3. patchew
printf 'patchew.org (series search): '
if python3 scripts/patchew.py search "folio" >/dev/null 2>&1; then
  ok "responded"
else
  bad "no answer"
fi

# 4. lore via jina / marc
printf 'lore.kernel.org (mail fetch): '
if python3 scripts/lore.py msg "$KNOWN_MSGID" >/dev/null 2>&1; then
  ok "responded"
else
  bad "no answer -- both r.jina.ai and marc.info failed (rate limited?)"
fi

printf '\n'
if [[ $fails -eq 0 ]]; then
  echo "all channels alive"
  exit 0
fi
echo "$fails channel(s) failed"
exit 1
