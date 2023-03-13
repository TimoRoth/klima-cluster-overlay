# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="The Process Management Interface (PMI) Exascale"
HOMEPAGE="https://openpmix.github.io/"
SRC_URI="https://github.com/openpmix/openpmix/releases/download/v${PV}/${P}.tar.bz2"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~amd64-linux ~x86-linux"
IUSE="debug +munge pmi +tools"

RDEPEND="
	dev-libs/libevent:=
	sys-apps/hwloc:=
	sys-cluster/ucx
	sys-libs/zlib:=
	munge? ( sys-auth/munge )
	pmi? ( !sys-cluster/slurm )
"
DEPEND="${RDEPEND}"

src_prepare() {
	default
	# eautoreconf ## Re-Enable once weird configure.ac doc issue is resolved, https://github.com/openpmix/openpmix/issues/2975
}

src_configure() {
	econf \
		--disable-werror \
		$(use_enable debug) \
		$(use_enable tools pmix-binaries) \
		$(use_with munge)
}

src_install() {
	default

	find "${ED}" -name "*.la" -delete || die

	# bug #884765
	mv "${ED}"/usr/bin/pquery "${ED}"/usr/bin/pmix-pquery || die
}
