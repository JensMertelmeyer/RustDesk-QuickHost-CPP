# Building in VS Code (Windows XP target)

This checkout includes an initial CMake build configuration and VS Code tasks.
It targets x86 Release, MSVC 14.16 / v141_xp, static CRT (/MT), and the Windows
5.01 subsystem. It is not yet build-verified: the compiler and compiled
dependencies must be installed first. XP compatibility also requires checking
dependency imports and testing the resulting executable on XP.

## 1. Install the compiler

Use Microsoft's [older Visual Studio downloads](https://visualstudio.microsoft.com/vs/older-downloads/)
to obtain **Build Tools for Visual Studio 2019**, or Visual Studio 2019.
Microsoft may require an account for older downloads. Run the installer yourself
and select:

- Desktop development with C++ / Visual C++ build tools.
- Standard VS 2019 MSVC v142 x86/x64 tools (supplies the v160 MSBuild host files).
- MSVC v141 x86/x64 tools, version 14.16.
- Windows XP support for C++ (v141_xp), including the Windows 7.1A SDK.
- A Windows 10 SDK for the other Windows API headers/tools.

As per [[https://learn.microsoft.com/en-gb/cpp/build/configuring-programs-for-windows-xp?view=msvc-170]], there is no paid subscription needed, but an account is required.


Do not substitute only the current MSVC toolset. The supplied preset deliberately
uses the Visual Studio 2019 generator with the older v141_xp toolset. Build Tools
2017 can also provide the XP compiler, but requires changing the preset generator
to `Visual Studio 15 2017`.

The VS 2019 generator also needs that installation's standard C++ MSBuild host
files. Installing only the optional v141/XP components can leave
`MSBuild/Microsoft/VC/v160/Microsoft.Cpp.Default.props` missing. If so, modify the
installation to add the C++ workload and v142 tools. The preset still compiles
QuickHost with v141_xp/14.16, not v142.

Install [CMake](https://cmake.org/download/) **3.21 or newer**, adding it to PATH.
The generator requires CMake support for Visual Studio 2019. Git is also needed
for vcpkg. VS Code's Microsoft C/C++ and CMake Tools extensions are optional;
the build task itself does not require them. Restart VS Code after installation
so it inherits the updated PATH.

Run **Terminal > Run Task > QuickHost: Check prerequisites**. A missing dependency
prefix is expected until the next step. The check inspects prerequisite files;
it does not prove SDK completeness, library ABI, static linkage, or XP safety.

## 2. Build dependencies

All four dependencies must be **x86 Release static libraries using /MT**, built
with XP-compatible settings. Headers alone are insufficient; this checkout's
zstd directory contains no compiled library.

The repository's vcpkg overlay is a starting point for libvpx, libyuv and zstd.
From a PowerShell terminal in the **QuickHost repository root**, capture its
absolute path before changing directories. Set `$vcpkgRoot` to your actual vcpkg
checkout (the example below uses `C:\dev\vcpkg`):

```powershell
$repo = (Resolve-Path .).Path
$vcpkgRoot = 'C:\dev\vcpkg'
$overlayPorts = Join-Path $repo 'third_party\vcpkg_overlays\ports'
$overlayTriplets = Join-Path $repo 'third_party\vcpkg_overlays\triplets'
if (-not (Test-Path (Join-Path $overlayTriplets 'x86-windows-static-v141xp.cmake'))) { throw 'Run these setup commands from the QuickHost repository root.' }
git clone https://github.com/microsoft/vcpkg $vcpkgRoot
& "$vcpkgRoot\bootstrap-vcpkg.bat" -disableMetrics
$env:VCPKG_VISUAL_STUDIO_PATH = 'C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools'
& "$vcpkgRoot\vcpkg.exe" install libvpx libyuv zstd --triplet x86-windows-static-v141xp "--overlay-ports=$overlayPorts" "--overlay-triplets=$overlayTriplets"
```

Skip cloning and bootstrapping if that checkout is already ready. This custom
triplet is supplied by QuickHost, not vcpkg, so it will not appear in vcpkg's
built-in triplet list. `Invalid triplet` usually means the overlay path is wrong
or missing. In particular, `$PWD\third_party\...` is wrong from inside the vcpkg
directory. The absolute paths captured above work from either directory. Add
`--dry-run` to the install command to check the dependency plan without building.

Adjust the Visual Studio path if using another edition or installation directory.
This dependency command has not been tested here. Current vcpkg ports may require
a newer compiler or OS API baseline; libyuv and zstd have no XP-specific overlay
in this repository. If a port fails with v141, preserve the error and select a
compatible port revision rather than switching the compiler silently. Record
the successful vcpkg commit (`git -C C:\dev\vcpkg rev-parse HEAD`) for repeat builds.

The libvpx overlay explicitly disables its newer threading implementation and
uses v141_xp. The triplet itself selects v141/14.16, not an XP SDK for every
other dependency; inspect those libraries separately.

Use the bundled libsodium project for the remaining dependency. In the **Developer
PowerShell/Command Prompt for VS 2019**, change to this repository. The following
are PowerShell commands (MSBuild must be available in that shell):

```powershell
$deps = 'C:\dev\vcpkg\installed\x86-windows-static-v141xp'
New-Item -ItemType Directory -Force "$deps\lib", "$deps\include" | Out-Null
msbuild third_party\libsodium\libsodium.sln /t:libsodium /m /p:Configuration=Release /p:Platform=Win32 /p:PlatformToolset=v141_xp /p:PostBuildEventUseInBuild=false "/p:OutDir=$deps/lib/"
if ($LASTEXITCODE -ne 0) { throw 'libsodium build failed' }
Copy-Item third_party\libsodium\src\libsodium\include\sodium.h "$deps\include"
Copy-Item third_party\libsodium\src\libsodium\include\sodium "$deps\include" -Recurse -Force
```

The bundled project's Release configuration uses /MT. Its pre-build step generates
headers; the post-build test event is disabled above because this command builds
only the library, not the bundled test executables. The expected output is
`$deps/lib/libsodium.lib`. This command still requires verification on the installed
toolchain.

Alternatively, use a separate dependency prefix with `include/` and `lib/`.
CMake accepts `libsodium.lib`/`sodium.lib`, `vpx.lib`/`libvpx.lib`,
`yuv.lib`/`libyuv.lib`, and `zstd_static.lib`/`libzstd_static.lib`/`zstd.lib`/`libzstd.lib`.
Do not provide DLL import libraries. Use matching headers from the same builds.

## 3. Configure and build

Set the dependency prefix in a normal PowerShell terminal:

```powershell
[Environment]::SetEnvironmentVariable('QUICKHOST_DEPS_ROOT', 'C:\dev\vcpkg\installed\x86-windows-static-v141xp', 'User')
$env:QUICKHOST_DEPS_ROOT = 'C:\dev\vcpkg\installed\x86-windows-static-v141xp'
cmake --preset xp-x86-release
cmake --build --preset xp-x86-release
```

Completely restart VS Code after setting the persistent variable. Then **Ctrl+Shift+B**
runs **QuickHost: Build XP x86 Release**, which configures before building.
The expected executable is `build/xp-x86-release/bin/Release/RustDeskQS.exe`.
The resource compiler embeds the supplied icons and PNGs. No Rust toolchain is
required. Build does not launch the host or initiate remote connections.

If you change dependency prefixes after configuring, use
`cmake --fresh --preset xp-x86-release` with CMake 3.24+ to clear cached paths.

## 4. Verify XP compatibility

Use `dumpbin /headers` and `dumpbin /imports` from the VS developer terminal
on the executable. Confirm x86, subsystem version 5.01, no required CRT DLLs,
and no statically imported Vista-or-newer APIs. Linking /MT and setting the
subsystem version do not by themselves establish XP compatibility.

Finally test on an isolated XP machine/VM: application startup, VP8 connection,
clipboard and file transfer. H.264 uses dynamically loaded Media Foundation
and is not an XP component. Test newer Windows separately. Until those checks
pass, treat the executable as an experimental build rather than an XP release.