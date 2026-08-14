---
title: Home
layout: default
nav_order: 1
---

# nyxos-otc

A Tibia **protocol 15.25** client built on OTClient, with a Cip-style interface.

These pages cover everything from a clean machine to a running client: what to
install, how to build it on Windows and Linux, where the game assets go, and
which server-side changes some features need.

---

## Start here

| Page | What it covers |
|---|---|
| [Running a prebuilt build](prebuilt.md) | **No compiler needed.** Download the executable and get it running |
| [Building on Windows](building-windows.md) | Visual Studio, vcpkg, the build script, common failures |
| [Building on Linux](building-linux.md) | Package list, CMake flags, known caveats |
| [Getting started](getting-started.md) | Assets, `config.lua`, first run |
| [Server-side changes](server-side.md) | What your server needs for ambience, sounds and the HWID handshake |

**Just want to try it?** You do not need a compiler. Every push to `main`
produces a Windows and a Linux executable — take one, combine it with a clone of
this repository and your own game assets, and you have a running client.
[Step by step](prebuilt.md).

---

## What you need before anything else

This client does **not** ship Tibia game data. Sprites, appearances and sound
files belong to CipSoft GmbH and are not redistributed here. You supply them
from a client installation you already have — see
[Getting started](getting-started.md).

Without those files the client compiles and starts, but shows no graphics.

---

## How the pieces fit

```
nyxos-otc/
├── src/            C++ engine: framework (rendering, net, sound, Lua) + client
├── modules/        Lua UI modules loaded at startup (login, game window, minimap…)
├── mods/           Lua feature modules (settings, store, analysers, trackers…)
├── data/           UI images, fonts, styles, shaders, sound index
│   ├── things/     <- your sprites and appearances go here
│   └── sounds/     <- your extracted .ogg files go here
├── init.lua        Entry point: app name, protocol version, service defaults
└── config.lua      Your local overrides (gitignored; copy from config.example.lua)
```

The C++ side is the engine. Nearly all interface and gameplay presentation is
Lua on top of it, so most changes do not need a recompile — edit the `.lua` or
`.otui` file and restart the client.

---

## License

[MIT](https://github.com/dbrkihel/nyxos-otc/blob/main/LICENSE), inherited from
OTClient. Covers this source code only, not Tibia game assets. See
[CREDITS](https://github.com/dbrkihel/nyxos-otc/blob/main/CREDITS.md).
