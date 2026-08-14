<#
.SYNOPSIS
    Builds NyxosClient with CMake + Ninja + MSVC, without opening Visual Studio.

.DESCRIPTION
    This is the CMake counterpart to compile.ps1 (which drives the vc17 .sln
    through MSBuild). It bootstraps vcpkg if needed, loads the MSVC environment
    from vcvars64.bat, configures with Ninja and builds.

    Only the C++ toolchain comes from Visual Studio -- the IDE is never opened.

.EXAMPLE
    .\compile-cmake.ps1
    Release build into build\ -> build\NyxosClient.exe

.EXAMPLE
    .\compile-cmake.ps1 -Config Debug
    Debug build into build-debug\

.EXAMPLE
    .\compile-cmake.ps1 -Clean
    Wipes the build dir first (dependencies stay cached in vcpkg).
#>
[CmdletBinding()]
param(
    # CMake build type.
    [ValidateSet('Release', 'Debug', 'RelWithDebInfo')]
    [string]$Config = 'Release',

    # vcpkg triplet. x64-windows links the deps as DLLs (copied next to the exe
    # automatically); x64-windows-static produces a standalone exe, matching the
    # /MT vc17 build, at the cost of a much longer first build.
    [string]$Triplet = 'x64-windows',

    # Build directory. Defaults to build\ for Release, build-<config>\ otherwise.
    [string]$BuildDir = '',

    # Path to an existing vcpkg clone. Defaults to $env:VCPKG_ROOT, then
    # <repo>\vcpkg, then $env:USERPROFILE\vcpkg (cloned on demand).
    [string]$VcpkgRoot = '',

    # Delete the build directory before configuring.
    [switch]$Clean,

    # Parallel compile jobs. Defaults to the CPU count.
    [int]$Jobs = 0,

    # Do not kill a running NyxosClient before linking.
    [switch]$NoKill,

    # Leave the binaries in the build dir instead of deploying them to the repo
    # root. Without deployment the exe only runs if the repo root is the current
    # working directory (see the note in the deploy step below).
    [switch]$NoDeploy
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------- build dir --
if (-not $BuildDir) {
    if ($Config -eq 'Release') { $BuildDir = Join-Path $repoRoot 'build' }
    else { $BuildDir = Join-Path $repoRoot "build-$($Config.ToLower())" }
} elseif (-not [System.IO.Path]::IsPathRooted($BuildDir)) {
    $BuildDir = Join-Path $repoRoot $BuildDir
}

if ($Clean -and (Test-Path $BuildDir)) {
    Write-Step "Removing $BuildDir"
    Remove-Item $BuildDir -Recurse -Force
}

# ------------------------------------------------------------------ vcvars --
Write-Step 'Locating the MSVC toolchain'
$vcvars = $null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath
    if ($vsPath) {
        $candidate = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
        if (Test-Path $candidate) { $vcvars = $candidate }
    }
}
if (-not $vcvars) {
    # vswhere is missing on some installs; fall back to globbing the usual roots.
    $globs = @(
        'C:\Program Files\Microsoft Visual Studio\*\*\VC\Auxiliary\Build\vcvars64.bat',
        'C:\Program Files (x86)\Microsoft Visual Studio\*\*\VC\Auxiliary\Build\vcvars64.bat'
    )
    foreach ($g in $globs) {
        $hit = Get-ChildItem $g -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { $vcvars = $hit.FullName; break }
    }
}
if (-not $vcvars) {
    throw "vcvars64.bat not found. Install Visual Studio (or the Build Tools) with the 'Desktop development with C++' workload."
}
Write-Host "    $vcvars"

# ------------------------------------------------------------------- vcpkg --
Write-Step 'Locating vcpkg'
if (-not $VcpkgRoot) {
    if ($env:VCPKG_ROOT -and (Test-Path (Join-Path $env:VCPKG_ROOT 'vcpkg.exe'))) {
        $VcpkgRoot = $env:VCPKG_ROOT
    } elseif (Test-Path (Join-Path $repoRoot 'vcpkg\vcpkg.exe')) {
        $VcpkgRoot = Join-Path $repoRoot 'vcpkg'
    } else {
        $VcpkgRoot = Join-Path $env:USERPROFILE 'vcpkg'
    }
}

if (-not (Test-Path (Join-Path $VcpkgRoot '.git')) -and -not (Test-Path (Join-Path $VcpkgRoot 'vcpkg.exe'))) {
    Write-Step "Cloning vcpkg into $VcpkgRoot"
    & git clone --depth 1 https://github.com/microsoft/vcpkg $VcpkgRoot
    if ($LASTEXITCODE -ne 0) { throw 'git clone of vcpkg failed' }
}
if (-not (Test-Path (Join-Path $VcpkgRoot 'vcpkg.exe'))) {
    Write-Step 'Bootstrapping vcpkg'
    & (Join-Path $VcpkgRoot 'bootstrap-vcpkg.bat') -disableMetrics
    if ($LASTEXITCODE -ne 0) { throw 'bootstrap-vcpkg.bat failed' }
}
Write-Host "    $VcpkgRoot"

