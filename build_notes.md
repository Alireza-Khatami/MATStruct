# Build Fix Notes

## Overview
Complete instructions to build the project from scratch on the HPC cluster.
The final binary is: `build/bin/VolumeVoronoiGPU`

---

## Step 1: Copy External Dependencies

The HPC login node may not have internet access on all nodes. Copy these dependencies manually into `extern/`:

| Directory | Source |
|---|---|
| `extern/geogram/` | https://github.com/alicevision/geogram (tag v1.7.5) |
| `extern/libmat/` | https://github.com/ningnawang/libmat (branch main) |
| `extern/cli11/` | https://github.com/CLIUtils/CLI11 (tag v2.5.0) |
| `extern/polyscope/` | https://github.com/nmwsharp/polyscope (commit eb07f8a) |

Note: `libigl`, `geometry-central`, and `nlohmann_json` are fetched via `FetchContent` and will be downloaded automatically if internet is available.

---

## Step 2: Code Fixes Required

### Fix 1 — CMake subprocess not passing policy version flag
**File:** `cmake/DownloadProject.cmake` (line ~163)

CMake 4.x removed compatibility with `cmake_minimum_required` versions below 3.5.
The `download_project()` function spawns a subprocess cmake that needs this flag forwarded.

```cmake
# Before
execute_process(COMMAND ${CMAKE_COMMAND} -G "${CMAKE_GENERATOR}"
                    -D "CMAKE_MAKE_PROGRAM:FILE=${CMAKE_MAKE_PROGRAM}"
                    .
                RESULT_VARIABLE result
                ${OUTPUT_QUIET}
                WORKING_DIRECTORY "${DL_ARGS_DOWNLOAD_DIR}"
)

# After
execute_process(COMMAND ${CMAKE_COMMAND} -G "${CMAKE_GENERATOR}"
                    -D "CMAKE_MAKE_PROGRAM:FILE=${CMAKE_MAKE_PROGRAM}"
                    -D "CMAKE_POLICY_VERSION_MINIMUM=3.5"
                    .
                RESULT_VARIABLE result
                ${OUTPUT_QUIET}
                WORKING_DIRECTORY "${DL_ARGS_DOWNLOAD_DIR}"
)
```

---

### Fix 2 — Disable polyscope in libmat (no Xinerama headers on HPC)
**File:** `extern/libmat/cmake/rpdDependencies.cmake` (line ~54)

`libmat` unconditionally downloads polyscope which requires `libxinerama-dev` headers
not available on the HPC cluster. Comment it out since visualization is not needed.

```cmake
# Before
if(NOT TARGET polyscope)
    rpd_download_polyscope()
    add_subdirectory(${LIBMAT_MODULE_EXTERNAL}/polyscope)
endif()

# After
# polyscope (disabled - no visualization on HPC)
# if(NOT TARGET polyscope)
#     rpd_download_polyscope()
#     add_subdirectory(${LIBMAT_MODULE_EXTERNAL}/polyscope)
# endif()
```

---

### Fix 3 — Add missing `release_pointers()` declaration to header
**File:** `extern/libmat/src/rpd3d_api/rpd_api.h`

The definition of `RPD3D_GPU::release_pointers()` exists in `rpd_api.cxx` but was
missing from the class declaration in the header, causing a compile error in `main_voronoi.cpp`.

```cpp
// In class RPD3D_GPU, add this declaration:
public:
  void release_pointers();   // <-- add this line
  void calculate();
  ...
```

---

## Step 3: Compiler & CUDA Setup

The HPC cluster has GCC 12.4 as default, which is incompatible with CUDA 11.7.
CUDA 12+ removed `cub::Min()` used in `extern/libmat/src/dist2mat/dist2mat.cu`.
The solution is to use **CUDA 11.7 + GCC 9.4**.

Available CUDA versions: `cuda/11.7.0`, `cuda/12.4`, `cuda/12.8`, `cuda/13.0`
Available GCC at: `/opt/ohpc/pub/compiler/gcc/` — versions: `5.5.0`, `7.5.0`, `9.4.0`, `12.4.0`

Use GCC 9.4.0 (supported by CUDA 11.7) by prepending it to PATH.

---

## Step 4: Build

Use the `build.sh` script at the project root:

```bash
bash /groups/czhang/axk230084/axk230084/build.sh
```

Contents of `build.sh`:
```bash
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

# Clean cmake cache to ensure new CUDA/GCC versions are picked up
rm -f CMakeCache.txt

$CMAKE .. \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DMATSTRUCT_WITH_VISUALIZATION=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_HOST_COMPILER=$GCC9/gcc

make -j4
```

