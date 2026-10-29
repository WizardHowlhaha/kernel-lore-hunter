#!/usr/bin/env python3
"""Read Linux kernel mailing list messages without fighting the Anubis bot-wall.

lore.kernel.org, git.kernel.org and lkml.org sit behind an Anubis proof-of-work
gate, so plain fetches return a ~1.1 KB "Making sure you're not a bot" page.
This helper goes through r.jina.ai and falls back to marc.info when the proxy
is rate-limited (it often is, after a dozen calls).

Usage:
    lore.py msg    <message-id | lore-url>     # headers + body
    lore.py thread <message-id | lore-url>     # reply tree only
    lore.py msg --full <id>                    # keep thread overview in body

Exit code 1 if both channels fail.
"""

import html as htmlmod
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

WALL_MARKERS = ("Anubis", "Making sure you're not a bot", "Loading...")


def curl(url, timeout=60, attempts=3):
    """Return body text, or "" if every attempt failed (both sites flake a lot)."""
    for i in range(attempts):
        try:
            p = subprocess.run(["curl", "-fsSL", "-m", str(timeout), "-A", UA, url],
                               capture_output=True, text=True)
            if p.returncode == 0 and p.stdout:
                return p.stdout
        except Exception:
            pass
        if i + 1 < attempts:
            time.sleep(2)
    return ""


def is_wall(text):
    """True for the Anubis interstitial: tiny body that only says 'verifying'."""
    if not text:
        return True
    if "Anubis could not load its JavaScript" in text:
        return True
    return len(text) < 2500 and any(m in text for m in WALL_MARKERS)


def msgid(arg):
    """Accept a bare message-id or any lore/kml URL and return the message-id."""
    arg = arg.strip()
    if arg.startswith("http"):
        for pat in (r"/all/([^/]+)/?", r"/lkml/([^/]+)", r"/linux-[a-z]+/([^/]+)"):
            m = re.search(pat, arg)
            if m:
                return urllib.parse.unquote(m.group(1))
    return arg.strip("<>")


# ---------------------------------------------------------------- fetchers

def from_jina(mid, attempts=3, pause=4):
    """The free reader proxy rate-limits; retry with backoff before giving up."""
    url = "https://r.jina.ai/https://lore.kernel.org/all/%s/" % urllib.parse.quote(mid)
    for i in range(attempts):
        body = curl(url, attempts=1)
        if not is_wall(body):
            if "Markdown Content:" in body:
                body = body.split("Markdown Content:", 1)[1]
            return body.strip()
        if i + 1 < attempts:
            time.sleep(pause * (i + 1))
    return None


def _marc_pre(page):
    m = re.search(r"<pre[^>]*>(.*?)</pre>", page, re.S)
    if not m:
        return None
    txt = htmlmod.unescape(re.sub(r"<[^>]+>", "", m.group(1))).strip()
    txt = re.sub(r"^\[Download RAW[^\]]*\]\s*$", "", txt, flags=re.M)
    i = txt.find("Subject:")          # drop marc's nav header
    if i > 0:
        txt = txt[i:]
    j = txt.find("[prev in list]")    # and its footer
    if j > 0:
        txt = txt[:j]
    return txt.strip()


def from_marc(mid):
    """marc.info: ?i=<msgid> is an index of cross-posts; the body is one hop away."""
    idx = curl("https://marc.info/?i=" + urllib.parse.quote(mid), timeout=40)
    if is_wall(idx) or not idx:
        return None
    body = _marc_pre(idx)
    if body and body.startswith(("Subject:", "From:")):
        return body
    for href in re.findall(r'href="(\?l=[^"]+?&m=\d+&w=2)"', idx)[:3]:
        page = curl("https://marc.info/" + htmlmod.unescape(href), timeout=40)
        body = _marc_pre(page)
        if body:
            return body
    return None


