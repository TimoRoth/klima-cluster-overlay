# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="Unified Communication X"
HOMEPAGE="https://www.openucx.org"
SRC_URI="https://github.com/openucx/ucx/releases/download/v${PV}/${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 -riscv ~x86 ~amd64-linux ~x86-linux"
IUSE="+numa +openmp knem"

RDEPEND="
	sys-cluster/rdma-core
	sys-libs/binutils-libs:=
	numa? ( sys-process/numactl )
	knem? ( >=sys-cluster/knem-1.1 )
"
DEPEND="${RDEPEND}"

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	BASE_CFLAGS="" \
	econf \
		--disable-compiler-opt \
		--without-java \
		--without-go \
		$(use_enable numa) \
		$(use_enable openmp) \
		$(use_with knem)
}

src_compile() {
	BASE_CFLAGS="" emake
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die
}
