cmake_minimum_required(VERSION 3.11 FATAL_ERROR)

# Grab the PonyC version number from the "VERSION" source file.
if (NOT DEFINED PONYC_VERSION)
    file(STRINGS "VERSION" PONYC_VERSION)
endif()

execute_process(
    COMMAND git rev-parse --short HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_REVISION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

project(Pony VERSION ${PONYC_VERSION} LANGUAGES C CXX)

# Uncomment this to show build commands
# set(CMAKE_VERBOSE_MAKEFILE ON)

# We require LLVM, Google Test and Google Benchmark
find_package(LLVM REQUIRED CONFIG PATHS "build/libs/lib/cmake/llvm" "build/libs/lib64/cmake/llvm" NO_DEFAULT_PATH)
find_package(GTest REQUIRED CONFIG PATHS "build/libs/lib/cmake/GTest" "build/libs/lib64/cmake/GTest" NO_DEFAULT_PATH)
find_package(benchmark REQUIRED CONFIG PATHS "build/libs/lib/cmake/benchmark" "build/libs/lib64/cmake/benchmark" NO_DEFAULT_PATH)

# LibPonyC tests assume that our outputs are two directories above the root directory.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}/../debug)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}/../release)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL ${CMAKE_BINARY_DIR}/../minsizerel)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO ${CMAKE_BINARY_DIR}/../relwithdebinfo)

# Libs are now always built in release mode.
set(PONY_LLVM_BUILD_MODE "1")

# Required definitions.  We use these generators so that the defines are correct for both *nix (where the config applies at configuration time) and Windows (where the config applies at build time).
add_compile_definitions(
    BUILD_COMPILER="${CMAKE_C_COMPILER_VERSION}"
    _FILE_OFFSET_BITS=64
    __STDC_CONSTANT_MACROS
    __STDC_FORMAT_MACROS
    __STDC_LIMIT_MACROS
    LLVM_BUILD_MODE=${PONY_LLVM_BUILD_MODE}
    LLVM_VERSION="${LLVM_VERSION}"
    PONY_ALWAYS_ASSERT
    PONY_COMPILER="${CMAKE_C_COMPILER}"
    PONY_ARCH="${CMAKE_SYSTEM_PROCESSOR}"
    PONY_DEFAULT_PIC=true
    $<$<CONFIG:Debug>:PONY_BUILD_CONFIG="debug">
    $<$<CONFIG:Release>:PONY_BUILD_CONFIG="release">
    $<$<CONFIG:RelWithDebInfo>:PONY_BUILD_CONFIG="release">
    $<$<CONFIG:MinSizeRel>:PONY_BUILD_CONFIG="release">
    PONY_USE_BIGINT
    PONY_VERSION="${PONYC_VERSION}"
    $<$<CONFIG:Debug>:PONY_VERSION_STR="${PONYC_VERSION}-${GIT_REVISION} [debug]\\nCompiled with: LLVM ${LLVM_VERSION} -- ${CMAKE_C_COMPILER_ID}-${CMAKE_C_COMPILER_VERSION}-${CMAKE_C_COMPILER_ARCHITECTURE_ID}">
    $<$<CONFIG:Release>:PONY_VERSION_STR="${PONYC_VERSION}-${GIT_REVISION} [release]\\nCompiled with: LLVM ${LLVM_VERSION} -- ${CMAKE_C_COMPILER_ID}-${CMAKE_C_COMPILER_VERSION}-${CMAKE_C_COMPILER_ARCHITECTURE_ID}">
    $<$<CONFIG:RelWithDebInfo>:PONY_VERSION_STR="${PONYC_VERSION}-${GIT_REVISION} [relwithdebinfo]\\nCompiled with: LLVM ${LLVM_VERSION} -- ${CMAKE_C_COMPILER_ID}-${CMAKE_C_COMPILER_VERSION}-${CMAKE_C_COMPILER_ARCHITECTURE_ID}">
    $<$<CONFIG:MinSizeRel>:PONY_VERSION_STR="${PONYC_VERSION}-${GIT_REVISION} [minsizerel]\\nCompiled with: LLVM ${LLVM_VERSION} -- ${CMAKE_C_COMPILER_ID}-${CMAKE_C_COMPILER_VERSION}-${CMAKE_C_COMPILER_ARCHITECTURE_ID}">
)

if (MSVC)
    set_property(GLOBAL PROPERTY USE_FOLDERS ON)

    # Disable some warnings for Windows, and compile Debug builds with the regular CRT.
    add_compile_options(
        /wd4142
        /wd4996
        $<$<CONFIG:Debug>:/MD>
        /WX
    )
    add_compile_definitions(
        _MBCS
        _CRT_SECURE_NO_WARNINGS
        $<$<CONFIG:Debug>:_ITERATOR_DEBUG_LEVEL=0>
    )
else()
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu11 -Werror -Wconversion -Wno-sign-conversion -Wextra -Wall -fpic")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++11 -fno-rtti -fexceptions -fpic")
    add_link_options(-rdynamic)
endif (MSVC)

set(CMAKE_STATIC_LIBRARY_PREFIX "")

add_subdirectory(src/libponyc)
add_subdirectory(src/libponyrt)
add_subdirectory(src/ponyc)

add_subdirectory(test/libponyc)
add_subdirectory(test/libponyrt)

add_subdirectory(benchmark/libponyc)
add_subdirectory(benchmark/libponyrt)

install(TARGETS
    ponyc
    libponyc.tests
    libponyc.benchmarks
    libponyrt
    libponyrt.benchmarks
    libponyrt.tests
    DESTINATION ponyc/bin)
install(DIRECTORY packages/ DESTINATION packages)
install(DIRECTORY examples/ DESTINATION examples PATTERN .gitignore EXCLUDE)
