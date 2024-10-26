# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..13} )

inherit distutils-r1 pypi

DESCRIPTION="hidapi bindings in ctypes"
HOMEPAGE="
	https://github.com/apmorton/pyhidapi
	https://pypi.org/project/hid/
"
# SRC_URI="https://github.com/apmorton/pyhidapi/archive/refs/tags/${PV}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64"

DEPEND="
	dev-libs/hidapi
"
RDEPEND="
	${DEPEND}
"

# distutils_enable_tests pytest

python_configure_all() {
	DISTUTILS_ARGS=(
		--with-system-hidapi
	)
}


# python_test() {
# 	epytest tests.py
# }
