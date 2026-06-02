# build.ps1 — Build script for arcdps-uploader
# Usage: .\build.ps1 [-Config Release|Debug] [-Docker]
#
# With -Docker flag, runs the build inside a Docker container.
# Without -Docker flag, runs the build locally (requires MSVC + vcpkg).

param(
    [ValidateSet("Release", "Debug")]
    [string]$Config = "Release",
    [switch]$Docker
)

$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot

if ($Docker) {
    Write-Host "=== Building with Docker ===" -ForegroundColor Cyan
    
    # Build the Docker image (first time only, cached after)
    Write-Host "Building Docker image..." -ForegroundColor Yellow
    docker build -t arcdps-uploader-build "$ProjectRoot"
    if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }
    
    # Run the build inside the container
    Write-Host "Running build inside container..." -ForegroundColor Yellow
    docker run --rm `
        -v "${ProjectRoot}:C:\src" `
        arcdps-uploader-build `
        powershell -Command "C:\src\build.ps1 -Config $Config"
    if ($LASTEXITCODE -ne 0) { throw "Docker container build failed" }
    
    Write-Host "=== Build complete! ===" -ForegroundColor Green
    Write-Host "Output: $ProjectRoot\build\$Config\d3d9_uploader.dll"
    exit 0
}

# --- Local / In-Container Build ---

Write-Host "=== arcdps-uploader Build ===" -ForegroundColor Cyan
Write-Host "Configuration: $Config"

# Initialize submodules if needed
if (-not (Test-Path "$ProjectRoot\revtc\Revtc.h")) {
    Write-Host "Initializing git submodules..." -ForegroundColor Yellow
    git -C "$ProjectRoot" submodule update --init --recursive
}

# Determine vcpkg toolchain
$VcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { "C:\vcpkg" }
$VcpkgToolchain = "$VcpkgRoot\scripts\buildsystems\vcpkg.cmake"

if (-not (Test-Path $VcpkgToolchain)) {
    throw "vcpkg toolchain not found at $VcpkgToolchain. Set VCPKG_ROOT or install vcpkg."
}

Write-Host "Using vcpkg at: $VcpkgRoot" -ForegroundColor Yellow

# Install vcpkg dependencies
Write-Host "Installing vcpkg dependencies..." -ForegroundColor Yellow
Push-Location $ProjectRoot
vcpkg install --triplet x64-windows-static
Pop-Location

# Find VS developer environment
$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $VsWhere) {
    $VsPath = & $VsWhere -latest -property installationPath
    $VcVarsAll = "$VsPath\VC\Auxiliary\Build\vcvarsall.bat"
    if (Test-Path $VcVarsAll) {
        Write-Host "Setting up MSVC environment..." -ForegroundColor Yellow
        cmd /c "`"$VcVarsAll`" x64 && set" | ForEach-Object {
            if ($_ -match "^(.*?)=(.*)$") {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
            }
        }
    }
}

# Create build directory
$BuildDir = "$ProjectRoot\build"
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

# Configure with CMake
Write-Host "Configuring with CMake..." -ForegroundColor Yellow
cmake -S "$ProjectRoot" -B "$BuildDir" `
    -G "Visual Studio 17 2022" -A x64 `
    -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
    -DVCPKG_TARGET_TRIPLET=x64-windows-static
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed" }

# Build
Write-Host "Building ($Config)..." -ForegroundColor Yellow
cmake --build "$BuildDir" --config $Config --target d3d9_uploader
if ($LASTEXITCODE -ne 0) { throw "CMake build failed" }

Write-Host ""
Write-Host "=== Build Successful! ===" -ForegroundColor Green

$DllPath = "$BuildDir\$Config\d3d9_uploader.dll"
if (Test-Path $DllPath) {
    $size = (Get-Item $DllPath).Length
    Write-Host "Output: $DllPath ($([math]::Round($size / 1KB)) KB)" -ForegroundColor Cyan
} else {
    Write-Host "Warning: DLL not found at expected path. Check build output." -ForegroundColor Yellow
}
