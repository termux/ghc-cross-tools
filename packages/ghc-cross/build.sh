TERMUX_PKG_HOMEPAGE=https://www.haskell.org/ghc/
TERMUX_PKG_DESCRIPTION="The Glasgow Haskell Compiler"
TERMUX_PKG_LICENSE="custom"
TERMUX_PKG_MAINTAINER="Aditya Alok <alok@termux.dev>"
TERMUX_PKG_VERSION=9.12.1
TERMUX_PKG_SRCURL="https://downloads.haskell.org/~ghc/$TERMUX_PKG_VERSION/ghc-$TERMUX_PKG_VERSION-src.tar.xz"
TERMUX_PKG_SHA256=4a7410bdeec70f75717087b8f94bf5a6598fd61b3a0e1f8501d8f10be1492754
TERMUX_PKG_DEPENDS="libiconv, libffi, libgmp, libandroid-posix-semaphore"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--host=$TERMUX_BUILD_TUPLE
--with-system-libffi
--disable-ld-override"
TERMUX_PKG_HOSTBUILD=true

__build_hadrian() {
  local version="9.10.1"
  local cache_dir="$TERMUX_COMMON_CACHEDIR/hadrian-cache"
  local tar_file="${cache_dir}/ghc-${version}.tar.xz"
  local unpack_dir="${cache_dir}/ghc-${version}"
  local ghc_install_dir="${cache_dir}/ghc-${version}-runtime"

  local hadrian_install_dir="${cache_dir}/hadrian"

  export PATH="${hadrian_install_dir}:$PATH"

  test -d "$hadrian_install_dir" && return

  mkdir -p "$cache_dir"
  termux_download "https://downloads.haskell.org/~ghc/${version}/ghc-${version}-x86_64-ubuntu20_04-linux.tar.xz" \
    "$tar_file" \
    ae3be406fdb73bd2b0c22baada77a8ff2f8cde6220dd591dc24541cfe9d895eb

  mkdir -p "$unpack_dir" "$ghc_install_dir"
  tar xf "$tar_file" --strip-components=1 -C "$unpack_dir"

  (
    set -e
    unset CC CXX CFLAGS CXXFLAGS CPPFLAGS LDFLAGS AR AS CPP LD RANLIB READELF STRIP

    cd "$unpack_dir"
    ./configure --prefix="$ghc_install_dir"
    make install

  ) &>/dev/null

  rm -rf "$unpack_dir" "$tar_file"

  mkdir -p "$hadrian_install_dir"

  (
    set -e
    cd "$TERMUX_PKG_SRCDIR"
    PATH="$ghc_install_dir/bin:$PATH" cabal --project-file="$PWD/hadrian/cabal.project" new-build \
      --disable-documentation \
      --disable-profiling \
      --disable-library-profiling \
      --constraint="hadrian -threaded" \
      -j exe:hadrian

    PATH="$ghc_install_dir/bin:$PATH" cabal list-bin --project-file="$PWD/hadrian/cabal.project" hadrian:exes |
      xargs install -Dm755 -t "$hadrian_install_dir"
  )

  rm -rf "$ghc_install_dir"
}

termux_step_host_build() {
  termux_setup_cabal
  __build_hadrian
}

termux_step_pre_configure() {
  termux_setup_ghc

  export CONF_CC_OPTS_STAGE1="$CFLAGS $CPPFLAGS"
  export CONF_GCC_LINKER_OPTS_STAGE1="$LDFLAGS"
  export CONF_CXX_OPTS_STAGE1="$CXXFLAGS"

  export CONF_CC_OPTS_STAGE2="$CFLAGS $CPPFLAGS"
  export CONF_GCC_LINKER_OPTS_STAGE2="$LDFLAGS"
  export CONF_CXX_OPTS_STAGE2="$CXXFLAGS"

  export target="$TERMUX_HOST_PLATFORM"

  # NOTE: We do not build profiled libs. It exceeds the 6 hours limit of github CI.
  export flavour="release+split_sections+late_ccs+no_profiled_libs"

  if [ "$TERMUX_ARCH" = "arm" ]; then
    target="armv7a-linux-androideabi"
  fi

  TERMUX_PKG_EXTRA_CONFIGURE_ARGS="$TERMUX_PKG_EXTRA_CONFIGURE_ARGS --target=$target"
}

termux_step_make() {
  (
    unset CFLAGS CPPFLAGS LDFLAGS # For stage0 compilation.
    hadrian binary-dist-dir \
      -j"$TERMUX_PKG_MAKE_PROCESSES" \
      --flavour="$flavour" \
      --docs=none \
      --directory="$PWD" \
      "stage1.unix.ghc.link.opts += -optl-landroid-posix-semaphore"
  )
}

termux_step_make_install() {
  cd _build/bindist/ghc-"$TERMUX_PKG_VERSION"-"$target" || exit 1
  tar cJf "$TAR_OUTPUT_DIR"/ghc-"$TERMUX_PKG_VERSION"-"$target".tar.xz -C .. ghc-"$TERMUX_PKG_VERSION"-"$target"
  exit
}
