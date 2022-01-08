#!/bin/bash
set -x

if [ -e "package.use/$PACKAGE_CATEGORY-$PACKAGE_NAME.use" ]; then
  cp -rf package.use/$PACKAGE_CATEGORY-$PACKAGE_NAME.use /etc/portage/package.use/$PACKAGE_CATEGORY-$PACKAGE_NAME.use
fi

if [ -e "package.accept_keywords/$PACKAGE_CATEGORY-$PACKAGE_NAME.accept_keywords" ]; then
  cp -rf package.accept_keywords/$PACKAGE_CATEGORY-$PACKAGE_NAME.accept_keywords /etc/portage/package.accept_keywords/$PACKAGE_CATEGORY-$PACKAGE_NAME.accept_keywords
fi

if [ -e "package.license/$PACKAGE_CATEGORY-$PACKAGE_NAME.license" ]; then
  cp -rf package.license/$PACKAGE_CATEGORY-$PACKAGE_NAME.license /etc/portage/package.license/$PACKAGE_CATEGORY-$PACKAGE_NAME.license
fi
