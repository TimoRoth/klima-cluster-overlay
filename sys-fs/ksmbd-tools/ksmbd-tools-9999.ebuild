# Copyright 2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit autotools systemd

DESCRIPTION="KSMBD userspace tools"
HOMEPAGE="https://github.com/cifsd-team/ksmbd-tools"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/cifsd-team/ksmbd-tools.git"
else
	SRC_URI="https://github.com/cifsd-team/ksmbd-tools/releases/download/${PV}/${P}.tgz"
	KEYWORDS="~amd64"
	S="${WORKDIR}/${PN}"
fi

LICENSE="GPL-2+"
SLOT="0"
IUSE="kerberos kernel-builtin"

DEPEND="kerberos? ( virtual/krb5 )
	>=dev-libs/glib-2.40
	>=dev-libs/libnl-3.0"
RDEPEND="${DEPEND}
	!kernel-builtin? ( sys-fs/ksmbd )"

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	econf $(use_enable kerberos krb5)
}

src_install() {
	default

	insinto /etc/ksmbd
	doins smb.conf.example

	systemd_dounit "${FILESDIR}"/ksmbd.service
}
