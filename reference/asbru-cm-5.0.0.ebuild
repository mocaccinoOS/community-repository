# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit bash-completion-r1 gnome2 multilib

DESCRIPTION="Asbru CM is a user interface that helps organizing remote terminal sessions"
HOMEPAGE="https://www.asbru-cm.net/"
SRC_URI="https://github.com/${PN}/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="freerdp mosh rdesktop vnc webdav"

RDEPEND="freerdp? ( net-misc/freerdp )
	mosh? ( net-misc/mosh )
	rdesktop? ( net-misc/rdesktop )
	vnc? ( net-misc/tigervnc )
	webdav? ( net-misc/cadaver )
	dev-libs/ossp-uuid[perl]
	dev-perl/Crypt-Blowfish
	dev-perl/Crypt-CBC
	dev-perl/Crypt-Rijndael
	dev-perl/Expect
	dev-perl/File-KeePass
	dev-perl/Gnome2-GConf
	dev-perl/gnome2-perl
	dev-perl/Gnome2-Vte
	dev-perl/Gtk2
	dev-perl/Gtk2-Ex-Simple-List
	dev-perl/gtk2-gladexml
	dev-perl/Gtk2-Unique
	dev-perl/IO-Stty
	dev-perl/Net-ARP
	dev-perl/Socket6
	dev-perl/YAML"
DEPEND="${RDEPEND}"

src_prepare() {
	find "${PN}" lib utils -type f | while read f
	do
		sed -i -e "s@\$RealBin[^']*\('\?\)\([./]*\)/lib@\1/usr/$(get_libdir)/${PN}@g" "${f}"
		sed -i -e "s@\$RealBin[^']*\('\?\)\([./]*\)/res@\1/usr/share/${PN}@g" "${f}"
		sed -i -e "s@use KeePass@use File::KeePass@g" "${f}"
	done

	# https://github.com/asbru-cm/asbru-cm/pull/64
	eapply "${FILESDIR}/${P}-bash-completion.patch"

	eapply_user
}

src_configure() { :; }

src_install() {
	rm lib/ex/KeePass.pm

	dobin "${PN}"

	doman "res/${PN}.1"
	rm "res/${PN}.1"

	insinto /usr/share/applications
	doins "res/${PN}.desktop"
	rm "res/${PN}.desktop"

	newicon -s scalable res/asbru-logo.svg "${PN}".svg
	newicon -s 24 res/asbru-logo-24.png "${PN}".png
	newicon -s 256 res/asbru-logo-24.png "${PN}".png
	newicon -s 64 res/asbru-logo-24.png "${PN}".png

	newbashcomp res/asbru_bash_completion "${PN}"
	rm res/asbru_bash_completion

	insinto "/usr/$(get_libdir)/${PN}"
	doins -r lib/*

	insinto "/usr/share/${PN}"
	doins -r res/*
	doins -r utils
}

pkg_postinst() {
	gnome2_icon_cache_update
}

pkg_postrm() {
	gnome2_icon_cache_update
}
