# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools systemd

DESCRIPTION="OSI Certified implementation of a complete cluster engine"
HOMEPAGE="http://www.corosync.org/"
SRC_URI="https://github.com/corosync/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD-2 public-domain"
SLOT="0"
KEYWORDS="~amd64"
IUSE="doc qdevice +qnetd systemd"

RDEPEND="dev-libs/nss
	sys-cluster/corosync
	systemd? ( sys-apps/systemd:= )"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig
	doc? ( sys-apps/groff )"

src_prepare() {
	default

	sed -i 's/$SEC_FLAGS $OPT_CFLAGS $GDB_FLAGS/$OS_CFLAGS/' configure.ac || die 'sed failed'

	if ! use doc; then
		sed -i 's/BUILD_HTML_DOCS, test/BUILD_HTML_DOCS, false/' configure.ac || die 'sed failed'
	fi

	eautoreconf
}

src_configure() {
	econf_opts=(
		--disable-static \
		--localstatedir=/var \
		--with-systemddir="$(systemd_get_systemunitdir)" \
		$(use_enable systemd) \
		$(use_enable qdevice qdevices) \
		$(use_enable qnetd)
	)
	econf "${econf_opts[@]}"
}

src_install() {
	default
	rm -r "${ED}/var/run" || die
}
