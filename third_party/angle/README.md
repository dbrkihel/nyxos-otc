# Vendored ANGLE (Google) — DirectX/OPENGL_ES build

The `DirectX` build configuration compiles against GLES2 + EGL and uses **ANGLE**
to translate those calls to a GPU backend at runtime. ANGLE is selected per-launch
from the "Graphics Engine" option (see `mods/client_settings/options/graphics.otui`
and `win32window.cpp::getPreferredGraphicsBackend`).

## Why vendored instead of vcpkg

The vcpkg `angle` port (chromium/7258) only builds the **D3D11, D3D9 and GL**
backends — its WebKit `gni-to-cmake` buildsystem never converts
`libANGLE/renderer/vulkan/BUILD.gn`, so there is **no Vulkan backend**. Confirmed
with `dumpbin /archivemembers ANGLE.lib`: D3D11=36 objs, D3D9=21, GL=4, Vulkan=0.

Google's official ANGLE (the one shipped inside Chrome/Edge) **does** build the
Vulkan backend by default on Windows. So `angle` was removed from `vcpkg.json` and
a prebuilt Google ANGLE is vendored here instead.

## Contents

```
include/      EGL, GLES2, GLES3, KHR headers (stable API; copied from vcpkg)
lib/x64/      libEGL.lib, libGLESv2.lib   -> import libs (NOT static libs)
bin/x64/      libEGL.dll, libGLESv2.dll, d3dcompiler_47.dll, vulkan-1.dll  -> runtime DLLs
```

The DirectX|x64 project config adds `include/` to the include path, `lib/x64/` to the
library path, links `libEGL.lib;libGLESv2.lib`, and a PostBuildEvent copies every
`bin/x64/*.dll` next to the executable. **All four DLLs must ship with the client.**

`vulkan-1.dll` is the Vulkan loader and is **required for the Vulkan backend**: ANGLE's
Vulkan renderer fails to initialize against an arbitrary system loader, but works with
the co-located loader Chrome/Edge ship (this exact failure was observed — Vulkan init
returned `VK_ERROR_INITIALIZATION_FAILED` until `vulkan-1.dll` was placed next to the exe).
`d3dcompiler_47.dll` is loaded at runtime by the D3D11/D3D9 backends.

## Backends available in this build

Vulkan, Direct3D 11, Direct3D 11 (WARP) and Direct3D 9 all work. The desktop-GL backend
(`EGL_PLATFORM_ANGLE_TYPE_OPENGL_ANGLE`, the combo's "OpenGL" entry) is **not** compiled
into Chrome/Edge ANGLE, so selecting it falls back to the automatic chain (D3D11). Native
desktop OpenGL remains available only through the separate `OpenGL` build config
(`NyxosClient_gl_x64.exe`), which does not use ANGLE.

## Source / version

`bin/x64/*.dll` were taken from Microsoft Edge
(`C:\Program Files (x86)\Microsoft\Edge\Application\149.0.4022.69\`):

- `libGLESv2.dll` — ANGLE 2.1.46022 (git hash dfec10e842a8)
- `libEGL.dll`
- `vulkan-1.dll` — Khronos Vulkan loader (the build Edge ships)
- `d3dcompiler_47.dll` — Microsoft DirectX redistributable

ANGLE and the Vulkan loader are BSD/Apache licensed; `d3dcompiler_47.dll` is a
redistributable DirectX component. All are redistributable.

## Regenerating the import libs (from a Developer prompt)

```powershell
$dll = 'bin\x64\libGLESv2.dll'; $base = 'libGLESv2'
$names = (dumpbin /exports $dll) -match '^\s+\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+\S' |
         ForEach-Object { ($_ -split '\s+')[-1] } | Sort-Object -Unique
@("LIBRARY $base","EXPORTS") + $names | Set-Content "lib\x64\$base.def" -Encoding ascii
lib /def:lib\x64\$base.def /machine:x64 /out:lib\x64\$base.lib
```

## Caveats

- **x64 only.** `DirectX|Win32` would need an x86 ANGLE vendored under `lib/Win32`
  and `bin/Win32`; it is not a supported build target.
- To update ANGLE, replace the three DLLs from a newer Chrome/Edge, regenerate the
  import libs, and (if the API changed) refresh the headers.
