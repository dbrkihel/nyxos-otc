---
title: Building on Linux
layout: default
nav_order: 4
---

# Building on Linux

Verified on **Ubuntu 24.04** (x86-64), GCC 14, CMake 3.28, Ninja 1.11 — the same
combination the CI workflow uses. Other distributions work if you can supply the
equivalent packages; the names below are Debian/Ubuntu.

{: .note }
> Linux is a secondary platform here. It builds and links, but it gets far less
> day-to-day testing than the Windows build. Report anything odd.

---

## 1. Install the dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake ninja-build git \
  libgl1-mesa-dev libglew-dev libx11-dev libopenal-dev \
  libfreetype-dev libprotobuf-dev protobuf-compiler \
  libphysfs-dev libogg-dev libvorbis-dev libzip-dev liblzma-dev \
  libssl-dev zlib1g-dev libluajit-5.1-dev nlohmann-json3-dev \
  libboost-filesystem-dev libboost-system-dev
```

Two of these trip people up:

- **`libluajit-5.1-dev`, not `liblua5.1-0-dev`.** The framework's
  `FindLuaJIT.cmake` looks for LuaJIT specifically. Plain Lua 5.1 will configure
  no further than `Could NOT find LuaJIT`.
- **Boost is required.** Without it you stop at `Could not find a package
  configuration file provided by "boost_filesystem"`.

---

## 2. Get the source

```bash
git clone https://github.com/dbrkihel/nyxos-otc.git
cd nyxos-otc
```

---

## 3. Configure and build

```bash
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_STATIC_LIBS=OFF

cmake --build build
```

{: .important }
> **`-DUSE_STATIC_LIBS=OFF` is not optional on Ubuntu.** The default is static
> linking, but Ubuntu ships no static `libopenal.a`, so CMake fails at generate
> time with `OPENAL_LIBRARY (ADVANCED) ... set to NOTFOUND`. Shared linking
> resolves it.

The binary lands at `build/NyxosClient` (~13 MB).

---

## 4. Run it

```bash
cd /path/to/nyxos-otc
./build/NyxosClient
```

Run it from the repository root, not from `build/` — the client resolves
`data/`, `modules/` and `mods/` relative to the working directory.

Configuration and saved data go to `~/.local/share/NyxosClient/Nyxos/` (the
PhysFS preference directory), which is the Linux equivalent of `%APPDATA%` on
Windows.

---

## 5. Known caveats

**X11 only.** The window backend is `x11window.cpp`. Under Wayland you are going
through XWayland, which works but is untested for input edge cases.

**Windows-only process helpers.** `Application::restart()` and the
bootstrap-rename helper in `ResourceManager` use `CreateProcessA` on Windows and
a `fork`/`exec` path on POSIX. The POSIX branch compiles and is
straightforward, but the auto-update flow that uses it is not exercised on
Linux.

**No installer or packaging.** There is no `.deb`, AppImage or Flatpak. You run
it from the source tree.

---

Next: [Getting started](getting-started.md)
