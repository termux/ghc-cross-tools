# ghc-cross-tools

This repository contains the build scripts, and patches required to cross-compile the Glasgow Haskell Compiler for Android. It builds and packages the cross-compilation toolchain to be consumed by the [termux-packages](https://github.com/termux/termux-packages), enabling packaging of `ghc`, `cabal`, and other Haskell packages for Android.

## Supported targets

The cross-compiler is built on `ubuntu-latest-x86_64` host and builds against four Android architectures:

| Target Architecture | Target Triple | Notes |
| :--- | :--- | :--- |
| **AArch64 (ARM64)** | `aarch64-linux-android` | |
| **ARMv7a (ARM32)** | `armv7a-linux-androideabi` | Profiled libraries are disabled (`+no_profiled_libs`) to bypass GitHub Actions' 6-hour runner limit. |
| **x86_64** | `x86_64-linux-android` | |
| **i686 (x86)** | `i686-linux-android` | |

## Patches

### 1. Cross-Compiler specific

Located in `packages/ghc-cross/`

#### `add-missing-i686-relocs.patch`

Implements support for `R_386_GOTPC`, `R_386_GOTOFF`, `R_386_GOT32`, `R_386_GOT32X`, and `R_386_PLT32` relocations in GHC's runtime linker (`rts/linker/Elf.c`). This is required because the compiler emits these specific GOT relocations for `-fPIC` code on 32-bit x86 targets. Without them, PIC on Android i686 fails at runtime (eg: `iserv`).

#### `hadrian-enable-iserv.patch`

Forces Hadrian to build the `iserv` (external interpreter) in the stage1 binary distribution. During cross-compilation, Hadrian defaults to dropping `iserv` from the stage1 bindist. This `iserv` binary is meant to run on Android target. We use it under proot and qemu (arm and aarch64) to run on CI itself. Thus, making Template Haskell splices evaluation possible for cross-compiler.

### 2. General

Located at: <https://github.com/termux/termux-packages/blob/master/packages/ghc>

#### [`rts-heap-reservation.patch`](https://github.com/termux/termux-packages/blob/master/packages/ghc/rts-heap-reservation.patch)

**Bug:** On Android, simple commands like `ghc --help` will sometimes (in my testing, ~25% of the times) hang, consuming 90%-100% CPU.

**Cause:** In GHC, the function `osReserveHeapMemory` tries to allocate virtual space starting from `0x4200000000` so that the heap is safely above 8GB (leaving space below for dynamically loaded code). If the kernel allocates below this address, GHC unmaps it and repeats the `mmap` call with an increasing hint address. However, Android's kernel occasionally ignores the hint and returns the same unmapped address over and over. This traps GHC in an infinite loop.  
For more detail see: <https://github.com/termux/termux-packages/pull/22991#issuecomment-2759137291>

**Patch:** This patch modifies the RTS heap allocator to use a recursive reservation strategy. It keeps the undesired `< 8GB` mapping active while making subsequent `mmap` calls until the kernel finally yields an address `> 8GB`. Once successful, it unwinds the recursion and unmaps all the lower, unwanted addresses.

#### [`elf-types.patch`](https://github.com/termux/termux-packages/blob/master/packages/ghc/elf-types.patch)

Android's Bionic libc `<elf.h>` header omits the standard `ELF32_ST_VISIBILITY` macro. This patch explicitly defines it within the GHC RTS linker so that it can successfully compile against the bionic libc.

#### Android dynamic linker restrictions

**Bug:** missing symbols in `ghci` and other dynamically loaded parts

**Cause:** Standard gnu/Linux behaviour is to load the main executable dependencies to global scope. This behaviour is assumed by ghc dynamic linker. But it is not true on Android. In API 23 Android changed the behaviour and introduced stricter separation. ONLY main executable, LD_PRELOAD and dependencies marked with DF_1_GLOBAL is loaded into global scope. Others go to local scope. Thus, any library further opened via dlopen(3) can't see the symbols from the dependencies of the main executable.

See:

- <https://android.googlesource.com/platform/bionic/+/master/android-changes-for-ndk-developers.md#changes-to-library-search-order>
- <https://android.googlesource.com/platform/bionic/+/master/android-changes-for-ndk-developers.md#rtld_local-available-in-api-level-23>
- <https://github.com/android/ndk/issues/201>

**Patch:** compile with `-optl-Wl,-z,global` linker flag

> [!NOTE]
> There are more not much significant patches. See at: <https://github.com/termux/termux-packages/blob/master/packages/ghc>

## Termux specific libraries used

They are either missing on older APIs or absent on Android.

- `libiconv`
- `libffi`
- `libgmp`
- `libandroid-posix-semaphore`
- `libandroid-utimes`
- `ncurses` (for `terminfo`)

## License

The build infrastructure is licensed under the [Apache License, Version 2.0](LICENSE.md).
Patches corresponding to the GHC source code are licensed under the [3-Clause BSD License](https://opensource.org/licenses/BSD-3-Clause) AND HaskellReport as per the upstream.