> **Note:** Use `make -j4` instead of `make -j$(nproc)` — the login node has process limits
> and too many parallel jobs will cause `fork: Resource temporarily unavailable`.

---

## Running the Batch

### Paths
| Purpose | Path |
|---|---|
| Binary | `build/bin/VolumeVoronoiGPU` |
| Input | `/groups/xguo/axk230084/experiments/MATStruct/input` |
| Output | `/groups/xguo/axk230084/experiments/MATStruct/output` |
| Logs | `/groups/xguo/axk230084/experiments/MATStruct/output/logs` |

### Runtime Library Dependencies

The binary requires these libraries at runtime which are **not** on the default `LD_LIBRARY_PATH`:

| Library | Path |
|---|---|
| `libgeogram.so.1` | `build/lib/` (built alongside the binary) |
| `libcublas.so.11` | `/opt/ohpc/pub/unpackaged/apps/cuda/11.7.0/targets/x86_64-linux/lib/` |
| `libcuda.so.1` | Provided by the NVIDIA GPU driver — **must run on a GPU compute node** |

`run_batch.sh` sets `LD_LIBRARY_PATH` automatically. If running the binary directly, export:
```bash
export LD_LIBRARY_PATH="<project_root>/build/lib:/opt/ohpc/pub/unpackaged/apps/cuda/11.7.0/targets/x86_64-linux/lib:$LD_LIBRARY_PATH"
```

### Important: Must Run on a GPU Compute Node

`libcuda.so.1` is a GPU driver library not present on the login node. The batch **must** be run on a compute node with a GPU (e.g. via an interactive session or SLURM job).

### Debugging with GDB

`gdb` is not available as a module on the cluster. Install it via the `general` conda env:

```bash
conda install -y -n general gdb
```

GDB binary location: `/home/axk230084/.conda/envs/general/bin/gdb`

Then run with:
```bash
export LD_LIBRARY_PATH="<project_root>/build/lib:/opt/ohpc/pub/unpackaged/apps/cuda/11.7.0/targets/x86_64-linux/lib:$LD_LIBRARY_PATH"
conda run -n general gdb -batch -ex run -ex bt \
  --args <project_root>/build/bin/VolumeVoronoiGPU \
  -i <input>.msh -d <output_dir>
```

#### How to debug step by step

**Quick crash diagnosis (non-interactive)** — get a stack trace automatically:
```bash
export LD_LIBRARY_PATH="<project_root>/build/lib:/opt/ohpc/pub/unpackaged/apps/cuda/11.7.0/targets/x86_64-linux/lib:$LD_LIBRARY_PATH"
conda run -n general gdb -batch -ex run -ex bt \
  --args <project_root>/build/bin/VolumeVoronoiGPU -i <input>.msh -d <output_dir>
```
- `-batch` runs non-interactively
- `-ex run` starts the program
- `-ex bt` prints the backtrace (call stack) on crash

**Interactive debugging** — step through code:
```bash
export LD_LIBRARY_PATH="..."
/home/axk230084/.conda/envs/general/bin/gdb <project_root>/build/bin/VolumeVoronoiGPU
```
Then inside gdb:
```
(gdb) set args -i <input>.msh -d <output_dir>   # set program arguments
(gdb) run                                         # start the program
(gdb) bt                                          # print backtrace after crash
(gdb) frame 5                                     # jump to a specific frame in the stack
(gdb) list                                        # show source code at current frame
(gdb) print <variable>                            # inspect a variable value
(gdb) break io.cxx:92                             # set a breakpoint at file:line
(gdb) continue                                    # continue after a breakpoint
(gdb) next                                        # step over one line
(gdb) step                                        # step into a function call
(gdb) quit                                        # exit gdb
```

> **Note:** The binary is built in Release mode (optimized), so some variables may be
> unavailable or frames may be inlined. For full debug info, rebuild with
> `-DCMAKE_BUILD_TYPE=Debug` in `build.sh`.

---

### Known Runtime Issue — Double Free Crash (exit 134)

After successfully loading input meshes, the binary crashes with:
```
free(): double free detected in tcache 2
```
This is a memory corruption bug in the processing code, not a configuration issue. Needs investigation in the source.

---

## Known Warnings (Non-Fatal)

- `SuiteSparse not found` — geometry-central disables that support automatically.
- `libz.so conflict` — conda env vs system lib, unlikely to cause runtime issues.
- `FOR macro redefined` — macro name clash between geogram and libmat headers, harmless.
- Various narrowing conversion warnings in project source files.

---

## Final Output

```
[100%] Built target VolumeVoronoiGPU
```

Binary located at: `build/bin/VolumeVoronoiGPU`
