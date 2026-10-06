$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$missing = @()

$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if ($cmake) {
    $versionOutput = @(& $cmake.Source --version)
    $versionOutput | Write-Output
    if ($LASTEXITCODE -ne 0 -or $versionOutput.Count -eq 0 -or
        $versionOutput[0] -notmatch '^cmake version (\d+\.\d+\.\d+)') {
        $missing += 'A working CMake installation'
    } elseif ([version]$Matches[1] -lt [version]'3.21.0') {
        $missing += 'CMake 3.21 or newer'
    }
} else {
    $missing += 'CMake 3.21 or newer on PATH'
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $installations = @(& $vswhere -products '*' -version '[15.0,17.0)' -property installationPath)
    $compatibleInstallations = 0
    $toolchainIssues = @()
    if ($installations.Count -eq 0) {
        $missing += 'Visual Studio / Build Tools 2017 or 2019 with MSVC 14.16 and v141_xp'
    }
    foreach ($installation in $installations) {
        Write-Output "Visual Studio: $installation"
        $toolsets = @(Get-ChildItem (Join-Path $installation 'VC\Tools\MSVC') -Directory -Filter '14.16.*' -ErrorAction SilentlyContinue)
        if ($toolsets.Count -eq 0) {
            $toolchainIssues += "MSVC 14.16 in $installation"
        }
        $xpPropsPaths = @(
            (Join-Path $installation 'Common7\IDE\VC\VCTargets\Platforms\Win32\PlatformToolsets\v141_xp\Toolset.props'),
            (Join-Path $installation 'MSBuild\Microsoft\VC\*\Platforms\Win32\PlatformToolsets\v141_xp\Toolset.props')
        )
        $xpProps = @($xpPropsPaths | Where-Object { Test-Path $_ })
        if ($xpProps.Count -eq 0) {
            $toolchainIssues += "Windows XP support for C++ (v141_xp) in $installation"
        }
        if ($toolsets.Count -gt 0 -and $xpProps.Count -gt 0) {
            $compatibleInstallations++
            Write-Output "XP toolchain found: MSVC $($toolsets[0].Name), v141_xp"
        }
    }
    if ($compatibleInstallations -eq 0) {
        $missing += $toolchainIssues
    }
} else {
    $missing += 'Visual Studio Installer / Build Tools 2017 or 2019'
}

foreach ($asset in @('rustdesk_app.ico', 'rustdesk_tray.ico', 'qslogo.png', 'material_more_vert.png', 'material_refresh.png')) {
    if (-not (Test-Path (Join-Path $root "resources\$asset"))) {
        $missing += "resources\$asset"
    }
}

if (-not $env:QUICKHOST_DEPS_ROOT) {
    $missing += 'QUICKHOST_DEPS_ROOT pointing to x86 /MT dependency libraries and headers'
} else {
    Write-Output "Dependency prefix: $env:QUICKHOST_DEPS_ROOT"
    foreach ($header in @('sodium.h', 'vpx\vp8cx.h', 'libyuv\convert.h', 'zstd.h')) {
        if (-not (Test-Path (Join-Path $env:QUICKHOST_DEPS_ROOT "include\$header"))) {
            $missing += "Dependency header: $header"
        }
    }
    foreach ($names in @(@('libsodium.lib', 'sodium.lib'), @('vpx.lib', 'libvpx.lib'), @('yuv.lib', 'libyuv.lib'), @('zstd_static.lib', 'libzstd_static.lib', 'zstd.lib', 'libzstd.lib'))) {
        $found = @($names | Where-Object { Test-Path (Join-Path $env:QUICKHOST_DEPS_ROOT "lib\$_") })
        if ($found.Count -eq 0) {
            $missing += "Dependency library: $($names -join ' or ')"
        }
    }
}

if ($missing.Count -gt 0) {
    Write-Output "`nMissing prerequisites:"
    $missing | ForEach-Object { Write-Output "  - $_" }
    exit 1
}
Write-Output "`nPrerequisite files found. A successful build and XP runtime test are still required."