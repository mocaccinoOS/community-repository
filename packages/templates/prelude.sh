#!/bin/bash
set -x

packages=( "${@/#layerbase-/layers-}" )

for package in ${packages[@]}; do

  if [ -e "package.use/$package.use" ]; then
    cp -rf package.use/$package.use /etc/portage/package.use/$package.use
  fi
  
  if [ -e "package.accept_keywords/$package.accept_keywords" ]; then
    cp -rf package.accept_keywords/$package.accept_keywords /etc/portage/package.accept_keywords/$package.accept_keywords
  fi
  
  if [ -e "package.license/$package.license" ]; then
    cp -rf package.license/$package.license /etc/portage/package.license/$package.license
  fi

done
