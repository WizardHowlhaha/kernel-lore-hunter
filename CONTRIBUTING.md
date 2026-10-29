# Contributing

Thanks for helping make kernel archaeology less painful.

## The bar

**Every change must be backed by something you actually ran.**

This skill exists because guessing produces confident nonsense. The same rule
applies to changes to the skill itself:

- Fixing a script? Paste the command you ran and its real output.
- Adding a channel? Show it working against a live URL, not a description of
  how it should work.
- Changing the SOP? Explain which real investigation it would have saved.

Claims like "this should work" or "the upstream changed" without evidence will
be asked about.

## Workflow

```bash
git clone https://github.com/WizardHowlhaha/kernel-lore-hunter.git
cd kernel-lore-hunter

bash scripts/selftest.sh        # offline package + frontmatter + script checks
```

Then make your change and open a PR. CI runs the same checks plus
`skills-ref validate` (the official Agent Skills validator) and shellcheck.

### Before you push

```bash
bash scripts/selftest.sh
bash -n install.sh && bash -n uninstall.sh
python3 -m py_compile scripts/lore.py scripts/patchew.py
```

## Style

- **Scripts**: POSIX-flavoured bash, `set -euo pipefail`, tabs for indentation
  inside heredocs, no network calls in anything that runs offline.
- **Python**: standard library only. No third-party dependencies — users
  install this with `curl`, not `pip install`.
- **Docs**: `SKILL.md` stays under 500 lines. Detail goes in `references/`,
  loaded only when the skill needs it.
- **Frontmatter**: keep `name` equal to the folder name, `description` under
  1024 characters. The description is a trigger string, not a paragraph —
  it decides whether the agent loads this skill at all.
- **Comments**: explain *why*, especially for workarounds. "Anubis requires
  JavaScript, so UA spoofing does not work" saves the next person an hour.

## Adding a channel

The five channels in `SKILL.md` exist because the obvious ones are blocked.
If you find a sixth:

1. Confirm it is not behind Anubis, or that it has a working bypass.
2. Add it to `references/channels.md` with a measured round-trip time.
3. Add it to the channel matrix in `SKILL.md` with the same columns.
4. If it needs a script, add it to `scripts/` with a `--help` and an entry in
   `scripts/selftest.sh`.

## Reporting a wrong conclusion

If the skill produces a wrong or misleading answer, that is a bug worth
reporting. Include the input, the output, and what the correct answer was —
ideally with a lore link. That is exactly the evidence standard this project
asks for.

## Code of conduct

By participating you agree to the [Code of Conduct](./CODE_OF_CONDUCT.md).

## License

Contributions are licensed under the [MIT License](./LICENSE).
