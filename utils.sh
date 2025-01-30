#!/bin/bash

clone_termux_packages() {
  # clone termux-packages into container
  #TODO: Remove test branch after merger of https://github.com/termux/termux-packages/pull/22991
  git clone -b test-latest-ghc --single-branch https://github.com/termux/termux-packages.git
}

download() {
  url="$1"
  destination="$2"
  checksum="$3"

  curl --fail --retry 20 --retry-connrefused --retry-delay 30 --location -o "${destination}" "${url}" || {
    echo "Failed to download '${url}'."
    exit 1
  }

  if [ "${checksum}" != "SKIP" ]; then
    actual_checksum=$(sha256sum "${destination}" | cut -f 1 -d ' ')
    if [ "${checksum}" != "${actual_checksum}" ]; then
      printf >&2 "Wrong checksum for %s:\nExpected: %s\nActual:   %s\n" \
        "${url}" "${checksum}" "${actual_checksum}"
      return 1
    fi
  fi
}
