# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LUA_COMPAT=( lua5-1 )

DOTNET_PKG_COMPAT=8.0
NUGETS="
discordrichpresence@1.2.1.24
linguini.bundle@0.8.1
microsoft.extensions.dependencymodel@9.0.0
mono.nat@3.0.4
mp3sharp@1.0.5
nuget.commandline@6.12.2
nvorbis@0.10.5
openra-eluant@1.0.22
openra-freetype6@1.0.11
openra-fuzzylogiclibrary@1.0.1
openra-openal-cs@1.0.22
openra-sdl2-cs@1.0.42
pfim@0.11.3
rix0rrr.beaconlib@1.0.2
roslynator.analyzers@4.13.0
roslynator.formatting.analyzers@4.13.0
sharpziplib@1.4.2
stylecop.analyzers@1.2.0-beta.556
system.runtime.loader@4.3.0
system.threading.channels@9.0.0
taglibsharp@2.3.0
"

inherit check-reqs dotnet-pkg lua-single xdg

DESCRIPTION="A free RTS engine supporting games like Command & Conquer, Red Alert and Dune2k"
HOMEPAGE="https://www.openra.net/
	https://github.com/OpenRA/OpenRA/"

if [[ "${PV}" == *9999* ]] ; then
	inherit git-r3

	EGIT_REPO_URI="https://github.com/OpenRA/OpenRA.git"
else
	SRC_URI="https://github.com/OpenRA/OpenRA/archive/release-${PV}.tar.gz
		-> ${P}.tar.gz"
	S="${WORKDIR}/OpenRA-release-${PV}"

	KEYWORDS="~amd64"
fi

SRC_URI+=" ${NUGET_URIS} "

# Engine is GPL-3, dependent DLLs are mixed.
LICENSE="GPL-3 Apache-2.0 BSD GPL-2 MIT"
SLOT="0"
REQUIRED_USE="${LUA_REQUIRED_USE}"

RDEPEND="
	${LUA_DEPS}
	app-misc/ca-certificates
	media-libs/freetype:2
	media-libs/libsdl2[opengl,video]
	media-libs/openal
"
BDEPEND="
	${RDEPEND}
"

CHECKREQS_DISK_BUILD="2G"
PATCHES=(
	"${FILESDIR}/${PN}-20231010-makefile.patch"
	"${FILESDIR}/${PN}-20231010-packaging-functions.patch"
	"${FILESDIR}/${PN}-20231010-handle-multilib.patch"
)

DOCS=( AUTHORS CODE_OF_CONDUCT.md CONTRIBUTING.md README.md )

pkg_setup() {
	check-reqs_pkg_setup
	dotnet-pkg_pkg_setup
	lua-single_pkg_setup
}

src_unpack() {
	dotnet-pkg_src_unpack

	if [[ -n "${EGIT_REPO_URI}" ]] ; then
		git-r3_src_unpack
	fi
}

src_compile() {
	emake VERSION="release-${PV}" version
	emake RUNTIME=net6
}

src_install() {
	local openra_home="/usr/lib/${PN}"

	# We compiled to "bin", not standard "dotnet-pkg" path.
	mkdir -p "${ED}/usr/share" || die
	cp -r bin "${ED}/usr/share/${P}" || die

	# This is used by "linux-shortcuts" (see below make-install).
	dotnet-pkg-base_launcherinto "${openra_home}"
	dotnet-pkg-base_dolauncher "/usr/share/${P}/OpenRA" OpenRA
	dotnet-pkg-base_dolauncher "/usr/share/${P}/OpenRA.Server" OpenRA.Server

	emake DESTDIR="${ED}" RUNTIME=net6 prefix=/usr bindir=/usr/bin \
		  install install-linux-shortcuts install-linux-appdata install-man

	local -a assets=(
		glsl
		mods
		AUTHORS
		COPYING
		VERSION
		'global mix database.dat'
	)
	local asset
	for asset in "${assets[@]}" ; do
		dosym -r "${openra_home}/${asset}" "/usr/share/${P}/${asset}"
	done

	einstalldocs
}
