# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{8,9,10,11} )

inherit desktop distutils-r1

DESCRIPTION="Application launcher for Linux"
HOMEPAGE="https://ulauncher.io"
KEYWORDS="~amd64 ~x86"

if [[ ${PV} == 9999 ]];then
	inherit git-r3
	SRC_URI=""
	EGIT_REPO_URI="https://github.com/Ulauncher/${PN^}.git"
else
	SRC_URI="https://github.com/Ulauncher/${PN^}/releases/download/${PV}/${PN}_${PV}.tar.gz"
	S="${WORKDIR}/${PN}"
fi

LICENSE="GPL-3"
SLOT="0"

PYTHON_REQ_USE="sqlite"

DEPEND="
	dev-python/python-distutils-extra[${PYTHON_USEDEP}]
"
RDEPEND="${DEPEND}
	dev-python/dbus-python[${PYTHON_USEDEP}]
	dev-python/pygobject:3[${PYTHON_USEDEP}]
	dev-python/pyinotify[${PYTHON_USEDEP}]
	dev-python/Levenshtein[${PYTHON_USEDEP}]
	dev-python/pyxdg[${PYTHON_USEDEP}]
	dev-python/websocket-client[${PYTHON_USEDEP}]
	dev-libs/gobject-introspection:=
	dev-libs/libappindicator:3
	dev-libs/keybinder:3
	net-libs/webkit-gtk:4/37
"

BDEPEND="${PYTHON_DEPS}"

src_install(){
	distutils-r1_src_install
	domenu build/share/applications/${PN}.desktop
}
