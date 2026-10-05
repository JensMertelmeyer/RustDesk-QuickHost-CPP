# Building in VS Code (Windows XP target)

This checkout includes an initial CMake build configuration and VS Code tasks.
It targets x86 Release, MSVC 14.16 / v141_xp, static CRT (/MT), and the Windows
5.01 subsystem. It is not yet build-verified: the compiler and compiled
dependencies must be installed first. XP compatibility also requires checking
dependency imports and testing the resulting executable on XP.

## 1. Install the compiler

Use Microsoft's [older Visual Studio downloads](https://visualstudio.microsoft.com/vs/older-downloads/)
to obtain **Build Tools for Visual Studio 2017** (15.9), or Visual Studio 2017.
Microsoft may require an account for older downloads. Run the installer yourself
and select:

- Desktop development with C++ / Visual C++ build tools.
- MSVC v141 x86/x64 tools, version 14.16.
- Windows XP support for C++ (v141_xp), including the Windows 7.1A SDK.
- A Windows 10 SDK for the other Windows API headers/tools.

As per [[https://learn.microsoft.com/en-gb/cpp/build/configuring-programs-for-windows-xp?view=msvc-170]], there is no paid subscription needed, but an account is required.


Do not substitute only the current MSVC toolset. The supplied preset deliberately
uses the Visual Studio 2017 generator. Installing just v141 into a newer Visual
Studio instance does not satisfy that preset.

Install [CMake](https://cmake.org/download/) **3.21 or newer**, adding it to PATH.
The generator requires CMake support for Visual Studio 2017. Git is also needed
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
From a PowerShell terminal in the repository:

```powershell
git clone https://github.com/microsoft/vcpkg C:\dev\vcpkg
& C:\dev\vcpkg\bootstrap-vcpkg.bat -disableMetrics
$env:VCPKG_VISUAL_STUDIO_PATH = 'C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools'
& C:\dev\vcpkg\vcpkg.exe install libvpx libyuv zstd --triplet x86-windows-static-v141xp --overlay-ports="$PWD\third_party\vcpkg_overlays\ports" --overlay-triplets="$PWD\third_party\vcpkg_overlays\triplets"
```

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
PowerShell/Command Prompt for VS 2017**, change to this repository. The following
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