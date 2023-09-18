# Copyright 1999-2022 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="The Process Management Interface (PMI) Exascale"
HOMEPAGE="https://openpmix.github.io/"
SRC_URI="https://github.com/openpmix/openpmix/releases/download/v${PV}/${P}.tar.bz2"

SLOT="0"
LICENSE="BSD"
KEYWORDS="~amd64 ~x86 ~amd64-linux ~x86-linux"
IUSE="debug +munge pmi +tools"

RDEPEND="
	dev-libs/libevent:0=
	sys-cluster/ucx
	sys-libs/zlib:0=
	munge? ( sys-auth/munge )
	pmi? ( !sys-cluster/slurm )
	"
DEPEND="${RDEPEND}"

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	econf \
		$(use_enable debug) \
		$(use_enable pmi pmi-backward-compatibility) \
		$(use_enable tools pmix-binaries) \
		$(use_with munge)
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die
}
