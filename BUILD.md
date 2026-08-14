# Building NyxosClient (Windows)

There are two supported build paths, and both produce the same client:

| Path | Driver | When to use |
|---|---|---|
| **CMake + Ninja** | `compile-cmake.ps1` | Command line only; never opens the IDE. Also the path CI uses. |
| **Visual Studio solution** (`vc17/`) | `compile.ps1` | When you want the VS debugger/IDE, or the ANGLE/DirectX configurations. |

Neither path needs you to install vcpkg by hand — both scripts bootstrap it on
the first run.

## Prerequisites

1. **Visual Studio 2022 or 2026** with the **"Desktop development with C++"**
   workload. Only the compiler is used by the CMake path; the IDE is never opened.
   - The Build Tools SKU (no IDE) is enough for `compile-cmake.ps1`.
   - For the `vc17/` path: VS **2026** ships toolset **v145** (the repo default);
     on VS **2022** you only have **v143**, so pass `-Toolset v143` to `compile.ps1`.
2. **Git** on `PATH` (used to fetch vcpkg on the first build).
3. **CMake ≥ 3.16** and **Ninja** on `PATH` — CMake path only.
   Both ship with the VS "Desktop development with C++" workload; otherwise
   `winget install Kitware.CMake Ninja-build.Ninja`.

## What the repo does NOT ship (vcpkg provides it)

The C++ dependencies (Boost, OpenSSL, protobuf + `protoc.exe`, PhysFS, LuaJIT,
GLEW, libzip, freetype, …) are **not** committed. They are declared in
[`vcpkg.json`](vcpkg.json) and built by **vcpkg** into a gitignored tree
(`build/vcpkg_installed/` for CMake, `vcpkg_installed/` for the `.sln`).

> **The first build is slow.** vcpkg compiles every dependency from source —
> expect **30–60+ minutes and a few GB**. Subsequent builds reuse the cache and
> take minutes. Both build paths share vcpkg's binary cache, so the second path
> you try is much faster than the first.

---

## Build with CMake (no Visual Studio IDE)

From the repo root:

```powershell
.\compile-cmake.ps1                      # Release  -> build\NyxosClient.exe
.\compile-cmake.ps1 -Config Debug        # Debug    -> build-debug\NyxosClient.exe
.\compile-cmake.ps1 -Clean               # wipe the build dir first (deps stay cached)
.\compile-cmake.ps1 -Jobs 8              # limit parallelism
```

The script locates `vcvars64.bat`, bootstraps vcpkg if needed, then runs
`cmake -G Ninja` + `cmake --build`. It does not open Visual Studio.

Useful switches:

```powershell
.\compile-cmake.ps1 -VcpkgRoot C:\dev\vcpkg          # use an existing vcpkg clone
.\compile-cmake.ps1 -Triplet x64-windows-static      # standalone exe, no DLLs (slower first build)
.\compile-cmake.ps1 -BuildDir build-experiment       # build somewhere else
.\compile-cmake.ps1 -NoKill                          # don't kill a running client before linking
```

By default the triplet is `x64-windows`, which links the dependencies as DLLs;
vcpkg copies them next to `NyxosClient.exe` automatically. Use
`-Triplet x64-windows-static` for a single self-contained exe — that is what the
`vc17/` solution produces (`/MT`), at the cost of a much longer first build.

### Running it

On success the script copies `NyxosClient.exe` and its runtime DLLs from the
build dir into the **repo root**, which is the same layout the `vc17/` solution
produces. So just:

```powershell
& .\NyxosClient.exe
```

or double-click it in Explorer. Everything deployed there is gitignored.

This copy is what makes the client startable from anywhere.
`ResourceManager::setup()` looks for `init.lua` in the current working directory
first and in the executable's own directory second — with the exe sitting next
to `init.lua`, `data/`, `modules/` and `mods/`, the second lookup always
succeeds. Left in `build\`, the exe only starts when launched *with the repo
root as the working directory*, and double-clicking it fails with
`Unable to find working directory (or data.zip)`.

Pass `-NoDeploy` to skip the copy and keep the binaries in the build dir:

```powershell
.\compile-cmake.ps1 -NoDeploy
cd C:\dev\NyxosClient; & .\build\NyxosClient.exe   # working dir must be the root
```

> A `Debug` build deploys under the same `NyxosClient.exe` name and overwrites
> whatever Release binary is in the root (unlike the `vc17/` path, which names it
> `NyxosClient_debug_x64.exe`). Use `-NoDeploy` if you want to keep both.

### Driving CMake yourself

If you'd rather not use the wrapper — from a **Developer PowerShell for VS**
(so `cl.exe` is on `PATH`):

```powershell
$env:VCPKG_ROOT = 'C:\dev\vcpkg'
cmake --preset windows-x64
cmake --build --preset windows-x64
```

[`CMakePresets.json`](CMakePresets.json) defines `windows-x64`,
`windows-x64-debug`, `windows-x64-static` and `linux-x64`. The presets require
`VCPKG_ROOT` to be set and an MSVC environment already loaded — `compile-cmake.ps1`
does both for you, which is why it is the recommended entry point.

Or fully by hand:

```powershell
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release `
      -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl `
      -DCMAKE_TOOLCHAIN_FILE=C:\dev\vcpkg\scripts\buildsystems\vcpkg.cmake
