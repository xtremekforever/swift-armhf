#!/bin/bash
set -e
source swift-define

if [ $STATIC_BUILD ]; then
    FOUNDATION_BUILDDIR=$FOUNDATION_STATIC_BUILDDIR
    FOUNDATION_INSTALL_PREFIX=$FOUNDATION_STATIC_INSTALL_PREFIX
    BUILD_SHARED_LIBS=OFF
    STATIC="Static"
else
    BUILD_SHARED_LIBS=ON
fi

echo "Create Foundation build folder ${FOUNDATION_BUILDDIR}"
mkdir -p $FOUNDATION_BUILDDIR
rm -rf $FOUNDATION_INSTALL_PREFIX
mkdir -p $FOUNDATION_INSTALL_PREFIX

echo "Configure Foundation ${STATIC}"
rm -rf $FOUNDATION_BUILDDIR/CMakeCache.txt
cmake -S $FOUNDATION_SRCDIR -B $FOUNDATION_BUILDDIR -G Ninja \
    -DCMAKE_INSTALL_PREFIX=${FOUNDATION_INSTALL_PREFIX} \
    -DBUILD_TESTING=OFF \
    -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} \
    -DCMAKE_BUILD_TYPE=${SWIFT_BUILD_CONFIGURATION} \
    -DCMAKE_C_COMPILER=${SWIFT_NATIVE_PATH}/clang \
    -DCMAKE_CXX_COMPILER=${SWIFT_NATIVE_PATH}/clang++ \
    -DCMAKE_C_FLAGS="${RUNTIME_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${RUNTIME_FLAGS}" \
    -DCMAKE_C_LINK_FLAGS="${LINK_FLAGS}" \
    -DCMAKE_CXX_LINK_FLAGS="${LINK_FLAGS}" \
    -DCMAKE_ASM_FLAGS="${ASM_FLAGS}" \
    -DCMAKE_TOOLCHAIN_FILE="${CROSS_TOOLCHAIN_FILE}" \
    -DCF_DEPLOYMENT_SWIFT=ON \
    -Ddispatch_DIR="${LIBDISPATCH_BUILDDIR}/cmake/modules" \
    -DCMAKE_Swift_FLAGS="${SWIFTC_FLAGS}" \
    -DCMAKE_Swift_FLAGS_DEBUG="" \
    -DCMAKE_Swift_FLAGS_RELEASE="" \
    -DCMAKE_Swift_FLAGS_RELWITHDEBINFO="" \
    -DSwiftFoundation_MACRO="${SWIFT_NATIVE_PATH}../lib/host/plugins/libFoundationMacros.so" \
    -D_SwiftFoundation_SourceDIR="$SRC_ROOT/downloads/swift-foundation" \
    -D_SwiftFoundationICU_SourceDIR="$SRC_ROOT/downloads/swift-foundation-icu" \
    -D_SwiftCollections_SourceDIR="$SRC_ROOT/downloads/swift-collections" \

echo "Build & Install Foundation ${STATIC}"
(cd $FOUNDATION_BUILDDIR && ninja install)
