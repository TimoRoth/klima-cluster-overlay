# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit autotools bash-completion-r1 udev tmpfiles

DESCRIPTION="mirror/replicate block-devices across a network-connection"
SRC_URI="https://pkg.linbit.com/downloads/drbd/utils/${P}.tar.gz"
HOMEPAGE="https://www.linbit.com/drbd"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="pacemaker +udev xen"

DEPEND="
	pacemaker? ( sys-cluster/pacemaker )
	udev? ( virtual/udev )"
RDEPEND="${DEPEND}"
BDEPEND="sys-devel/flex"

PATCHES=(
	"${FILESDIR}"/${PN}-9.18.0-sysmacros.patch
)

S="${WORKDIR}/${P/_/}"

src_prepare() {
	# respect LDFLAGS, #453442
	sed -e "s/\$(CC) -o/\$(CC) \$(LDFLAGS) -o/" \
		-e "/\$(DESTDIR)\$(localstatedir)\/lock/d" \
		-i user/*/Makefile.in || die

	# respect multilib
	sed -i -e "s:/lib/:/$(get_libdir)/:g" \
		Makefile.in scripts/{Makefile.in,global_common.conf,drbd.conf.example} || die
	sed -e "s:@prefix@/lib:@prefix@/$(get_libdir):" \
		-e "s:(DESTDIR)/lib:(DESTDIR)/$(get_libdir):" \
		-i user/*/Makefile.in || die

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

	# fix ocf path
	sed -i -e "s:lib/ocf:$(get_libdir)/ocf:" \
		scripts/*.{in,sh,ocf} drbd.spec.in || die
	sed -i -e "s:\$(sysconfdir)/udev:$(get_udevdir):" scripts/Makefile.in || die

	default
	eautoreconf
}

src_configure() {
	econf \
		--localstatedir="${EPREFIX}"/var \
		--with-bashcompletion \
		--with-distro=gentoo \
		--with-prebuiltman \
		--without-rgmanager \
		$(use_with pacemaker) \
		$(use_with udev) \
		$(use_with xen)
}

src_compile() {
	# only compile the tools
	emake OPTFLAGS="${CFLAGS}" tools doc
}

src_install() {
	# only install the tools
	emake DESTDIR="${ED}" install-tools install-doc

	# install our own init script
	newinitd "${FILESDIR}"/${PN}-8.0.rc ${PN/-utils/}

	dodoc scripts/drbd.conf.example

	dosym /usr/sbin/drbdadm /sbin/drbdadm

	keepdir /var/lib/drbd

	newtmpfiles "${FILESDIR}/drbd.tmpfiles" drbd.conf

	# https://bugs.gentoo.org/698304
	[[ "$(get_libdir)" != "lib" ]] && dosym "../$(get_libdir)/drbd" /lib/drbd
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
