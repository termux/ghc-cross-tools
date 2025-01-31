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
--with-system-libffi"
TERMUX_PKG_BLACKLISTED_ARCH="i686"
TERMUX_PKG_NO_STATICSPLIT=true

termux_step_post_get_source() {
  termux_setup_ghc && termux_setup_cabal
  cabal update
}

termux_step_pre_configure() {
  export CONF_CC_OPTS_STAGE1="$CFLAGS $CPPFLAGS" CONF_GCC_LINKER_OPTS_STAGE1="$LDFLAGS"
  export CONF_CC_OPTS_STAGE2="$CFLAGS $CPPFLAGS" CONF_GCC_LINKER_OPTS_STAGE2="$LDFLAGS"

  export flavour="perf"

  target="$TERMUX_HOST_PLATFORM"
  if [ "$TERMUX_ARCH" = "arm" ]; then
    target="armv7a-linux-androideabi"
    flavour+="+no_profiled_libs" # Otherwise takes more than 6 hrs to build.
  fi
  TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" --target=$target"

  ./boot.source
}

termux_step_make() {
  (
    unset CFLAGS CPPFLAGS LDFLAGS # For stage0 compilation.
    ./hadrian/build binary-dist-xz --flavour="$flavour" --docs=none \
      "stage1.*.ghc.*.opts += -optl-landroid-posix-semaphore"
  )

  cp ./_build/bindist/ghc-*.tar.xz "$TAR_OUTPUT_DIR"/
  exit 0
}
