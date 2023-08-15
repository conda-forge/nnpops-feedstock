#!/bin/bash

set -euxo pipefail

rm -rf build || true

# function for facilitate version comparison; cf. https://stackoverflow.com/a/37939589
function version2int { echo "$@" | awk -F. '{ printf("%d%02d\n", $1, $2); }'; }

CMAKE_FLAGS="${CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release -DPython_EXECUTABLE=${PYTHON}"
CMAKE_FLAGS+=" -DTorch_DIR=${SP_DIR}/torch/share/cmake/Torch"

# adapted from https://github.com/conda-forge/faiss-split-feedstock/blob/main/recipe/build-lib.sh
declare -a CUDA_CONFIG_ARGS
if [ ${cuda_compiler_version} != "None" ]; then
    ARCH_LIST=$(${PYTHON} -c "import torch; print(';'.join([arch.split('_')[1][:1] + '.' + arch.split('_')[1][1:] for arch in torch._C._cuda_getArchFlags().split()]))")
    CMAKE_FLAGS+=" -DTORCH_CUDA_ARCH_LIST=${ARCH_LIST}"
else
    CMAKE_FLAGS+=" -DENABLE_CUDA=OFF"
fi

mkdir build && cd build
cmake ${CMAKE_FLAGS} ${SRC_DIR}
make -j$CPU_COUNT
make -j$CPU_COUNT install
CTEST_OUTPUT_ON_FAILURE=1 ctest --verbose --exclude-regex TestCuda
