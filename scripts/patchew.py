#!/usr/bin/env python3
"""Query patchew.org -- the patch-series index that mirrors the kernel lists.

patchew is not behind Anubis, so it is the cheapest way to find a series and
to read every patch of it with its diffstat.

Usage:
    patchew.py search "<keywords>"
    patchew.py series <cover-message-id | patchew-url>
"""

import html as htmlmod
import re
import shutil
import subprocess
import sys
import time
import urllib.parse

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def curl(url, timeout=60, attempts=3):
    for i in range(attempts):
        p = subprocess.run(["curl", "-fsSL", "-m", str(timeout), "-A", UA, url],
                           capture_output=True, text=True)
        if p.returncode == 0 and p.stdout:
            return p.stdout
        if i + 1 < attempts:
            time.sleep(2)
    return ""


def text_of(fragment):
    fragment = re.sub(r"<br\s*/?>", "\n", fragment)
    fragment = re.sub(r"</(p|div|li|tr|h\d)>", "\n", fragment)
    txt = htmlmod.unescape(re.sub(r"<[^>]+>", "", fragment))
    txt = re.sub(r"[ \t\xa0]+", " ", txt)
    return re.sub(r"\n{3,}", "\n\n", txt).strip()


def cmd_search(query):
    url = "https://patchew.org/search?q=" + urllib.parse.quote(query)
    page = curl(url)
    if not page:
        print("!! search failed: %s" % url, file=sys.stderr)
        return 1

    rows, seen = [], set()
    for m in re.finditer(r"<a ([^>]*)>(.*?)</a>", page, re.S):
        attrs, label = m.group(1), text_of(m.group(2))
        if "series-subject" not in attrs:
            continue
        hm = re.search(r'href="(/linux/[^"]+)"', attrs)
        if not hm:
            continue
        mid = hm.group(1).strip("/").split("/")[-1]
        if mid in seen:
            continue
        seen.add(mid)
        # the author sits in the following <span title="Name <mail>">
        tail = page[m.end():m.end() + 800]
        am = re.search(r'<span title="([^"]+)"', tail)
        author = htmlmod.unescape(am.group(1)).split(" <")[0] if am else "?"
        rows.append((label, author, mid, "https://patchew.org" + hm.group(1)))

    if not rows:
        print("no series found for %r -- try fewer / more distinctive words" % query)
        return 0
    for label, author, mid, link in rows:
        print("%-64s %-22s %s" % (label[:64], author[:22], link))
    print("\n%d series; open one with: patchew.py series <cover-id>" % len(rows))
    return 0


def cmd_series(arg):
    arg = arg.strip()
    if arg.startswith("http"):
        url = arg
        mid = arg.rstrip("/").split("/")[-1]
    else:
        mid = arg.strip("<>")
        url = "https://patchew.org/linux/%s/" % mid
    page = curl(url)
    if not page:
        print("!! series fetch failed: %s" % url, file=sys.stderr)
        print("   (patchew only indexes series it received; fall back to lore)", file=sys.stderr)
        return 1

    title = re.search(r"<title>\s*(.*?)\s*</title>", page, re.S)
    if title:
        print("# " + re.sub(r"\s+", " ", text_of(title.group(1))))
        print()

    blocks = [text_of(b) for b in re.findall(r'<pre class="body-full">(.*?)</pre>', page, re.S)]
    diffstat = [b for b in blocks if re.match(r"\S+\s+\|\s+\d+", b)]
    messages = [b for b in blocks if b and b not in diffstat]

    if diffstat:
        print("## diffstat")
        print(diffstat[0])
        print()
    if messages:
        print("## cover letter")
        print(messages[0])
        if len(messages) > 1:
            print("\n## %d repl%s on this series (patchew keeps them too)"
                  % (len(messages) - 1, "y" if len(messages) == 2 else "ies"))

    ul = re.search(r'<ul[^>]*id="patches"[^>]*>(.*?)</ul>', page, re.S)
    if ul:
        print("\n## patches")
        for m in re.finditer(r'<a href="([^"]+)">(.*?)</a>', ul.group(1), re.S):
            subj = re.sub(r"\s+", " ", text_of(m.group(2)))
            if not subj:
                continue
            link = urllib.parse.urljoin(url, m.group(1))
            print("%-74s %s" % (subj[:74], link))

    print("\n## series page: %s" % url)
    print("## lore:        https://lore.kernel.org/all/%s/" % mid)
    return 0


def main(argv):
    if len(argv) < 3 or argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        return 0 if len(argv) > 1 else 2
    if not shutil.which("curl"):
        print("!! curl not found on PATH -- this script needs curl to fetch series", file=sys.stderr)
        return 1
    if argv[1] == "search":
        return cmd_search(" ".join(argv[2:]))
    if argv[1] == "series":
        return cmd_series(argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
