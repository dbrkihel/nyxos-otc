# Contributing

Thanks for wanting to help. This document is the short version of how work gets
accepted here — reading it before you open a PR will save you a round trip.

---

## Ground rules

### 1. English in the code

Identifiers, comments, commit messages and PR descriptions: **English**. Issue
discussion can be in Portuguese or English, whichever you are comfortable with.

### 2. Comments earn their place

One or two lines, maximum, and only where the code cannot say it itself. Explain
**why**, not what.

```cpp
// Good: says why the obvious thing was not done.
// AL_LOOPING is invalid on a source with queued buffers, so a stream loops by
// rewinding its file in update() instead of through the base implementation.

// Bad: restates the code.
// Set the looping flag to the given value.
```

Do not leave commented-out code, `TODO` graveyards, or block comments narrating
a function line by line.

### 3. No dead options

Every option exposed in the UI must have a working backend. A checkbox that
changes nothing is a bug, not a placeholder.

If a feature is not implemented yet, either leave the option out entirely or add
it to `unsupportedOptions` so it renders greyed out. Never ship a live control
that silently does nothing.

### 4. Research before you guess

This client mirrors the official Tibia client's behaviour and layout. When you
are unsure how something should look or work, find the answer instead of
approximating it — the official client's QML, its resource bundles, and its
packet traces are all inspectable. A pixel-accurate answer exists; guessing
produces work that has to be redone.

The same applies to protocol changes: confirm the wire format before changing a
parser.

### 5. Never commit assets or secrets

- **Game assets** (sprites, appearances, `.ogg` sound files) belong to CipSoft
  and must never be committed. `.gitignore` blocks the known paths — do not
  work around it.
- **No credentials.** `config.lua` is gitignored for this reason. Put your hosts
  and passwords there, never in `config.example.lua` or in source.
- **No personal paths** (`C:\Users\yourname\...`) in committed files.

---

## Technical conventions

**Lua is LuaJIT** (`LUAJIT=ON`), so `goto` and labels are valid and module code
uses them. Check syntax with `luajit -bl yourfile.lua`, never `luac5.1 -p` —
5.1 rejects valid code with `'=' expected near 'continue'`.

**Run the specs** before opening a PR — they take seconds and CI runs them on
every push:

```bash
tests/run.sh
```

They parse every Lua module and cover pure logic (routing decisions, lookup
tables, handler contracts). If your change touches logic that can be tested
headless, add a spec — see [`tests/README.md`](tests/README.md).

**Line endings.** `.otui` and `.otmod` files are CRLF; Lua and C++ are LF. A
regex or script that assumes the wrong one will silently match nothing. If your
edit produces a whole-file diff, your editor changed the line endings — fix that
before committing.

**Layout comes from the source, not from measurement by eye.** Offsets, clips
and colours should be traceable to the official client, not tuned until they
look about right.

**Sandboxed modules.** A module with `sandboxed: true` in its `.otmod` has its
own global table. Cross-module access goes through `modules.<name>`.

---

## Making a change

1. **Open an issue first** for anything larger than a small fix. It avoids two
   people building the same thing, and avoids you building something that will
   not be merged.
2. Branch from `main`.
3. Keep the PR focused. One logical change. A refactor and a feature in the same
   PR will be asked to split.
4. **Build it.** Windows is the primary platform; if you touch `src/`, confirm
   it still compiles. CI builds both Windows and Linux on every PR — a red
   check will not be merged.
5. **Run it.** For anything touching UI or gameplay, actually start the client
   and exercise the change. "It compiles" is not "it works", and PRs are
   reviewed on the assumption you tested what you are claiming.

### Commit messages

Imperative mood, describing the effect:

```
Fix the trade column's frames, top gap and bottom overlap
Persist the explored minimap between sessions
```

Not `fixed stuff`, not `update store.lua`.

---

## Reporting bugs

Use the bug template and fill it in. The three things that make a report
actionable:

1. **`Nyxos.log`** — next to the executable. Attach it, do not paste a fragment
   you think is relevant.
2. **Exact steps** to reproduce, from client start.
3. **Your setup** — OS, build type, server software and version.

"It doesn't work" with no log gets closed.

---

## What is unlikely to be merged

- Features with no server-side story, when they need one
- Changes that hardcode a specific server's hosts, branding or business details
- Bot or automation features aimed at official Tibia servers
- Large reformatting or renaming passes mixed into functional changes
- Anything that commits copyrighted assets

---

## License

By contributing you agree your work is released under the
[MIT License](LICENSE) that covers this project.
