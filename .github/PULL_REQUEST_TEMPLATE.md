<!--
Read CONTRIBUTING.md before opening this. The short version:
English in code, comments earn their place, no dead options, no committed assets
or credentials, and you actually ran what you are submitting.
-->

## What this changes

<!-- One or two sentences. What behaviour is different after this PR? -->

## Why

<!-- The problem being solved. Link the issue if there is one: Fixes #123 -->

---

## How it was tested

<!--
Be specific. "Tested" on its own tells a reviewer nothing.
Say what you did and what you observed.

Example:
- Built Release on Windows 11 / VS 2022
- Logged in, walked Thais for two minutes, logged out and back in
- Confirmed "Minimap saved in 0.04 seconds" in Nyxos.log and the explored
  area still drawn after relogging
-->

- [ ] It compiles
- [ ] I started the client and exercised this change

## Scope

- [ ] Client-side only
- [ ] Needs server support (describe below)

<!-- If it needs server support, say exactly what the server must send. -->

---

## Checklist

- [ ] Code, comments and commit messages are in English
- [ ] Comments are one or two lines and explain *why*, not *what*
- [ ] No option is exposed in the UI without a working backend
- [ ] No game assets, credentials or personal paths are committed
- [ ] Lua changes pass `luajit -bl` (not `luac5.1` — it rejects valid `goto`)
- [ ] Line endings unchanged (CRLF for `.otui`/`.otmod`, LF elsewhere)
- [ ] This is one logical change, not several bundled together

## Screenshots

<!-- Required for anything that changes what the player sees. Before and after. -->
