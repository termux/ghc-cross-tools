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
TERMUX_PKG_BLACKLISTED_ARCH="i686"
TERMUX_PKG_NO_STATICSPLIT=true

termux_step_pre_configure() {
  # WARNING: Do not move it below exported (CONF_*) options.
  # They will get included in `settings` file of host `ghc` during `termux_setup_ghc`.
  # NOTE: This has been fixed in `termux_setup_ghc`. Remove when changes are upstreamed.
  termux_setup_ghc && termux_setup_cabal

  export CONF_CC_OPTS_STAGE1="$CFLAGS $CPPFLAGS"
  export CONF_GCC_LINKER_OPTS_STAGE1="$LDFLAGS"
  export CONF_CXX_OPTS_STAGE1="$CXXFLAGS"

  export CONF_CC_OPTS_STAGE2="$CFLAGS $CPPFLAGS"
  export CONF_GCC_LINKER_OPTS_STAGE2="$LDFLAGS"
  export CONF_CXX_OPTS_STAGE2="$CXXFLAGS"

  export target="$TERMUX_HOST_PLATFORM"
  export flavour="release+split_sections"

  if [ "$TERMUX_ARCH" = "arm" ]; then
    target="armv7a-linux-androideabi"
    flavour="${flavour}+no_profiled_libs" # Otherwise, build exceeds the 6 hours limit of github CI.
  fi

  TERMUX_PKG_EXTRA_CONFIGURE_ARGS="$TERMUX_PKG_EXTRA_CONFIGURE_ARGS --target=$target"
}

termux_step_make() {
  (
    unset CFLAGS CPPFLAGS LDFLAGS # For stage0 compilation.
    ./hadrian/build binary-dist-dir -j"$TERMUX_PKG_MAKE_PROCESSES" --flavour="$flavour" --docs=none
  )
}

termux_step_make_install() {
  cd _build/bindist/ghc-"$TERMUX_PKG_VERSION"-"$target" || exit 1

  # We need to re-run configure:
  # See: https://gitlab.haskell.org/ghc/ghc/-/issues/22058
  ./configure \
    --prefix="$TERMUX_PREFIX" \
    --with-system-libffi \
    --disable-ld-override \
    --host="$target"

  make install
}

termux_step_install_license() {
  install -Dm600 -t "$TERMUX_PREFIX/share/doc/$TERMUX_PKG_NAME" \
    "$TERMUX_PKG_SRCDIR/LICENSE"
}

termux_step_post_massage() {
  # Remove cross-prefix from binaries and fix links:
  for path in bin/"$target"-*; do
    newpath="${path//$target-/}"

    if [ -h "$path" ]; then
      link_target="$(readlink "$path")"
      ln -sf "${link_target//$target-/}" "$newpath"
      rm "$path"
    else
      mv "$path" "$newpath"
    fi

  done

  local ghclibs_dir="lib/$target-ghc-$TERMUX_PKG_VERSION"

  if ! [ -d "$ghclibs_dir" ]; then
    echo "ERROR: GHC lib directory is not at expected place. Please verify before updating."
    exit 1
  fi

  find . -type f \( -name "*.so" -o -name "*.a" \) -exec "$STRIP" --strip-unneeded {} \;
  find "$ghclibs_dir"/bin -type f -exec "$STRIP" {} \;

  tar cvzf "$TAR_OUTPUT_DIR"/ghc-"$TERMUX_PKG_VERSION"-"$TERMUX_ARCH".tar.xz lib/ bin/ share/ && exit 0
}
