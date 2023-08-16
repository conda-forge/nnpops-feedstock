#!/bin/bash

set -euxo pipefail

rm -rf build || true

# function for facilitate version comparison; cf. https://stackoverflow.com/a/37939589
function version2int { echo "$@" | awk -F. '{ printf("%d%02d\n", $1, $2); }'; }

CMAKE_FLAGS="${CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release -DPython_EXECUTABLE=${PYTHON}"
CMAKE_FLAGS+=" -DTorch_DIR=${SP_DIR}/torch/share/cmake/Torch"

declare -a CUDA_CONFIG_ARGS
if [ ${cuda_compiler_version} != "None" ]; then
    # Torch has a function that prints the archs it was compiled for as a list like, for instance this
    # ['sm_37', 'sm_50', 'sm_60', 'sm_70', 'sm_75', 'sm_80', 'sm_86', 'sm_90']
    # The line below transforms it into what is required by CMake: "3.7;5.0;6.0" and so on
    # There is a higher level function, called torch.cuda.get_arch_list, but it returns an empty list when there is no GPU available.
    # Should that fail, this could be used instead:
    # $ cuobjdump $(find $CONDA_PREFIX -name "libtorch_cuda.so")  | grep arch | awk '{print $3}' | sort | uniq | sed 's+sm_\([0-9]\)\([0-9]\)+\1.\2+g' | tr '\n' ';'
    ARCH_LIST=$(${PYTHON} -c "import torch; print(';'.join([f'{y[0]}.{y[1]}' for y in [x[3:] for x in torch._C._cuda_getArchFlags().split()]]))")
    # CMakeLists.txt seems to ignore the CMAKE_CUDA_ARCHITECTURES variable, instead, it is overloaded by TORCH_CUDA_ARCH_LIST
    # which in turn defaults to either nothing or the GPUs in the current system.
    CMAKE_FLAGS+=" -DTORCH_CUDA_ARCH_LIST=${ARCH_LIST}"
else
    CMAKE_FLAGS+=" -DENABLE_CUDA=OFF"
fi

mkdir build && cd build
cmake ${CMAKE_FLAGS} ${SRC_DIR}
make -j$CPU_COUNT
make -j$CPU_COUNT install
CTEST_OUTPUT_ON_FAILURE=1 ctest --verbose --exclude-regex TestCuda
