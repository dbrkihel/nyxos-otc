---
title: Running a prebuilt build
layout: default
nav_order: 2
---

# Running a prebuilt build

If you want to try the client without setting up a compiler, every push to
`main` produces a ready-made executable. This page takes you from that download
to a running client.

{: .important }
> **The download is the executable only.** It is not a complete client. You also
> need this repository's `data/`, `modules/` and `mods/` directories, and your
> own Tibia game assets. That is three pieces, and all three are required —
> the steps below assemble them.

Why it is split: `data/` alone is around 180 MB of interface art that does not
change between builds. Shipping it inside every artifact would mean
re-downloading it for a one-line code change.

---

## What you will end up with

```
nyxos-otc/                      <- a clone of this repository
├── NyxosClient.exe             <- from the download
├── *.dll                       <- from the download (Windows only)
├── data/                       <- from the clone
│   ├── things/1525/            <- your game assets
│   └── sounds/                 <- your sound files
├── modules/                    <- from the clone
├── mods/                       <- from the clone
└── config.lua                  <- you create this
```

---

## Step 1 — Get the repository

You need Git for this. If you do not have it: <https://git-scm.com/downloads>

```bash
git clone https://github.com/dbrkihel/nyxos-otc.git
cd nyxos-otc
```

No compiler needed — you are only taking the Lua modules and the interface art.

---

## Step 2 — Download the executable

### From a build of the latest code

1. Open the [Actions tab](https://github.com/dbrkihel/nyxos-otc/actions).
2. Click the most recent **Build** run with a green check.
3. Scroll to **Artifacts** at the bottom.
4. Download `nyxos-otc-windows-x64` or `nyxos-otc-linux-x64`.

{: .note }
> Downloading artifacts requires being signed in to GitHub — that is a GitHub
> restriction, not a choice made here. Artifacts also expire after 90 days.

### From a release

Tagged releases on the [Releases page](https://github.com/dbrkihel/nyxos-otc/releases)
carry the same archives, do not expire, and need no account.

### Unpack it into the clone

Extract the archive so the executable sits **in the repository root**, next to
`init.lua` — not in a subfolder.

**Windows:** `NyxosClient.exe` plus around 20 `.dll` files. All of them go in
the root. The client will not start if the DLLs are missing or left in a
subfolder.

**Linux:** a single `NyxosClient` file. Make it executable:

```bash
chmod +x NyxosClient
```

---

## Step 3 — Add game assets

{: .warning }
> Sprites, appearances and sounds belong to **CipSoft GmbH** and are not
> distributed here. Copy them from a Tibia client installation you already
> have. Without them the client starts but shows nothing.

### Graphics (required)

```
data/things/1525/
├── appearances.dat
├── catalog-content.json
└── sprites-*.bmp.lzma
```

In an official installation these live under `assets/` (sometimes
`packages/Tibia/assets/`). Copy the contents across.

### Sounds (optional)

Copy the `sound-*.ogg` files from the same `assets/` directory into
`data/sounds/`. The sound index (`soundbank.json`) is already in the clone.

Skip this and the client runs normally, just silently.

---

## Step 4 — Point it at a server

```bash
cp config.example.lua config.lua          # Windows: copy config.example.lua config.lua
```

Open `config.lua` and set the login endpoint:

```lua
Servers = {
  Local = "http://127.0.0.1/login.php",   -- your server
},
```

Everything else can stay as it is. Full reference:
[Getting started](getting-started.md).

---

## Step 5 — Run it

**Windows** — double-click `NyxosClient.exe`, or from the repository root:

```powershell
.\NyxosClient.exe
```

**Linux** — from the repository root:

```bash
./NyxosClient
```

{: .important }
> Run it **from the repository root**. The client resolves `data/`, `modules/`
> and `mods/` relative to the working directory, so launching it from anywhere
> else finds nothing.

---

## Linux: runtime libraries

The Linux build links against system libraries rather than bundling them, so
they have to be present. On Ubuntu 24.04:

```bash
sudo apt-get update
sudo apt-get install -y \
  libgl1 libglew2.2 libx11-6 libopenal1 libfreetype6 \
  libluajit-5.1-2 libphysfs1 libprotobuf32t64 libssl3t64 \
  zlib1g libzip4t64 liblzma5 libbz2-1.0 libpng16-16t64
```

That list was taken from `ldd` against an actual build, not from the build
requirements — it is what the binary genuinely loads. Everything else it needs
(X11 helpers, brotli, ALSA) arrives as a dependency of the packages above.

{: .note }
> The `t64` suffixes are specific to Ubuntu 24.04 and its 64-bit `time_t`
> transition. On other releases and distributions these are named differently.

If it still refuses to start, ask the binary what it is missing:

```bash
ldd ./NyxosClient | grep "not found"
```

That line names the exact library, whatever your distribution calls the package.

---

## When something does not work

Check `Nyxos.log`, written next to the executable. It is the first place to
look, and it usually names the problem directly.

| Symptom | Cause |
|---|---|
| Window opens, everything black or missing | No game assets in `data/things/1525` |
| Will not start, complains about a DLL | DLLs left in a subfolder, or not extracted |
| Starts but finds no files, log full of missing paths | Launched from the wrong working directory |
| Runs but plays no sound | No `.ogg` files in `data/sounds` — expected |
| Linux: `error while loading shared libraries` | Missing runtime library, see above |

Still stuck? [Open an issue](https://github.com/dbrkihel/nyxos-otc/issues/new/choose)
and attach `Nyxos.log`.

---

## Keeping it current

The executable and the Lua tree are versioned together, so update both:

```bash
git pull
```

then download the executable from a newer build. A stale executable against an
updated clone can fail in confusing ways — if odd behaviour appears right after
a `git pull`, refresh the binary before investigating.
