# Tests

Headless Lua specs. They run without booting the client — no window, no assets,
no server — so they are fast enough to run on every change.

```bash
tests/run.sh              # everything
tests/run.sh spells       # only specs whose name matches
```

Requires `luajit`:

```bash
sudo apt-get install -y luajit
```

From Windows: `wsl -e bash -lc "cd /mnt/c/dev/otserver/nyxos-client && ./tests/run.sh"`

---

## Use LuaJIT, not lua5.1

The client builds with `LUAJIT=ON`, so module code legitimately uses `goto` and
labels. Checking with `luac5.1 -p` **rejects valid code** — it reports
`'=' expected near 'continue'` on files that run perfectly well.

If a syntax check disagrees with the client, check which parser you ran before
assuming the code is wrong.

---

## What is covered

| Spec | Guards |
|---|---|
| `syntax_spec.lua` | Every `.lua` under `modules/` and `mods/` parses (286 files) |
| `spells_spec.lua` | Crosshair cast routing — `needPosition` spells prompt for a tile, everything else stays plain speech |

The syntax spec exists because a broken module only fails when something happens
to load it, which can be a long way from the change that broke it.

---

## Writing a spec

Name it `tests/lua/<subject>_spec.lua` and return the harness:

```lua
local t = require('harness')

t.describe('Subject', function()
  t.it('does the thing', function()
    t.expect(actual).toBe(expected)
  end)
end)

return t
```

Matchers: `toBe`, `toBeNil`, `toBeTruthy`, `toEqualPosition(x, y, z)`.

### Loading client modules

`t.loadModule(path, stubs)` runs a module in its own environment and returns the
globals it defined. Engine singletons that do not exist headless go in `stubs`:

```lua
local env = t.loadModule('modules/gamelib/spells.lua', {
  g_game = { talk = function(words) table.insert(talked, words) end },
  modules = { game_interface = { startAimedCast = function() end } }
})
local Spells = env.Spells
```

Each call gets a fresh environment, so one spec cannot leak globals into the
next. The corelib `string`/`table` extensions are loaded for real rather than
stubbed, because module code calls them constantly and stubbing them would test
the stub instead of the client.

### What belongs here

Pure logic: lookup tables, routing decisions, parsing, option filtering.

What does not: anything needing a live widget tree, the renderer, or a socket.
Those still need the client running and a real server.
