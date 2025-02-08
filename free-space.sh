#!/bin/sh

df -h

sudo apt purge -yq $(dpkg -l | grep '^ii' | awk '{ print $2 }' | grep -P '(aspnetcore|cabal-|dotnet-|ghc-|libmono|mongodb-|mysql-|llvm-|liblldb-|php)') \
  firefox google-chrome-stable microsoft-edge-stable mono-devel mono-runtime-common monodoc-manual ruby \
  azure-cli powershell libgl1-mesa-dri shellcheck mercurial-common humanity-icon-theme google-cloud-cli

echo "Listing 100 largest packages after"
dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n | tail -n 100

# Directories
sudo rm -fr /opt/ghc /opt/hostedtoolcache /usr/share/dotnet /usr/share/swift
sudo rm -rf /usr/local/graalvm/
sudo rm -rf /usr/local/.ghcup/
sudo rm -rf /usr/local/share/powershell
sudo rm -rf /usr/local/share/chromium
sudo rm -rf /usr/local/lib/android
sudo rm -rf /usr/local/lib/node_modules

# https://github.com/actions/runner-images/issues/709#issuecomment-612569242
sudo rm -rf "/usr/local/share/boost"
sudo rm -rf "$AGENT_TOOLSDIRECTORY"

sudo docker image prune --all --force
sudo docker builder prune -a

sudo apt autoremove -yq
sudo apt clean

df -h
