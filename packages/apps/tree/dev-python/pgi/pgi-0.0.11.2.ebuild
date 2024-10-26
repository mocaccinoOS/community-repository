# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..13} pypy3 )

inherit distutils-r1 pypi

DESCRIPTION="GTK+/GObject Introspection Bindings for PyPy"
HOMEPAGE="
	https://github.com/pygobject/pgi
	https://pypi.org/project/pgi/
"
# SRC_URI="https://github.com/pygobject/pgi/releases/tag/${PV}.tar.gz"


LICENSE="LGPL 2.1+"
SLOT="0"
KEYWORDS="amd64"

DEPEND="
	dev-python/pygobject
"
RDEPEND="
	${DEPEND}
"
