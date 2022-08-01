#!/bin/bash

set -euxo pipefail

rm -rf build || true


CMAKE_FLAGS="${CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release -DPython_EXECUTABLE=${PYTHON}"
CMAKE_FLAGS+=" -DTorch_DIR=${SP_DIR}/torch/share/cmake/Torch"
CMAKE_FLAGS+=" -DENABLE_CUDA=false"

mkdir build && cd build
cmake ${CMAKE_FLAGS} ${SRC_DIR}
make -j$CPU_COUNT
make -j$CPU_COUNT install
CTEST_OUTPUT_ON_FAILURE=1 ctest --verbose --exclude-regex TestCuda
