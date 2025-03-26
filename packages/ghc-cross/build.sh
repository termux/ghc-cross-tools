TERMUX_PKG_HOMEPAGE=https://www.haskell.org/ghc/
TERMUX_PKG_DESCRIPTION="The Glasgow Haskell Compiler"
TERMUX_PKG_LICENSE="custom"
TERMUX_PKG_MAINTAINER="Aditya Alok <alok@termux.dev>"
TERMUX_PKG_VERSION=9.12.2
TERMUX_PKG_SRCURL="https://downloads.haskell.org/~ghc/$TERMUX_PKG_VERSION/ghc-$TERMUX_PKG_VERSION-src.tar.xz"
TERMUX_PKG_SHA256=0e49cd5dde43f348c5716e5de9a5d7a0f8d68d945dc41cf75dfdefe65084f933
TERMUX_PKG_DEPENDS="libiconv, libffi, libgmp, libandroid-posix-semaphore"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--host=$TERMUX_BUILD_TUPLE
--with-system-libffi
--disable-ld-override"

__setup_bootstrap_compiler() {
  local version=9.10.1
  local temp_folder="$TERMUX_PKG_CACHEDIR/ghc-bootstrap-$version"
  local tarball="$temp_folder.tar.xz"
  local runtime_folder="$temp_folder-runtime"

  export PATH="$runtime_folder/bin:$PATH"

  [[ -d "$runtime_folder" ]] && return

  termux_download "https://downloads.haskell.org/~ghc/$version/ghc-$version-x86_64-ubuntu20_04-linux.tar.xz" \
    "$tarball" \
    ae3be406fdb73bd2b0c22baada77a8ff2f8cde6220dd591dc24541cfe9d895eb

  mkdir -p "$temp_folder" "$runtime_folder"
  tar xf "$tarball" --strip-components=1 -C "$temp_folder"
  (
    set -e
    unset CC CXX CFLAGS CXXFLAGS CPPFLAGS LDFLAGS AR AS CPP LD RANLIB READELF STRIP
    cd "$temp_folder"
    ./configure --prefix="$runtime_folder"
    make install
  ) >/dev/null

  rm -Rf "$temp_folder" "$tarball"
}

termux_step_pre_configure() {
  __setup_bootstrap_compiler && termux_setup_cabal

  export CONF_CC_OPTS_STAGE1="$CFLAGS $CPPFLAGS"
  export CONF_GCC_LINKER_OPTS_STAGE1="$LDFLAGS"
  export CONF_CXX_OPTS_STAGE1="$CXXFLAGS"

  export CONF_CC_OPTS_STAGE2="$CFLAGS $CPPFLAGS"
  export CONF_GCC_LINKER_OPTS_STAGE2="$LDFLAGS"
  export CONF_CXX_OPTS_STAGE2="$CXXFLAGS"

  export target="$TERMUX_HOST_PLATFORM"
  export profiled_libs=""

  if [[ "$TERMUX_ARCH" == "arm" ]]; then
    target="armv7a-linux-androideabi"
    profiled_libs="+no_profiled_libs" # NOTE: We do not build profiled libs for arm. It exceeds the 6 hours usage limit of github CI.
  fi

  TERMUX_PKG_EXTRA_CONFIGURE_ARGS="$TERMUX_PKG_EXTRA_CONFIGURE_ARGS --target=$target"
  ./boot.source
}

termux_step_make() {
  (
    unset CFLAGS CPPFLAGS LDFLAGS # For stage0 compilation.

    ./hadrian/build binary-dist-dir \
      -j"$TERMUX_PKG_MAKE_PROCESSES" \
      --flavour="release+split_sections$profiled_libs" \
      --docs=none \
      "stage1.unix.ghc.link.opts += -optl-landroid-posix-semaphore" \
      "stage2.unix.ghc.link.opts += -optl-landroid-posix-semaphore"
  )
}

termux_step_make_install() {
  tar cJf "$TAR_OUTPUT_DIR"/ghc-"$TERMUX_PKG_VERSION"-"$target".tar.xz -C _build/bindist ghc-"$TERMUX_PKG_VERSION"-"$target"
  exit
}
