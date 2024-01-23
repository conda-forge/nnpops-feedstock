#!/bin/bash

set -euxo pipefail

rm -rf build || true

# function for facilitate version comparison; cf. https://stackoverflow.com/a/37939589
function majorversion { echo "$@" | awk -F. '{ printf("%d%02d\n", $1); }'; }

CMAKE_FLAGS="${CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release"
CMAKE_FLAGS+=" -DPython_EXECUTABLE=${PYTHON}"
CMAKE_FLAGS+=" -DTorch_DIR=${SP_DIR}/torch/share/cmake/Torch"

declare -a CUDA_CONFIG_ARGS
if [ ${cuda_compiler_version} != "None" ]; then
    # Output format from torch._C._cuda_getArchFlags(): 'sm_35 sm_50 sm_60 sm_61 sm_70 sm_75 sm_80 sm_86 compute_86'
    # We need to turn this into: "3.5;5.0;6.0;6.1;7.0;7.5;8.0;8.6" for TORCH_CUDA_ARCH_LIST (which overrides CMake-native option)
    # There is a higher level function, called torch.cuda.get_arch_list, but it returns an empty list when there is no GPU available.
    # Should that fail, this could be used instead:
    # $ cuobjdump $(find $CONDA_PREFIX -name "libtorch_cuda.so")  | grep arch | awk '{print $3}' | sort | uniq | sed 's+sm_\([0-9]\)\([0-9]\)+\1.\2+g' | tr '\n' ';'
    ARCH_LIST=$(${PYTHON} -c "import torch; print(';'.join([f'{y[0]}.{y[1]}' for y in [x[3:] for x in torch._C._cuda_getArchFlags().split() if x.startswith('sm_')]]))")
    # CMakeLists.txt seems to ignore the CMAKE_CUDA_ARCHITECTURES variable, instead, it is overwritten by TORCH_CUDA_ARCH_LIST
    CMAKE_FLAGS+=" -DTORCH_CUDA_ARCH_LIST=${ARCH_LIST}"
    if [ majorversion ${cuda_compiler_version} -ge 12 ]; then
	# This is required because conda-forge stores cuda headers in a non standard location
	export CUDA_INC_PATH=$CONDA_PREFIX/$targetsDir/include
    fi
else
    CMAKE_FLAGS+=" -DENABLE_CUDA=OFF"
fi

mkdir build && cd build
cmake ${CMAKE_FLAGS} ${SRC_DIR}
make -j$CPU_COUNT
make -j$CPU_COUNT install

if [[ "$target_platform" != "osx-arm64" ]]; then
    CTEST_OUTPUT_ON_FAILURE=1 ctest --verbose --exclude-regex TestCuda
fi
