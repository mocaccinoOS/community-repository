# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit bash-completion-r1 eutils gnome2 multilib

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
	dev-perl/Gtk2
	>x11-libs/vte-0.48
	dev-perl/Glib-Object-Introspection
	dev-perl/Gtk3
	dev-perl/YAML
	dev-perl/Crypt-CBC
	dev-perl/Socket6
	dev-perl/Net-ARP
	x11-libs/libwnck
	dev-perl/Gtk3-SimpleList
	dev-perl/Expect"
DEPEND="${RDEPEND}"

src_prepare() {
	find "${PN}" lib utils -type f | while read f
	do
		sed -i -e "s@\$RealBin[^']*\('\?\)\([./]*\)/lib@\1/usr/$(get_libdir)/${PN}@g" "${f}"
		sed -i -e "s@\$RealBin[^']*\('\?\)\([./]*\)/res@\1/usr/share/${PN}@g" "${f}"
		sed -i -e "s@use KeePass@use File::KeePass@g" "${f}"
	done

	eapply_user
}

src_configure() { :; }

src_install() {
#	rm lib/ex/KeePass.pm
	exeinto "/opt/asbru"
	doexe "${PN}"

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

	insinto "/opt/asbru/lib"
	doins -r lib/*

	insinto "/opt/asbru/res"
	doins -r res/*
	doins -r utils

	dosym /opt/asbru/asbru-cm /usr/bin/asbru-cm
	dosym /opt/asbru/res /usr/share/asbru-cm
	dosym /opt/asbru/lib /usr/lib64/asbru-cm
	
}

pkg_postinst() {
	gnome2_icon_cache_update
}

pkg_postrm() {
	gnome2_icon_cache_update
}
