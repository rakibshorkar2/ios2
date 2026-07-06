#!/bin/bash
# setup_libtorrent.sh - Initializes the C++ libtorrent dependency and runs CMake
# Must be run from the ios/ directory

set -e

LIBTORRENT_DIR="LibTorrent-Swift"
THIRDPARTY_DIR="$LIBTORRENT_DIR/Thirdparty/libtorrent"
BUILD_DIR="$LIBTORRENT_DIR/libtorrent-build"

if [ ! -d "$LIBTORRENT_DIR" ]; then
    echo "Error: $LIBTORRENT_DIR not found"
    exit 1
fi

# Check if C++ libtorrent source is present
if [ ! -f "$THIRDPARTY_DIR/include/libtorrent/version.hpp" ]; then
    echo "Cloning C++ libtorrent source..."
    rm -rf "$THIRDPARTY_DIR"
    git clone --depth 1 --branch v2.0.10 \
        https://github.com/arvidn/libtorrent.git \
        "$THIRDPARTY_DIR"
fi

echo "Running CMake to generate libtorrent Xcode project..."
cd "$LIBTORRENT_DIR"
chmod +x make.sh
./make.sh
cd ..

echo "LibTorrent setup complete"
