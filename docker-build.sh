#!/bin/bash
# docker-build.sh — Cross-compile arcdps-uploader for Windows x64 from Linux
set -euo pipefail

CONFIG="${1:-Release}"
echo "=== arcdps-uploader Cross-Compile Build ==="
echo "Configuration: $CONFIG"

cd /src

# Install vcpkg dependencies for mingw
echo "--- Installing vcpkg dependencies (x64-mingw-static) ---"
vcpkg install curl[core,brotli,ssl]:x64-mingw-static cpr:x64-mingw-static

# Configure with CMake
echo "--- Configuring with CMake ---"
cmake -S . -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE="$CONFIG" \
    -DCMAKE_TOOLCHAIN_FILE=/src/cmake/mingw-toolchain.cmake \
    -DVCPKG_TARGET_TRIPLET=x64-mingw-static \
    -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=/src/cmake/mingw-toolchain.cmake \
    -DCMAKE_TOOLCHAIN_FILE=/opt/vcpkg/scripts/buildsystems/vcpkg.cmake

# Build
echo "--- Building ---"
cmake --build build --config "$CONFIG" --target d3d9_uploader -j$(nproc)

echo ""
echo "=== Build Complete ==="
if [ -f build/libd3d9_uploader.dll ] || [ -f build/d3d9_uploader.dll ]; then
    DLL=$(find build -name "*d3d9_uploader*.dll" | head -1)
    echo "Output: $DLL ($(du -h "$DLL" | cut -f1))"
    # Copy to output directory
    cp "$DLL" /src/output/d3d9_uploader.dll 2>/dev/null || true
else
    echo "Warning: DLL not found at expected paths. Listing build dir:"
    find build -name "*.dll" -o -name "*.so" -o -name "*.a" 2>/dev/null || true
fi
