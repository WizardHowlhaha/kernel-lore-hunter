# kernel-lore-hunter

**Turn an article, a commit, or a kernel symbol into the actual patchset, the actual mailing-list thread, and a verified merge status.**

lore.kernel.org, git.kernel.org and lkml.org all sit behind an
[Anubis](https://github.com/TecharoHQ/anubis) proof-of-work bot-wall. A plain
`curl` gets you `403` and a ~1.1 KB fake page. This skill teaches your agent
five channels that get through, plus the procedure for turning a vague
"someone posted about page cache" into **code branch + mail thread + version
status**, each with a permanent, clickable link.

> Works with Claude Code, Codex, Cursor, Gemini CLI, OpenCode, GitHub Copilot,
> Windsurf, Cline, Goose, Amp, MiniMax Code, DSH and anything else that follows
> the [Agent Skills](https://agentskills.io) standard.

[中文文档](./README.zh-CN.md) · [Skill file](./SKILL.md) · [MIT License](./LICENSE)

---

## What it actually does

Given *"this article says Linus used an LLM to rewrite the page cache — find the
patchset"*, the skill produces:

| | |
|---|---|
| **Code** | the branch, the commit range, every version of the series |
| **Discussion** | the root mail, the 3–6 review comments that actually mattered, who argued what |
| **Lineage** | earlier attempts at the same problem, in order |
| **Corrections** | where the article is wrong — dates, patch counts, branch ownership |
| **Status** | merged / still in RFC / superseded, **with the date it was checked** |

The last two rows are the point. Second-hand kernel coverage is wrong roughly
every time, and an agent that repeats it without checking produces confident
nonsense.

---

## Install

### 1. `npx skills` (fastest — works with 40+ agents)

```bash
npx skills add WizardHowlhaha/kernel-lore-hunter -g
```

Target specific agents, or a subset of skills:

```bash
npx skills add WizardHowlhaha/kernel-lore-hunter -g -a claude-code -a codex
npx skills list -g                 # what is installed
```

### 2. Clone + install script (recommended — auditable, one copy, many agents)

```bash
git clone https://github.com/WizardHowlhaha/kernel-lore-hunter.git
cd kernel-lore-hunter
./install.sh                        # user scope, every detected agent
./install.sh --dry-run              # preview first
./install.sh -a claude-code -a cursor
./install.sh --scope project --project-dir ~/work/linux-mm
```

The script keeps **one canonical copy** at `~/.agents/skills/kernel-lore-hunter`
and symlinks every agent to it. Update the canonical copy and all agents see
it at once.

### 3. Manual copy

```bash
git clone https://github.com/WizardHowlhaha/kernel-lore-hunter.git \
  ~/.agents/skills/kernel-lore-hunter
```

For Claude Code (which does not read `~/.agents/skills/`), add a symlink:

```bash
mkdir -p ~/.claude/skills
ln -s ~/.agents/skills/kernel-lore-hunter ~/.claude/skills/kernel-lore-hunter
```

### Uninstall

```bash
./uninstall.sh            # remove the agent links
./uninstall.sh --purge    # also delete the canonical copy
```

---

## Where each agent looks

`install.sh` links the right directory for you; this is the reference.

| Agent | User scope | Project scope | Covered by `install.sh` |
|---|---|---|---|
| Universal (`~/.agents/skills`) | `~/.agents/skills/kernel-lore-hunter` | `.agents/skills/kernel-lore-hunter` | ✅ canonical |
| Claude Code | `~/.claude/skills/kernel-lore-hunter` | `.claude/skills/kernel-lore-hunter` | ✅ |
| Codex | `~/.codex/skills/kernel-lore-hunter` | `.codex/skills/kernel-lore-hunter` | ✅ |
| Cursor | `~/.cursor/skills/kernel-lore-hunter` | `.cursor/skills/kernel-lore-hunter` | ✅ |
| Gemini CLI | `~/.gemini/skills/kernel-lore-hunter` | `.gemini/skills/kernel-lore-hunter` | ✅ |
| OpenCode | `~/.config/opencode/skills/kernel-lore-hunter` | `.opencode/skills/kernel-lore-hunter` | ✅ |
| GitHub Copilot | `~/.copilot/skills/kernel-lore-hunter` | `.github/skills/kernel-lore-hunter` | ✅ |
| Windsurf | `~/.windsurf/skills/kernel-lore-hunter` | `.windsurf/skills/kernel-lore-hunter` | ✅ |
| Cline | `~/.cline/skills/kernel-lore-hunter` | `.cline/skills/kernel-lore-hunter` | ✅ |
| Goose | `~/.goose/skills/kernel-lore-hunter` | `.goose/skills/kernel-lore-hunter` | ✅ |
| Amp, MiniMax Code, DSH | read `~/.agents/skills/` | — | ✅ canonical |

**Claude Code is the exception**: it reads `.claude/skills/` and
`~/.claude/skills/`, *not* `~/.agents/skills/`. That is why `install.sh` keeps a
symlink for it.

### Verify

```bash
bash ~/.agents/skills/kernel-lore-hunter/scripts/selftest.sh
```

Runs fully offline: validates the package layout, the frontmatter against the
Agent Skills spec, every script's syntax, and the `--help` entry points.

Then restart your agent and try:

```
find the kernel patchset and LKML discussion behind <URL / commit / symbol>
```

---

## The five channels

The whole skill exists because of this table.

| Need | Channel | Speed | Notes |
|---|---|---|---|
| Read one mail | `scripts/lore.py msg <msgid>` | ~3 s | r.jina.ai first, auto-falls back to marc.info |
| Reply tree | `scripts/lore.py thread <msgid>` | ~3 s | jina only; rate-limited, wait 1–2 min |
| Find a series | `scripts/patchew.py search` / `series` | ~2 s | cover letter, diffstat, every patch |
| Confirm a branch | `git ls-remote --heads <repo> 'refs/heads/*kw*'` | ~1 s | **do this first** — faster than any web page |
| Read a master commit | `scripts/kbranch.sh <repo> master N` | ~2 s | via the GitHub mirror API |
| Read a side branch | `scripts/kbranch.sh --git ...` | **3–5 min** | linux.git packs are huge — run it in the background |
| Monthly archaeology | `lkml.iu.edu/hypermail/linux/kernel/YYMM.N/` | seconds | static MHonArc archive |
| Is it in mainline? | `scripts/kmainline.sh <symbol>` | ~1 s | exact phrase, avoids tokenised false positives |

> Spoofing the User-Agent does **not** work — Anubis runs JavaScript. Change
> channels instead.

---

## Scripts

| Script | Usage | Purpose |
|---|---|---|
| `scripts/lore.py msg <msgid\|url>` | `python3 scripts/lore.py msg as6vBoWQGglxXxb0@thinkstation` | mail headers + body |
| `scripts/lore.py thread <msgid>` | same | reply tree (date / depth / author / msgid) |
| `scripts/patchew.py search "<kw>"` | `python3 scripts/patchew.py search "folio references"` | find series |
| `scripts/patchew.py series <cover-id>` | | diffstat + cover letter + all patches |
| `scripts/kbranch.sh <repo> <branch> [n]` | `scripts/kbranch.sh .../torvalds/linux.git rcu-free-v3 8` | ls-remote + GitHub API |
| `scripts/kbranch.sh --git <repo> <branch> [n]` | | shallow fetch (slow; side branches) |
| `scripts/kbranch.sh --list <repo> '<pattern>'` | `--list <repo> 'refs/heads/*rcu*'` | list branches |
| `scripts/kmainline.sh <symbol>` | `scripts/kmainline.sh PG_rcu_free` | merged or not? |
| `scripts/selftest.sh` | `bash scripts/selftest.sh` | offline package check |
| `scripts/smoke.sh` | `bash scripts/smoke.sh` | live check that all five channels still answer |

Requirements: `curl`, `python3`, `git`. **Read-only** — the scripts never write
to a remote. Network access to `lore.kernel.org`, `patchew.org`, `marc.info`,
`git.kernel.org` and `api.github.com` is required; sandboxes that disable
networking by default must enable it first.

GitHub rate limits are tight without a token: the **search** API allows 10
requests per minute unauthenticated, and the core API 60 per hour. Set
`GITHUB_TOKEN` to raise those to 30 per minute and 5000 per hour.

---

## Layout

```
kernel-lore-hunter/
├── SKILL.md                   # the skill itself: SOP + channel matrix + output template
├── references/                # loaded on demand, not at skill start
│   ├── channels.md            # every URL / API template
│   ├── message-id.md          # decode author, series version, RFC stage from a Message-ID
│   ├── troubleshooting.md     # symptom -> cause -> remedy
│   └── worked-example.md      # a full article-to-patchset trace
├── scripts/                   # the five-channel helpers
├── install.sh                 # multi-agent installer
├── uninstall.sh
└── .claude-plugin/            # Claude Code plugin / marketplace manifest
```

`SKILL.md` stays small on purpose: the agent reads the frontmatter at startup
and only pulls the body when the skill actually triggers, then reads
`references/` for the specific lookup it needs.

---

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](./CONTRIBUTING.md).
The bar for a change: **it must be backed by something you actually ran.**

```bash
bash scripts/selftest.sh
```

---

## License

[MIT](./LICENSE) © 2026 Wenyu Liu
