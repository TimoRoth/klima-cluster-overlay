# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools toolchain-funcs

MY_PV=${PV/_/-}
DESCRIPTION="Unified Communication X"
HOMEPAGE="https://www.openucx.org"
SRC_URI="https://github.com/openucx/ucx/releases/download/v${PV}/${P}.tar.gz"
S="${WORKDIR}/${PN}-${MY_PV}"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 -riscv ~x86 ~amd64-linux ~x86-linux"
IUSE="+openmp knem"

RDEPEND="
	sys-cluster/rdma-core
	sys-libs/binutils-libs:=
	knem? ( >=sys-cluster/knem-1.1 )
"
DEPEND="${RDEPEND}"

PATCHES=(
	"${FILESDIR}"/${PN}-1.13.0-drop-werror.patch
)

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

src_prepare() {
	default
	sed -i 's/rpm/false/g' src/uct/ib/Makefile.am || die
	eautoreconf
}

src_configure() {
	BASE_CFLAGS="" econf \
		--disable-compiler-opt \
		--without-fuse3 \
		--without-go \
		--without-java \
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
