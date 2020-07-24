# Copyright 1999-2020 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit bash-completion-r1 udev autotools systemd

LICENSE="GPL-2"

DESCRIPTION="mirror/replicate block-devices across a network-connection"
SRC_URI="https://www.linbit.com/downloads/drbd/utils/${P/_/}.tar.gz"
HOMEPAGE="http://www.drbd.org"

KEYWORDS="~amd64 ~x86"
IUSE="heartbeat pacemaker +udev xen"
SLOT="0"

DEPEND="heartbeat? ( sys-cluster/heartbeat )
	pacemaker? ( sys-cluster/pacemaker )
	udev? ( virtual/udev )"
RDEPEND="${DEPEND}"

S="${WORKDIR}/${P/_/}"

src_prepare() {
	# This package has a ton of hardcoded paths to /lib and /usr/lib
	# There is really no sensible way to fix this, so this is knowingly in violation
	# of multilib guidelines.

	# correct install paths (really correct this time)
	sed -i -e "s:\$(sysconfdir)/bash_completion.d:$(get_bashcompdir):" \
		scripts/Makefile.in || die

	# don't participate in user survey bug 360483
	sed -i -e '/usage-count/ s/yes/no/' scripts/global_common.conf || die

	# fix C++11 compiler check
	sed -i -e 's/ac_ct_CXX/CXX/' configure.ac || die

	# fix state/lock dirs
	sed -i -e 's:\$localstatedir/run:/run:' -e 's:\$localstatedir/lock:/run/lock/drbd:' \
		configure.ac || die
	sed -i -e '/\$(localstatedir)\/lock/d' -e '/\$(localstatedir)\/run/d' \
		user/*/Makefile.in || die

	default

	eautoreconf
}

src_configure() {
	econf \
		--localstatedir=/var \
		--without-rgmanager \
		$(use_with udev) \
		$(use_with xen) \
		$(use_with pacemaker) \
		$(use_with heartbeat) \
		--with-bashcompletion \
		--with-distro=gentoo
}

src_compile() {
	# only compile the tools
	emake OPTFLAGS="${CFLAGS}" tools
}

src_install() {
	# only install the tools
	emake DESTDIR="${ED}" install-tools install-doc
	dodoc README.md ChangeLog

	# install our own init script
	newinitd "${FILESDIR}"/${PN}-8.0.rc ${PN/-utils/}

	dodoc scripts/drbd.conf.example

	dosym /usr/sbin/drbdadm /sbin/drbdadm

	keepdir /var/lib/drbd

	systemd_newtmpfilesd "${FILESDIR}/drbd.tmpfiles" drbd.conf
}

pkg_postinst() {
	einfo
	einfo "Please copy and gunzip the configuration file:"
	einfo "from /usr/share/doc/${PF}/${PN/-utils/}.conf.example.bz2 to /etc/${PN/-utils/}.conf"
	einfo "and edit it to your needs. Helpful commands:"
	einfo "man 5 drbd.conf"
	einfo "man 8 drbdsetup"
	einfo "man 8 drbdadm"
	einfo "man 8 drbddisk"
	einfo "man 8 drbdmeta"
	einfo
	elog "Remember to enable drbd support in kernel."
}
