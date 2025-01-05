#!/usr/bin/bash

set -e -u

TAR_OUTPUT_DIR="$(realpath "$1")"
ARCH="$2"

source ./utils.sh

mkdir -p "$TAR_OUTPUT_DIR"

clone_termux_packages
cp -r ./packages/ghc-cross termux-packages/packages/

cd termux-packages
./build-package.sh -I -a "$ARCH" ghc-cross