def fetch(mid):
    body = from_jina(mid)
    if body:
        return body, "r.jina.ai"
    body = from_marc(mid)
    if body:
        return body, "marc.info"
    return None, None


# ---------------------------------------------------------------- parsing

LINK = re.compile(r"\[([^\]]*)\]\((https://lore\.kernel\.org/all/[^)]+)\)")


def split_body(text):
    """Split a jina-rendered message into (body, thread-overview)."""
    m = re.search(r"\*\*Thread overview:?\*\*", text)
    if not m:
        return text, ""
    return text[:m.start()], text[m.start():]


def parse_thread(overview):
    """Yield (date, depth, author, subject, msgid, url) from a lore overview.

    Nested rows only carry the *author* link, top-level rows carry subject+author,
    and the tree is closed by a "* * *" rule -- all three quirks are handled here.
    """
    overview = overview.split("* * *")[0]
    rows = []
    for line in overview.splitlines():
        line = line.rstrip()
        links = list(LINK.finditer(line))
        if not links:
            continue
        first = links[0]
        url = first.group(2).split("#")[0]
        mid = urllib.parse.unquote(url.rstrip("/").rsplit("/", 1)[-1])
        if "@" not in mid:            # /t/#u, /T/#u and other nav links
            continue
        date_m = re.search(r"(\d{4}-\d{2}-\d{2})\s+(\d{1,2}:\d{2})", line)
        date = ("%s %s" % (date_m.group(1), date_m.group(2).rjust(5, "0"))) if date_m else "?"
        if len(links) >= 2:           # subject link then author link
            subject = first.group(1).strip()
            author = links[1].group(1).strip()
        else:                         # only one link: it is the author
            subject = ""
            author = first.group(1).replace("[this message]", "").strip()
        head = line[:first.start()]
        depth = len(head.split("`", 1)[1]) if "`" in head else 0
        rows.append((date, depth, author, subject, mid, url))
    return rows


# ---------------------------------------------------------------- commands

def cmd_msg(mid, full=False):
    text, via = fetch(mid)
    if not text:
        print("!! both r.jina.ai and marc.info failed for %s" % mid, file=sys.stderr)
        print("   -> retry in a minute, or open manually:", file=sys.stderr)
        print("      https://lore.kernel.org/all/%s/" % mid, file=sys.stderr)
        return 1
    body, overview = split_body(text)
    print(body.rstrip())
    if full and overview:
        print()
        print(overview.rstrip())
    print()
    print("-- via %s | https://lore.kernel.org/all/%s/" % (via, mid))
    return 0


def cmd_thread(mid):
    text, via = fetch(mid)
    if not text:
        print("!! both r.jina.ai and marc.info failed for %s" % mid, file=sys.stderr)
        return 1
    _, overview = split_body(text)
    rows = parse_thread(overview)
    if not rows:
        if via == "marc.info":
            print("(thread view needs r.jina.ai, which is rate-limited right now;")
            print(" retry in a minute, or open: https://lore.kernel.org/all/%s/T/#u)" % mid)
        else:
            print("(no thread overview -- this may be a lone post)")
        return 0
    print("%-16s %-26s %s" % ("date", "author", "message-id"))
    for date, depth, author, subject, m, _ in rows:
        print("%-16s %s%-26s %s" % (date, "  " * depth, author[:26], m))
    print("\n%d messages, via %s" % (len(rows), via))
    return 0


def main(argv):
    if len(argv) < 3 or argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        return 0 if len(argv) > 1 else 2
    if not shutil.which("curl"):
        print("!! curl not found on PATH -- this script needs curl to fetch mail", file=sys.stderr)
        return 1
    what = argv[1]
    rest = argv[2:]
    full = "--full" in rest
    rest = [a for a in rest if a != "--full"]
    mid = msgid(rest[0])
    if what == "msg":
        return cmd_msg(mid, full)
    if what == "thread":
        return cmd_thread(mid)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
