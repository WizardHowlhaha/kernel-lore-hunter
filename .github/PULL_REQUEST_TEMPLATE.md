## What this changes

<!-- One or two sentences. What is different after this PR? -->

## Why

<!-- The problem this solves. Link the issue if there is one: Closes #123 -->

## Evidence

<!--
The bar for this project: show the commands you ran and their real output.
A claim like "this works" without evidence will be asked about.
-->

```
$ bash scripts/selftest.sh
...
```

## Checklist

- [ ] `bash scripts/selftest.sh` passes
- [ ] `bash -n install.sh && bash -n uninstall.sh`
- [ ] `python3 -m py_compile scripts/lore.py scripts/patchew.py`
- [ ] I added or updated the relevant file in `references/`
- [ ] `SKILL.md` stays under 500 lines
- [ ] If I touched the SOP, the change is backed by a real investigation I ran
- [ ] No third-party runtime dependencies were added (stdlib only)
- [ ] `CHANGELOG.md` has an entry under *Unreleased*
