#!/usr/bin/env bash
# selftest.sh -- offline sanity check for the kernel-lore-hunter skill.
#
# Verifies the package shape and the scripts WITHOUT touching the network, so
# it is safe to run in CI, in a sandbox, or right after installing.
#
# Usage: bash scripts/selftest.sh [skill-root]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -ge 1 ]]; then ROOT="$(cd "$1" && pwd)"; fi
cd "$ROOT"

fails=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
head_() { printf '\n== %s ==\n' "$1"; }

# ------------------------------------------------------------------ layout
head_ "package layout"
for f in SKILL.md LICENSE; do
  [[ -f "$f" ]] && pass "$f" || fail "$f missing"
done
for d in scripts references; do
  [[ -d "$d" ]] && pass "$d/" || fail "$d/ missing"
done
# optional extras: a README belongs to the repo, not to an installed skill dir
[[ -f README.md ]] && pass "README.md" || true
[[ -d assets ]] && pass "assets/ (optional)" || true

# ------------------------------------------------------------- frontmatter
head_ "SKILL.md frontmatter"
python3 - "$ROOT" <<'PY' || fails=$((fails + 1))
import os, re, sys

root = sys.argv[1]
path = os.path.join(root, "SKILL.md")
text = open(path, encoding="utf-8").read()

fails = []

if not text.startswith("---\n"):
    print("  FAIL  SKILL.md does not start with '---'")
    sys.exit(1)

end = text.find("\n---\n", 3)
if end == -1:
    print("  FAIL  no closing '---' for the frontmatter")
    sys.exit(1)

fm = text[4:end]
body = text[end + 5:]

def field(name):
    m = re.search(r"^%s:\s*(.*)$" % re.escape(name), fm, re.M)
    return m.group(1).strip() if m else None

name = field("name")
desc = field("description")

if not name:
    fails.append("name is missing")
elif not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
    fails.append("name %r must be lowercase letters/digits/single hyphens" % name)
elif len(name) > 64:
    fails.append("name is longer than 64 characters")
elif name != os.path.basename(root):
    fails.append("name %r must match the folder name %r" % (name, os.path.basename(root)))

if not desc:
    fails.append("description is missing")
elif len(desc) > 1024:
    fails.append("description is %d characters (max 1024)" % len(desc))

compat = field("compatibility")
if compat and len(compat) > 500:
    fails.append("compatibility is %d characters (max 500)" % len(compat))

lines = body.count("\n")
if lines > 500:
    fails.append("SKILL.md body is %d lines (max 500)" % lines)

if fails:
    for f in fails:
        print("  FAIL  %s" % f)
    sys.exit(1)

print("  ok    name=%s (%d chars)" % (name, len(name)))
print("  ok    description=%d chars" % len(desc))
print("  ok    body=%d lines" % lines)
if compat:
    print("  ok    compatibility=%d chars" % len(compat))
PY

# ------------------------------------------------------- referenced files
head_ "referenced files exist"
for ref in $(grep -oE 'references/[a-z0-9-]+\.md' SKILL.md | sort -u); do
  [[ -f "$ref" ]] && pass "$ref" || fail "$ref referenced in SKILL.md but missing"
done

# ---------------------------------------------------------------- scripts
head_ "scripts"
for s in scripts/lore.py scripts/patchew.py scripts/kbranch.sh scripts/kmainline.sh; do
  if [[ ! -f "$s" ]]; then
    fail "$s missing"
    continue
  fi
  case "$s" in
    *.py) python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$s" 2>/dev/null \
           && pass "$s compiles" || fail "$s does not compile" ;;
    *.sh) bash -n "$s" 2>/dev/null && pass "$s parses" || fail "$s has a syntax error" ;;
  esac
  [[ -x "$s" ]] && pass "$s is executable" || fail "$s is not executable"
done

head_ "scripts --help"
python3 scripts/lore.py --help    >/dev/null 2>&1 && pass "lore.py --help"    || fail "lore.py --help failed"
python3 scripts/patchew.py --help >/dev/null 2>&1 && pass "patchew.py --help" || fail "patchew.py --help failed"
bash scripts/kbranch.sh --help    >/dev/null 2>&1 && pass "kbranch.sh --help"    || fail "kbranch.sh --help failed"
bash scripts/kmainline.sh --help  >/dev/null 2>&1 && pass "kmainline.sh --help"  || fail "kmainline.sh --help failed"

# -------------------------------------------------------------- dependencies
head_ "runtime dependencies"
for tool in curl git python3; do
  command -v "$tool" >/dev/null 2>&1 && pass "$tool" || fail "$tool not on PATH"
done

# ------------------------------------------------------------------- result
printf '\n'
if [[ $fails -eq 0 ]]; then
  echo "ALL CHECKS PASSED"
  exit 0
fi
echo "$fails CHECK(S) FAILED"
exit 1
