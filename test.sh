#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
BINARY="$BUILD_DIR/bin/VolumeVoronoiGPU"
# INPUT_FILE="$PROJECT_DIR/output/01_00040270_8d906ab70c3140a38f825d34_trimesh_005.obj_.msh"
INPUT_FILE="/mnt/d/datasets/abc_full_10k/ABC_input(use scaled_sf.obj)/01_00040049_5c84f0ac4aea4ad28f79872b_trimesh_000/01_00040049_5c84f0ac4aea4ad28f79872b_trimesh_000.obj_.msh"
OUTPUT_DIR="$PROJECT_DIR/output/test"

# mkdir -p "$BUILD_DIR"
# cd "$BUILD_DIR"
# cmake .. -DMATSTRUCT_WITH_VISUALIZATION=OFF
# make -j$(nproc)

mkdir -p "$OUTPUT_DIR"
"$BINARY" -i "$INPUT_FILE" -d "$OUTPUT_DIR"
