#!/bin/bash
set -e
source swift-define

if [ $STATIC_SWIFT_STDLIB ]; then
    PARAMS="--static-swift-stdlib"
    STATIC_SUFFIX="-static"
    STATIC="Static"
else
    # Only build tests when not building statically
    PARAMS="-Xswiftc -enable-testing"
fi

echo "Cross compile Swift package $STATIC_SWIFT_STDLIB_PARAM"
rm -rf $SWIFT_PACKAGE_BUILDDIR
mkdir -p $SWIFT_PACKAGE_BUILDDIR
cd $SWIFT_PACKAGE_SRCDIR
$SWIFT_NATIVE_PATH/swift build --build-tests \
    --configuration ${SWIFTPM_CONFIGURATION} \
    --scratch-path ${SWIFT_PACKAGE_BUILDDIR}${STATIC_SUFFIX} \
    --destination ${SWIFTPM_DESTINATION_FILE} \
    -Xswiftc -cxx-interoperability-mode=default \
    $PARAMS
