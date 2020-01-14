config ?= release
arch ?= native
tune ?= generic
version ?= $(shell cat VERSION)
build_flags ?= -j2
llvm_archs ?= X86
llvm_config ?= Release

# By default, CC is cc and CXX is g++
# So if you use standard alternatives on many Linuxes
# You can get clang and g++ and then bad things will happen
ifneq (,$(shell $(CC) --version 2>&1 | grep clang))
  ifneq (,$(shell $(CXX) --version 2>&1 | grep "Free Software Foundation"))
    CXX = c++
  endif

  ifneq (,$(shell $(CXX) --version 2>&1 | grep "Free Software Foundation"))
    $(error CC is clang but CXX is g++. They must be from matching compilers.)
  endif
else ifneq (,$(shell $(CC) --version 2>&1 | grep "Free Software Foundation"))
  ifneq (,$(shell $(CXX) --version 2>&1 | grep clang))
    CXX = c++
  endif

  ifneq (,$(shell $(CXX) --version 2>&1 | grep clang))
    $(error CC is gcc but CXX is clang++. They must be from matching compilers.)
  endif
endif

srcDir := $(shell dirname '$(subst /Volumes/Macintosh HD/,/,$(realpath $(lastword $(MAKEFILE_LIST))))')
buildDir := $(srcDir)/build/build_$(config)
outDir := $(srcDir)/build/$(config)

libsSrcDir := $(srcDir)/lib
libsBuildDir := $(srcDir)/build/build_libs
libsOutDir := $(srcDir)/build/libs

ifndef verbose
	SILENT = @
else
	SILENT =
endif

.DEFAULT_GOAL := build
.PHONY: all libs cleanlibs configure cross-configure build test test-ci test-check-version test-core test-stdlib-debug test-stdlib-release test-examples test-validate-grammar clean

libs:
	$(SILENT)mkdir -p '$(libsBuildDir)'
	$(SILENT)cd '$(libsBuildDir)' && cmake -B '$(libsBuildDir)' -S '$(libsSrcDir)' -DCMAKE_INSTALL_PREFIX="$(libsOutDir)" -DCMAKE_BUILD_TYPE="$(llvm_config)" -DLLVM_TARGETS_TO_BUILD="$(llvm_archs)" -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_ENABLE_WARNINGS=OFF -DLLVM_ENABLE_TERMINFO=OFF
	$(SILENT)cd '$(libsBuildDir)' && cmake --build '$(libsBuildDir)' --target install --config $(llvm_config) -- $(build_flags)

cleanlibs:
	$(SILENT)rm -rf '$(libsBuildDir)'
	$(SILENT)rm -rf '$(libsOutDir)'

configure:
	$(SILENT)mkdir -p '$(buildDir)'
	$(SILENT)cd '$(buildDir)' && CC="$(CC)" CXX="$(CXX)" cmake -B '$(buildDir)' -S '$(srcDir)' -DCMAKE_BUILD_TYPE=$(config) -DCMAKE_C_FLAGS="-march=$(arch) -mtune=$(tune)" -DCMAKE_CXX_FLAGS="-march=$(arch) -mtune=$(tune)" -DPONYC_VERSION=$(version)

all: build

build:
	$(SILENT)cd '$(buildDir)' && cmake --build '$(buildDir)' --config $(config) --target all -- $(build_flags)

crossBuildDir := $(srcDir)/build/$(arch)/build_$(config)

cross-libponyrt:
	$(SILENT)mkdir -p $(crossBuildDir)
	$(SILENT)cd '$(crossBuildDir)' && CC="$(CC)" CXX="$(CXX)" cmake -B '$(crossBuildDir)' -S '$(srcDir)' -DPONY_CROSS_LIBPONYRT=true -DCMAKE_BUILD_TYPE=$(config) -DCMAKE_C_FLAGS="-march=$(arch) -mtune=$(tune)" -DCMAKE_CXX_FLAGS="-march=$(arch) -mtune=$(tune)" -DPONYC_VERSION=$(version) -DLL_FLAGS="-march=$(arch) -mcpu=$(tune)"
	$(SILENT)cd '$(crossBuildDir)' && cmake --build '$(crossBuildDir)' --config $(config) --target all -- $(build_flags)

test: all test-core test-stdlib-release test-examples

test-ci: all test-check-version test-core test-stdlib-debug test-stdlib-release test-examples test-validate-grammar

test-check-version: all
	$(SILENT)cd '$(outDir)' && ./ponyc --version

test-core: all
	$(SILENT)cd '$(outDir)' && ./libponyrt.tests --gtest_shuffle
	$(SILENT)cd '$(outDir)' && ./libponyc.tests --gtest_shuffle

test-stdlib-release: all
	$(SILENT)cd '$(outDir)' && ./ponyc -b stdlib-release --pic --checktree --verify ../../packages/stdlib && ./stdlib-release && rm stdlib-release

test-stdlib-debug: all
	$(SILENT)cd '$(outDir)' && ./ponyc -d -b stdlib-debug --pic --strip --checktree --verify ../../packages/stdlib && ./stdlib-debug && rm stdlib-debug

test-examples: all
	$(SILENT)cd '$(outDir)' && PONYPATH=.:$(PONYPATH) find ../../examples/*/* -name '*.pony' -print | xargs -n 1 dirname | sort -u | grep -v ffi- | xargs -n 1 -I {} ./ponyc -d -s --checktree -o {} {}

test-validate-grammar: all
	$(SILENT)cd '$(outDir)' && ./ponyc --antlr >> pony.g.new && diff ../../pony.g pony.g.new && rm pony.g.new

clean:
	$(SILENT)([ -d '$(buildDir)' ] && cd '$(buildDir)' && cmake --build '$(buildDir)' --config $(config) --target clean) || true
	$(SILENT)rm -rf '$(buildDir)'
	$(SILENT)rm -rf '$(outDir)'

distclean:
	$(SILENT)([ -d build ] && rm -rf build) || true
