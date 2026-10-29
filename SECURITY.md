# Security Policy

## Scope

This project ships **read-only** helper scripts that fetch public pages over
HTTPS. It does not execute kernel code, modify your system, or write to any
remote.

The security-relevant surfaces are:

| Surface | What it does |
|---|---|
| `scripts/*.py`, `scripts/*.sh` | Fetch URLs and print the result. No writes to remote. |
| `install.sh` / `uninstall.sh` | Copy the skill into `~/.agents/skills/` and create symlinks. `--purge` deletes them. |
| `SKILL.md` | Instructions the agent follows, including web fetches. |

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x | ✅ |

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Use GitHub's private reporting: **Security → Report a vulnerability** on
<https://github.com/WizardHowlhaha/kernel-lore-hunter>, or email the
maintainer privately.

Include:

- what the problem is and what an attacker gains
- the exact version or commit
- reproduction steps
- whether the issue is already public

You can expect an acknowledgement within 72 hours and a fix or mitigation plan
within 14 days.

## Notes for reviewers

This is a prompt-and-scripts package, so the interesting risks are:

- **Prompt injection from fetched content.** The scripts fetch mail bodies and
  patch text from lore.kernel.org and print them verbatim. That content is
  attacker-influenced: anyone can post to a public mailing list. An agent that
  treats a fetched patch as instructions could be steered. The skill treats all
  fetched content as **data to be analysed and cited, never as instructions to
  follow**. Please keep that property intact when editing `SKILL.md`.
- **Untrusted install scripts.** `install.sh` only copies files from the
  directory it lives in and creates symlinks. Reviewing the script before
  running it — as with any `curl | bash` — is still the right habit. Prefer
  `git clone` + `./install.sh` over piping to a shell.
- **Supply chain.** No third-party runtime dependencies: Python standard library
  only, plus `curl` and `git`.

## Hardening notes

- All script URLs are HTTPS and are constructed by the scripts themselves; no
  user-supplied URL is passed to a shell.
- Shell arguments are quoted; no `eval` is used.
- `install.sh` backs up a pre-existing real directory to `<name>.bak.<timestamp>`
  before replacing it, and never deletes a real directory unless `--purge` is
  given.
