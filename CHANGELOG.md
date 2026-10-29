# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-10-29

First public release.

### Added

- `SKILL.md` — the skill itself: the Anubis reality check, the five-channel
  matrix, a seven-step SOP, merge-status rules and the output template.
- `references/channels.md` — every lore / patchew / marc / git / GitHub-mirror
  URL and API template, including the per-month MHonArc archive.
- `references/message-id.md` — decoding author, series version, RFC stage and
  subsystem from a Message-ID and Subject line.
- `references/troubleshooting.md` — symptom → cause → remedy for every failure
  mode, plus the edge cases of the "is it merged?" decision.
- `references/worked-example.md` — a full article-to-patchset trace, including
  the three ways kernel coverage usually gets the story wrong.
- `scripts/lore.py` — read a mail or its reply tree via r.jina.ai, falling back
  to marc.info when the proxy is rate-limited.
- `scripts/patchew.py` — search patch series and dump a cover letter,
  diffstat and every patch.
- `scripts/kbranch.sh` — inspect a branch through `ls-remote` plus the GitHub
  mirror API (seconds), or a shallow fetch (authoritative, slow).
- `scripts/kmainline.sh` — decide whether a symbol reached mainline, with
  false-positive flagging for tokenised merge-commit matches.
- `scripts/selftest.sh` — offline package validation for CI and post-install
  checks.
- `install.sh` / `uninstall.sh` — multi-agent installer. One canonical copy at
  `~/.agents/skills/kernel-lore-hunter`, symlinked into Claude Code, Codex,
  Cursor, Gemini CLI, OpenCode, GitHub Copilot, Windsurf, Cline and Goose.
  Supports user and project scope, `--copy`, `--dry-run` and `--force`.
- `.claude-plugin/` — Claude Code plugin and marketplace manifests.
- CI, issue templates, pull request template, `SECURITY.md`,
  `CODE_OF_CONDUCT.md` and `CONTRIBUTING.md`.

### Notes

- All scripts are read-only and never write to a remote.
- Network access to `lore.kernel.org`, `patchew.org`, `marc.info`,
  `git.kernel.org` and `api.github.com` is required.
- Set `GITHUB_TOKEN` to raise the GitHub rate limits: the commit search API
  goes from 10 to 30 requests per minute, the core API from 60 to 5000 per
  hour.

[1.0.0]: https://github.com/WizardHowlhaha/kernel-lore-hunter/releases/tag/v1.0.0
