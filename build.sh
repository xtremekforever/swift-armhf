#!/bin/bash
set -e
source swift-define

if [[ $OSTYPE == 'darwin'* ]]; then
    echo "Install macOS build dependencies"
    ./setup-mac.sh
fi

# Fetch and patch sources
if [ -z $SKIP_FETCH_SOURCES ]; then
    ./fetch-sources.sh
fi
./fetch-binaries.sh

# Generate Xcode toolchain
if [[ $OSTYPE == 'darwin'* && ! -d "$XCTOOLCHAIN" ]]; then
    mkdir -p $XCTOOLCHAIN
    ./generate-xcode-toolchain-impl.sh /tmp/ ./downloads/${SWIFT_VERSION}-osx.pkg $INSTALL_TAR
    cp -rf /tmp/cross-toolchain/swift-armv7.xctoolchain/* $XCTOOLCHAIN/
fi

# Cleanup previous build
rm -rf $STAGING_DIR/usr/lib/swift*

# Build LLVM
./build-llvm.sh

# This is required for cross-compiling dispatch, foundation, etc
./create-cmake-toolchain.sh

# Build Swift
./build-swift-stdlib.sh
./build-dispatch.sh
STATIC_BUILD=1 ./build-dispatch.sh
./build-foundation.sh
STATIC_BUILD=1 ./build-foundation.sh
./build-xctest.sh

# Enable Swift Testing for 6.0 and later
if [[ $SWIFT_VERSION == *"swift-6."* ]] || [[ $SWIFT_VERSION == *"swift-DEVELOPMENT"* ]]; then
    ./build-swift-testing.sh
fi

./deploy-to-sysroot.sh

# Archive
./build-tar.sh

# Cross compile test package
./generate-swiftpm-toolchain.sh
./build-swift-hello.sh
