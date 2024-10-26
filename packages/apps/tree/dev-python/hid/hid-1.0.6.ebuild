# Copyright 2024 Gentoo Authors
 # Distributed under the terms of the GNU General Public License v2

 EAPI=8

 DISTUTILS_USE_PEP517=setuptools
 PYTHON_COMPAT=( python3_{12..13} pypy3 )

 inherit distutils-r1 pypi

 DESCRIPTION="hidapi bindings in ctypes"
 HOMEPAGE="
     https://github.com/apmorton/pyhidapi
 "
 SRC_URI="https://github.com/apmorton/pyhidapi/archive/refs/tags/${PV}.tar.gz"

 LICENSE="MIT"
 SLOT="0"
 KEYWORDS="amd64"

RDEPEND="
	dev-libs/hidapi
"