cmake --build build --parallel
```

### CMake options

| Option | Default | Effect |
|---|---|---|
| `FRAMEWORK_SOUND` | `ON` | OpenAL/Vorbis audio |
| `FRAMEWORK_GRAPHICS` | `ON` | Renderer + UI (off = headless) |
| `FRAMEWORK_NET` | `ON` | Networking |
| `FRAMEWORK_XML` | `ON` | TinyXML |
| `WINDOWS_CONSOLE` | `OFF` | `ON` keeps a console window attached — handy for `g_logger` output |
| `CRASH_HANDLER` | `ON` | Crash report generation |
| `LUAJIT` | `ON` | LuaJIT instead of stock Lua |

---

## Build with the Visual Studio solution

```powershell
.\compile.ps1 -Config DirectX            # release-style ANGLE/D3D build -> NyxosClient.exe
.\compile.ps1 -Config Debug              # dev build           -> NyxosClient_debug_x64.exe
.\compile.ps1 -Config OpenGL             # release-style GL    -> NyxosClient_gl_x64.exe
.\compile.ps1 -Config DirectX -Toolset v143   # if you are on Visual Studio 2022
```

This path drives `vc17/NyxosClient.sln` through MSBuild and relies on vcpkg's
MSBuild integration (`vcpkg integrate install`, which the script performs).

The manual equivalent of the vcpkg setup:

```powershell
git clone https://github.com/microsoft/vcpkg C:\dev\vcpkg
C:\dev\vcpkg\bootstrap-vcpkg.bat
C:\dev\vcpkg\vcpkg.exe integrate install   # the .sln does NOT import vcpkg targets itself
```

The triplet is `x64-windows-static` (x64) / `x86-windows-static` (Win32).

### Differences from the CMake build

- The `.sln` has **DirectX/ANGLE** configurations that use the prebuilt
  `libEGL`/`libGLESv2` under `third_party/angle`. The CMake build targets desktop
  OpenGL (GLEW) only.
- The `.sln` links the CRT statically (`/MT`); the default CMake triplet links
  the dependencies as DLLs. Use `-Triplet x64-windows-static` to match.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Compatibility with CMake < 3.5 has been removed` | You are on an old checkout — the `cmake_minimum_required` bump is in this branch. `git pull`. |
| `vcvars64.bat not found` | Install the "Desktop development with C++" workload (or the Build Tools SKU). |
| `'vswhere.exe' is not recognized` during the build | Harmless warning from `vcvars64.bat`; the script already suppresses it and keeps going. |
| CMake configure ends at `Detecting compiler hash for triplet ...` for a long time | Normal — vcpkg is building the ~90 dependencies. Watch `build\vcpkg-manifest-install.log`. |
| `curl operation failed with error code 35 (SSL connect error)` while vcpkg downloads a port | Transient network failure, not a build problem. Just run the script again — vcpkg keeps everything it already built and resumes from the failed port. |
| `CMake was unable to find a build program corresponding to "Ninja"` | Usually a cascade from a vcpkg failure earlier in the same configure — read further up the log for the real error. If it is genuine, install Ninja and make sure it is on `PATH`. |
| `protoc not found - is the vcpkg toolchain file being used?` | You ran `cmake` without `-DCMAKE_TOOLCHAIN_FILE=.../vcpkg.cmake`. Use `compile-cmake.ps1` or pass the toolchain. |
| `MSB8066 ... protoc ... exited with code 3` (`.sln` path) | `protoc.exe` missing under `vcpkg_installed/<triplet>/tools/protobuf/`. Finish the vcpkg setup above so the manifest restore runs. |
| Linker can't find boost/openssl/etc. (`.sln` path) | vcpkg MSBuild integration not active — run `vcpkg integrate install`. |
| `error MSB8020 ... v145 ... cannot be found` | You're on VS 2022. Build with `-Toolset v143`. |
| Build can't overwrite `NyxosClient*.exe` (LNK1104) | The client is running. Both scripts kill it automatically unless you pass `-NoKill`. |
| Client starts and immediately exits / can't find `init.lua` | You ran the exe from `build\`. Run it from the repo root. |
