---
title: Building on Windows
layout: default
nav_order: 2
---

# Building on Windows

This is the primary supported platform. A clean build takes 30–60 minutes the
first time because vcpkg compiles every dependency from source; later builds
reuse that cache and finish in a few minutes.

---

## 1. Requirements

### Visual Studio

Install **Visual Studio 2022 or 2026** with the **"Desktop development with
C++"** workload. The Build Tools SKU (no IDE) is enough — the command-line path
never opens Visual Studio.

Download: <https://visualstudio.microsoft.com/downloads/>

{: .important }
> Selecting the workload matters more than the edition. Community works fine.
> Without "Desktop development with C++" you get the IDE but no compiler, and
> the build fails at "Locating the MSVC toolchain".

### Git

Needed on `PATH` — the build script uses it to fetch vcpkg on first run.

Download: <https://git-scm.com/download/win>

Verify:

```powershell
git --version
```

### That's it

You do **not** need to install vcpkg, CMake or Ninja by hand. The build script
bootstraps vcpkg, and CMake and Ninja come with the Visual Studio C++ workload.

---

## 2. Get the source

```powershell
git clone https://github.com/dbrkihel/nyxos-otc.git
cd nyxos-otc
```

---

## 3. Build

```powershell
.\compile-cmake.ps1 -Config Release
```

That single command:

1. locates `vcvars64.bat` and loads the MSVC environment,
2. finds or clones vcpkg (`$env:VCPKG_ROOT`, then `.\vcpkg`, then `%USERPROFILE%\vcpkg`),
3. builds every dependency listed in `vcpkg.json`,
4. configures and builds with CMake + Ninja,
5. copies `NyxosClient.exe` and its DLLs to the repository root.

On success you get:

```
==> Build succeeded
    ...\build\NyxosClient.exe (7 MB)
==> Deploying to the repo root
    NyxosClient.exe + 20 DLL(s) -> ...\nyxos-otc
```

### Useful options

| Flag | Effect |
|---|---|
| `-Config Debug` | Debug build with symbols |
| `-Clean` | Wipes the build dir first (vcpkg cache is kept) |
| `-BuildDir build-x` | Build into a different directory |

---

## 4. Building from the Visual Studio IDE instead

A solution is kept in `vc17/` if you want the IDE debugger:

```powershell
.\compile.ps1
```

{: .warning }
> VS 2026 ships toolset **v145**, which the solution targets by default. On
> VS 2022 you only have **v143**, so pass `-Toolset v143`.

---

## 5. Common failures

### `Cannot open include file: 'iso646.h'`

You invoked `cmake --build` directly, without the MSVC environment loaded. Use
`compile-cmake.ps1`, which loads `vcvars64.bat` first — or open a "x64 Native
Tools Command Prompt" and build from there.

### `Locating the MSVC toolchain` fails

Visual Studio is installed but the C++ workload is not. Reopen the Visual Studio
Installer, click Modify, and tick "Desktop development with C++".

### vcpkg takes forever on the first run

Expected. It is compiling protobuf, OpenSSL, Boost and the rest from source. It
happens once per machine — the packages are cached in your vcpkg root and shared
across every project that uses it.

### The build succeeds but the client shows nothing

You have no game assets yet. See [Getting started](getting-started.md).

---

Next: [Getting started](getting-started.md)
