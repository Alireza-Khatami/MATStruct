#!/bin/bash

module load cuda/11.7.0

GCC9=/opt/ohpc/pub/compiler/gcc/9.4.0/bin
export PATH=$GCC9:$PATH
export CC=$GCC9/gcc
export CXX=$GCC9/g++

CMAKE=/groups/czhang/axk230084/conda/envs/qndf/bin/cmake
BUILD_DIR="$(dirname "$0")/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clean cmake cache and stale deps to ensure new CUDA/GCC versions are picked up
rm -f CMakeCache.txt
rm -rf _deps

$CMAKE .. \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DMATSTRUCT_WITH_VISUALIZATION=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_HOST_COMPILER=$GCC9/gcc

make -j4
