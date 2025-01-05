TERMUX_PKG_HOMEPAGE=https://www.haskell.org/ghc/
TERMUX_PKG_DESCRIPTION="The Glasgow Haskell Compiler"
TERMUX_PKG_LICENSE="custom"
TERMUX_PKG_MAINTAINER="Aditya Alok <alok@termux.dev>"
TERMUX_PKG_VERSION=9.12.1
TERMUX_PKG_SRCURL="https://downloads.haskell.org/~ghc/$TERMUX_PKG_VERSION/ghc-$TERMUX_PKG_VERSION-src.tar.xz"
TERMUX_PKG_SHA256=4a7410bdeec70f75717087b8f94bf5a6598fd61b3a0e1f8501d8f10be1492754
TERMUX_PKG_DEPENDS="libiconv, libffi, libgmp, libandroid-posix-semaphore, bionic-host"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--host=$TERMUX_BUILD_TUPLE
--with-system-libffi"

TERMUX_PKG_NO_STATICSPLIT=true

termux_step_post_get_source() {
  termux_setup_ghc && termux_setup_cabal
  cabal update
}

termux_step_pre_configure() {
  export CONF_CC_OPTS_STAGE1="$CFLAGS $CPPFLAGS" CONF_GCC_LINKER_OPTS_STAGE1="$LDFLAGS"
  export CONF_CC_OPTS_STAGE2="$CFLAGS $CPPFLAGS" CONF_GCC_LINKER_OPTS_STAGE2="$LDFLAGS"

  export target="$TERMUX_HOST_PLATFORM"
  if [ "$TERMUX_ARCH" = "arm" ]; then
    target="armv7a-linux-androideabi"
  fi
  TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" --target=$target"

  ./boot.source
}

termux_step_make() {
  unset CFLAGS CPPFLAGS LDFLAGS # For stage0 compilation.

  ./hadrian/build binary-dist-dir --flavour=quickest+no_profiled_libs --docs=none \
    "stage1.*.ghc.*.opts += -optl-landroid-posix-semaphore"
}

termux_step_make_install() {

  cd ./_build/bindist/ghc-* || exit 1

  ./configure --prefix="$TERMUX_PREFIX" --host="$target"
  make install

  # We may build GHC with `llc-9` etc., but only `llc` is present in Termux
  sed -i 's/"LLVM llc command", "llc.*"/"LLVM llc command", "llc"/' \
    "$TERMUX_PREFIX/lib/$target-ghc-$TERMUX_PKG_VERSION/lib/settings" || :
  sed -i 's/"LLVM opt command", "opt.*"/"LLVM opt command", "opt"/' \
    "$TERMUX_PREFIX/lib/$target-ghc-$TERMUX_PKG_VERSION/lib/settings" || :
}

termux_step_install_license() {
  install -Dm600 -t "$TERMUX_PREFIX/share/doc/$TERMUX_PKG_NAME" \
    "$TERMUX_PKG_SRCDIR/LICENSE"
}

termux_step_post_massage() {
  # Package for Termux ci:

  local host_platform="${TERMUX_HOST_PLATFORM}"
  [ "${TERMUX_ARCH}" = "arm" ] && host_platform="armv7a-linux-androideabi"

  for f in "bin/${host_platform}"-{ghc,ghc-$TERMUX_PKG_VERSION,ghc-pkg*,hsc2hs,hp2ps}; do
    # Fix shebang and $topdir.
    sed -i -e "s|^#!${TERMUX_PREFIX}/bin/sh|#!/usr/bin/sh|" \
      -e "s|${host_platform}-ghc-${TERMUX_PKG_VERSION}|ghc-${TERMUX_PKG_VERSION}|g" \
      "$f"
    biname="$(basename "$f")"
    mv "$f" "bin/${biname/${host_platform}-/}"
  done

  rm -rf "bin/$host_platform"-* || : # Remove rest binaries.

  mkdir -p lib/ghc-"${TERMUX_PKG_VERSION}"/bin
  cp lib/"${host_platform}"-ghc-"${TERMUX_PKG_VERSION}"/settings lib/ghc-"${TERMUX_PKG_VERSION}"
  cp lib/"${host_platform}"-ghc-"${TERMUX_PKG_VERSION}"/bin/{ghc,ghc-pkg,hsc2hs,hp2ps,unlit} lib/ghc-"${TERMUX_PKG_VERSION}"/bin

  tar -cvzf "${TAR_OUTPUT_DIR}/ghc-cross-bin-${TERMUX_PKG_VERSION}-${TERMUX_ARCH}.tar.xz" \
    lib/ghc-"${TERMUX_PKG_VERSION}" \
    bin/

  exit
}
