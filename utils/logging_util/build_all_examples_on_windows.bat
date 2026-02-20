@echo off
@REM "@echo off" stops the Command Prompt from printing (echoing) every line of the script before executing it

@REM NOTE: Run this script from the "x64 Native Tools Command Prompt for VS" windows app




echo.
echo building C code

:: Clean and recreate C build directory
if exist src\c\build rd /s /q src\c\build
mkdir src\c\build


@REM :: Compile C bindings and create static library
@REM cl -TC -c src\c\c_bindings.c /Fosrc\c\build\
@REM lib -nologo src\c\build\c_bindings.obj -out:src\c\build\c_bindings.lib
@REM :: source: https://odin-lang.org/news/binding-to-c/#example


:: Compile C bindings with performance optimizations (for production)
:: MSVC equivalents to your GCC flags:
cl ^
    -TC ^
    -c ^
    -O2 ^
    -Oi ^
    -Ot ^
    -GS- ^
    -GL ^
    -DNDEBUG ^
    src\c\c_bindings.c ^
    /Fosrc\c\build\
REM -TC
REM    Treat all source files as C code, regardless of extension.
REM
REM -c
REM    Compiles without linking. Creates an object (.obj) file.
REM
REM -O2
REM    Creates fast code (Maps to -O2 in GCC).
REM    Includes /Og (Global Optimizations) and /Oi (Intrinsic Functions).
REM
REM -Oi
REM    Generates intrinsic functions. Replaces some function calls with 
REM    direct CPU instructions for speed.
REM
REM -Ot
REM    Tells the compiler to favor speed over code size.
REM
REM -GS-
REM    Disables buffer security checks (Canaries). 
REM    Equivalent to -fno-stack-protector.
REM
REM -GL
REM    Enables Whole Program Optimization. 
REM    Equivalent to -flto (Link Time Optimization).
REM
REM -DNDEBUG
REM    Defines the NDEBUG macro, which strips out standard C assert() calls.

:: Create static C library that Odin code incorporates
lib -nologo -LTCG src\c\build\c_bindings.obj -out:src\c\build\c_bindings.lib
REM -nologo
REM    Suppresses the startup banner/copyright message.
REM
REM -LTCG
REM    Link-Time Code Generation. **Required** because we used -GL in the cl command.
REM    This allows the librarian to optimize across the object files.




echo.
echo building odin code

:: Clean and recreate Odin build directory
if exist build rd /s /q build
mkdir build

:: Build Odin examples
echo building odin code examples/readme_example.odin
odin build examples/readme_example.odin -file ^
    -o:speed -no-bounds-check -disable-assert ^
    -extra-linker-flags:"/LTCG" ^
    -out:build/readme_example.exe

echo building odin code examples/full_example.odin
odin build examples/full_example.odin -file ^
    -o:speed -no-bounds-check -disable-assert ^
    -extra-linker-flags:"/LTCG" ^
    -out:build/full_example.exe

echo Build Complete.
