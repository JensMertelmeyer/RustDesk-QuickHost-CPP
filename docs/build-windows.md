# Build on Windows with VS Code

Target: **x86 Release, static CRT (/MT), MSVC 14.16 / v141_xp**.
Use a Windows 10/11 development machine. No Rust toolchain is needed.

## 1. Install tools

- [VS Code](https://code.visualstudio.com/).
- [Git for Windows](https://git-scm.com/downloads/win), available on PATH.
- [CMake](https://cmake.org/download/), version **3.21+**. Select **Add CMake to PATH**.
- **Build Tools for Visual Studio 2019**, from [Microsoft's older downloads](https://visualstudio.microsoft.com/vs/older-downloads/). An account may be required.

In the Build Tools installer, select **Desktop development with C++ / C++ build tools**, plus:

- **MSVC v142 x86/x64 tools** (required VS 2019 build infrastructure).
- **MSVC v141 x86/x64 tools**, version **14.16** (the compiler we use).
- **Windows XP support for C++**, including the **Windows 7.1A SDK**.
- **Windows 10 SDK**.

Keep both v142 and v141 installed. Restart VS Code after installation.
VS Code extensions are optional; the supplied build tasks work without them.

## 2. Build dependencies (once)

Open this project folder in VS Code. Open a **PowerShell** terminal at the
project root, where `CMakePresets.json` lives. Run all blocks below in the
**same terminal**, in order. Adjust `$vs` only if your installation path differs.

```powershell
$repo = (Get-Location).Path
$vcpkg = Join-Path $repo 'vcpkg'
$vs = 'C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools'
$deps = Join-Path $vcpkg 'installed\x86-windows-static-v141xp'

git clone https://github.com/microsoft/vcpkg $vcpkg
& "$vcpkg\bootstrap-vcpkg.bat" -disableMetrics
$env:VCPKG_VISUAL_STUDIO_PATH = $vs
& "$vcpkg\vcpkg.exe" install libvpx libyuv zstd `
	--triplet x86-windows-static-v141xp `
	"--overlay-ports=$repo\third_party\vcpkg_overlays\ports" `
	"--overlay-triplets=$repo\third_party\vcpkg_overlays\triplets"
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed' }
```

Skip cloning/bootstrap if vcpkg is already set up there. The custom triplet comes
from this project, so **keep both overlay arguments**. Wait for installation to finish.

## 3. Build bundled libsodium (once)

No developer shell is needed; call MSBuild directly:

```powershell
New-Item -ItemType Directory -Force "$deps\lib", "$deps\include" | Out-Null
& "$vs\MSBuild\Current\Bin\MSBuild.exe" `
	"$repo\third_party\libsodium\libsodium.sln" /t:libsodium /m `
	/p:Configuration=Release /p:Platform=Win32 /p:PlatformToolset=v141_xp `
	/p:PostBuildEventUseInBuild=false "/p:OutDir=$deps/lib/"
if ($LASTEXITCODE -ne 0) { throw 'libsodium build failed' }
Copy-Item "$repo\third_party\libsodium\src\libsodium\include\sodium.h" "$deps\include"
Copy-Item "$repo\third_party\libsodium\src\libsodium\include\sodium" "$deps\include" -Recurse -Force
```

## 4. Build QuickHost

Build from the project root. CMake automatically uses
`vcpkg/installed/x86-windows-static-v141xp` inside this project:

```powershell
cmake --preset xp-x86-release
if ($LASTEXITCODE -ne 0) { throw 'QuickHost configuration failed' }
cmake --build --preset xp-x86-release
```

Output: **`build/xp-x86-release/bin/Release/RustDeskQS.exe`**.

In VS Code, use **Ctrl+Shift+B**. It configures and builds automatically.
To check setup, use **Terminal > Run Task > QuickHost: Check prerequisites**.
Set `QUICKHOST_DEPS_ROOT` only if your dependencies are stored elsewhere.

This setup built successfully on our machine. A fresh-machine installation has
not been retested, and XP runtime compatibility still requires testing on XP.