#!/usr/bin/env bash
set -e

# build the C code
echo "building C code"

rm -rf src/c/build
mkdir src/c/build

# build the C code w/ performance optimizations (for production):
# Aggressive optimization for maximum speed (includes -O3 + some FP approximations)
# Warning: -Ofast can break strict IEEE 754 floating-point compliance in rare cases
#          → only use if your code doesn't depend on exact FP behavior
gcc \
    -c \
    -Ofast \
    -march=native \
    -mtune=native \
    -fno-stack-protector \
    -fno-semantic-interposition \
    -falign-functions=32 \
    -falign-loops=32 \
    src/c/c_bindings.c \
    -o src/c/build/c_bindings.o
# -c
#    Only compile — do not link. Produces an object file (.o) instead of an executable.
#    Required when building a static library (.a) like in your case.
#
# -Ofast
#    Enables very aggressive optimizations for speed.
#    Includes -O3 + allows some floating-point optimizations that may break strict IEEE 754
#    compliance (faster math at the cost of possible tiny precision differences).
#    → Use only if your code doesn't rely on exact floating-point behavior.
#
# -march=native
#    Tells GCC to generate code using **all** CPU features/instruction sets available
#    on the machine where you are compiling (AVX2, FMA, BMI2, POPCNT, etc.).
#    → Can give significant speedups (5–30% in vectorizable/math code).
#    Warning: Binaries are **not portable** to older CPUs that lack those instructions.
#
# -mtune=native
#    Optimizes instruction scheduling, loop unrolling decisions, etc., specifically
#    for the exact CPU model detected at compile time.
#    → Usually gives a small additional speedup on top of -march=native.
#    Almost always used together with -march=native.
#
# -flto=auto
#    Enables Link-Time Optimization (LTO) in automatic mode.
#    Allows the compiler to see across multiple compilation units at link time,
#    enabling better inlining, dead code elimination, and constant propagation.
#    → Often gives 5–20% extra performance in larger projects.
#
# -fuse-linker-plugin
#    Required when using -flto with GCC. Tells the linker to use GCC's plugin
#    interface so that LTO can actually work during the linking stage.
#    → Without this, -flto has little or no effect.
#
# -fno-stack-protector
#    Disables stack-smashing protection (buffer overflow canaries).
#    Removes the runtime checks that GCC inserts by default on many functions.
#    → Faster code, smaller stack frames.
#    Warning: Reduces security — only use if you fully trust your code and inputs.
#
# -fno-semantic-interposition
#    Tells GCC that no functions will be replaced/interposed at link/load time
#    (e.g. via LD_PRELOAD or symbol interposition).
#    → Allows more aggressive inlining, devirtualization, and other optimizations
#      that would otherwise be unsafe if functions could be overridden.
#
# -falign-functions=32
#    Forces the start address of every function to be aligned to a 32-byte boundary.
#    → Improves instruction fetch efficiency, branch prediction, and cache line usage
#      on modern x86-64 CPUs (especially useful with heavy inlining).
#
# -falign-loops=32
#    Forces the start of every loop to be aligned to a 32-byte boundary.
#    → Helps vectorization, reduces cache misses, and improves loop performance
#      when the compiler unrolls or vectorizes loops.
#
# src/current_time_formatted.c
#    The source file to compile.
#    This is the actual input file — GCC needs at least one source file.
#
# -o src/current_time_formatted.o
#    Specifies the name of the output object file.
#    Without -o, GCC would use a default name (e.g. current_time_formatted.o in cwd).

# Create staic C library that odin code incorporates
ar rcs src/c/build/libc_bindings.a src/c/build/c_bindings.o

# build the odin code w/ performance optimization (for production)
echo "building odin code"
rm -rf build
mkdir build
echo "building odin code examples/readme_example.odin"
odin build examples/readme_example.odin -file \
    -o:speed -no-bounds-check -disable-assert \
    -out:build/readme_example
echo "building odin code examples/full_example.odin"
odin build examples/full_example.odin -file \
    -o:speed -no-bounds-check -disable-assert \
    -out:build/full_example
