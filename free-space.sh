#!/bin/sh

sudo apt install ninja-build
sudo apt purge -yq $(dpkg -l | grep '^ii' | awk '{ print $2 }' | grep -P '(aspnetcore|cabal-|dotnet-|ghc-|libmono|mongodb-|mysql-|php)') \
  firefox google-chrome-stable microsoft-edge-stable mono-devel mono-runtime-common monodoc-manual ruby
sudo apt autoremove -yq
sudo apt clean
sudo rm -fr /opt/ghc /opt/hostedtoolcache /usr/lib/node_modules /usr/local/share/boost /usr/share/dotnet /usr/share/swift