$toolchain = Join-Path $VcpkgRoot 'scripts\buildsystems\vcpkg.cmake'
if (-not (Test-Path $toolchain)) { throw "vcpkg toolchain file not found at $toolchain" }

# --------------------------------------------------------------- ccache/etc --
if ($Jobs -le 0) { $Jobs = [int]$env:NUMBER_OF_PROCESSORS }

if (-not $NoKill) {
    $running = Get-Process -Name 'NyxosClient*' -ErrorAction SilentlyContinue
    if ($running) {
        Write-Warn "Killing running client so the linker can overwrite the exe"
        $running | Stop-Process -Force
    }
}

# ------------------------------------------------------- configure + build --
# Everything runs inside one cmd.exe: vcvars64 has to be in scope not just for
# our own compile, but for the sub-builds vcpkg spawns for each port (glew in
# particular fails with 'CMAKE_C_COMPILER not set' otherwise).
$cmdScript = Join-Path $env:TEMP "nyxos-cmake-build-$PID.cmd"
$lines = @(
    '@echo off'
    # vcvars64 warns on stderr on some installs (a missing vswhere.exe, for one)
    # without actually failing. Keep that noise off stderr: PowerShell 5.1 turns
    # any stderr line from a native command into a terminating error under
    # $ErrorActionPreference = 'Stop', which would abort the build for nothing.
    "call `"$vcvars`" 2>nul || exit /b 1"
    "cmake -S `"$repoRoot`" -B `"$BuildDir`" -G Ninja " +
        "-DCMAKE_BUILD_TYPE=$Config " +
        "-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl " +
        "-DVCPKG_TARGET_TRIPLET=$Triplet " +
        "-DCMAKE_TOOLCHAIN_FILE=`"$toolchain`" || exit /b 1"
    "cmake --build `"$BuildDir`" --parallel $Jobs || exit /b 1"
)
Set-Content -Path $cmdScript -Value $lines -Encoding ascii

Write-Step "Configuring and building ($Config, $Triplet, $Jobs jobs)"
Write-Warn 'First run compiles every vcpkg dependency from source - expect 30-60+ min. Later builds reuse the cache.'
# cmake/cl/vcpkg legitimately write warnings to stderr. Under 'Stop' those would
# become terminating errors, so judge success by the exit code instead.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & cmd.exe /c $cmdScript
    $code = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $prevEap
    Remove-Item $cmdScript -Force -ErrorAction SilentlyContinue
}

if ($code -ne 0) {
    throw "Build failed with exit code $code"
}

$exe = Join-Path $BuildDir 'NyxosClient.exe'
Write-Step 'Build succeeded'
if (Test-Path $exe) {
    $size = [math]::Round((Get-Item $exe).Length / 1MB, 1)
    Write-Host "    $exe ($size MB)" -ForegroundColor Green
}

# ---------------------------------------------------------------- deploy ----
# ResourceManager::setup() looks for init.lua in the current working directory
# first and in the executable's own directory second. Left in build\, the exe
# therefore only starts when launched with the repo root as the working dir --
# double-clicking it fails with "Unable to find working directory". Copying the
# exe and its DLLs to the root satisfies the second lookup, which is also the
# layout the vc17 solution produces. Everything copied here is gitignored.
if (-not $NoDeploy -and (Test-Path $exe)) {
    Write-Step "Deploying to the repo root"

    Copy-Item $exe $repoRoot -Force

    $dlls = @(Get-ChildItem (Join-Path $BuildDir '*.dll') -ErrorAction SilentlyContinue)
    foreach ($dll in $dlls) { Copy-Item $dll.FullName $repoRoot -Force }

    # The .pdb only exists for Debug/RelWithDebInfo; tools/symbolicate_crash.ps1
    # wants it next to the exe it symbolicates.
    $pdb = Join-Path $BuildDir 'NyxosClient.pdb'
    $pdbNote = ''
    if (Test-Path $pdb) {
        Copy-Item $pdb $repoRoot -Force
        $pdbNote = ' + NyxosClient.pdb'
    }

    Write-Host "    NyxosClient.exe + $($dlls.Count) DLL(s)$pdbNote -> $repoRoot" -ForegroundColor Green
    Write-Host '    Launch it with:' -ForegroundColor Gray
    Write-Host "      & '$(Join-Path $repoRoot 'NyxosClient.exe')'" -ForegroundColor Gray
    Write-Host '    (or just double-click it in Explorer)' -ForegroundColor Gray
} elseif (Test-Path $exe) {
    Write-Host '    Not deployed (-NoDeploy). Run it with the repo root as the working directory:' -ForegroundColor Gray
    Write-Host "      cd '$repoRoot'; & '$exe'" -ForegroundColor Gray
}
