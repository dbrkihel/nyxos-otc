---
title: Getting started
layout: default
nav_order: 4
---

# Getting started

You have a compiled client. It will not show anything useful until you give it
game assets and point it at a server. This page covers both.

---

## 1. Game assets

{: .warning }
> Sprites, appearances and sounds are the property of **CipSoft GmbH** and are
> not distributed with this repository. Copy them from a Tibia client
> installation you already have. Do not commit them — `.gitignore` already
> blocks them.

### Graphics

Protocol 15.25 uses the modern asset format: `appearances.dat`, the sprite
sheets, and `catalog-content.json`.

```
data/things/1525/
├── appearances.dat
├── catalog-content.json
└── sprites-*.bmp.lzma      (all of them)
```

In an official client installation these live under `assets/` (or
`packages/Tibia/assets/`). Copy the whole directory contents across.

### Sounds

Audio is split in two: an **index** that ships with the repository, and the
**audio files** that do not.

```
data/sounds/
├── soundbank.json          <- tracked in git, ships with the client
└── sound-<hash>.ogg        <- yours, ~815 files
```

Copy the `.ogg` files from your client's `assets/` directory into
`data/sounds/`.

If your client version differs and the ids no longer line up, regenerate the
index from your own sound bank:

```bash
python tools/soundbank.py path/to/sounds-<hash>.dat data/sounds/soundbank.json
```

That script walks the protobuf in `sounds-<hash>.dat` by hand and emits five
tables: files, effects, ambience, music and object groups.

Without the `.ogg` files the client runs normally and simply plays nothing.

---

## 2. Configuration

```bash
cp config.example.lua config.lua      # Windows: copy config.example.lua config.lua
```

`config.lua` is gitignored — edit that copy, never the example. Everything in it
is optional; the client falls back to `127.0.0.1` defaults from `init.lua`.

### Pointing at your server

```lua
return {
  Services = {
    website = "",
    updater = "",
    stats = "",
    crash = "",
    feedback = "",
    status = {},                              -- must be a LIST, not a string
    createAccount = "http://127.0.0.1",
    Coins = "http://127.0.0.1",
  },
  Servers = {
    Local = "http://127.0.0.1/login.php",     -- your login endpoint
  },
}
```

`Servers` entries can be a plain string (the login URL) or a table when you need
`clientServicesLink` as well:

```lua
Servers = {
  MyServer = {
    name               = "My Server",
    loginLink          = "https://example.com/api/login",
    clientServicesLink = "https://example.com/api/status",
  },
}
```

### Developer switches

| Setting | What it does |
|---|---|
| `AUTO_LOGIN_DEBUG = true` | Logs straight in using `AUTO_LOGIN_EMAIL` / `AUTO_LOGIN_PASS` |
| `AUTO_SELECT_CHAR = false` | Stop at the character list instead of entering the world |
| `UI_HOTRELOAD = true` | `Ctrl+Shift+R` rebuilds the NPC dialogue window from its `.otui` |
| `DEV_TERMINAL = true` | `Ctrl+T` opens an in-client Lua console with the live log |
| `g_extras.set("debugWalking", true)` | Logs every prewalk and server confirmation. Very noisy. |

`DEVELOPERMODE` in `init.lua` gates the profiling window and the on-screen debug
buttons. Ship it as `false`.

---

## 3. First run

**Windows** — double-click `NyxosClient.exe` in the repository root, or:

```powershell
.\NyxosClient.exe
```

**Linux** — from the repository root:

```bash
./build/NyxosClient
```

The log is written to `Nyxos.log` next to the executable. When something does
not work, that file is the first place to look.

---

## 4. Where your data lives

| Platform | Path |
|---|---|
| Windows | `%APPDATA%\NyxosClient\Nyxos\` |
| Linux | `~/.local/share/NyxosClient/Nyxos/` |

That directory holds `config.otml`, per-character data, screenshots, crash
reports, and the explored minimap (`minimap.otmm`). Deleting it resets the
client to defaults without touching your build.

---

## 5. Next

Some client features need matching support on the server —
see [Server-side changes](server-side.md).
