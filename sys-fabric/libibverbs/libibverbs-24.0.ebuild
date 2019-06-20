# Copyright 1999-2019 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

RDMA_CORE_TARGETS=(
	ibverbs
)
RDMA_CORE_TARGETS_NATIVE=(
	ibv_asyncwatch
	ibv_devices
	ibv_devinfo
	ibv_rc_pingpong
	ibv_srq_pingpong
	ibv_uc_pingpong
	ibv_ud_pingpong
	ibv_xsrq_pingpong
)
RDMA_CORE_INSTALL_TARGETS=(
	libibverbs/install
)
RDMA_CORE_INSTALL_TARGETS_NATIVE=(
	libibverbs/examples/install
	libibverbs/man/install
)

inherit rdma-core

DESCRIPTION="A library to use InfiniBand 'verbs' for direct access to IB hardware"

KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86 ~amd64-linux"
IUSE="static-libs"

SLOT="0/1"

multilib_src_install()
{
	rdma-core_multilib_src_install

	# Install files with no associated target
	use static-libs &&
		dolib.a lib/libibverbs.a

	insinto /usr/$(get_libdir)/pkgconfig
	doins lib/pkgconfig/libibverbs.pc
}
