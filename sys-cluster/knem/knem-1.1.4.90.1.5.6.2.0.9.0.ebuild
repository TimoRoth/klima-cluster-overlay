# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools linux-mod linux-info toolchain-funcs udev multilib

MLNX_OFED_VER="$(ver_cut 6-7)-$(ver_cut 8-)"
KNEM_VER="$(ver_cut 1-4)mlnx$(ver_cut 5)"

DESCRIPTION="High-Performance Intra-Node MPI Communication"
HOMEPAGE="http://knem.gforge.inria.fr/"
SRC_URI="https://content.mellanox.com/ofed/MLNX_OFED-${MLNX_OFED_VER}/MLNX_OFED_SRC-debian-${MLNX_OFED_VER}.tgz"
KEYWORDS="~amd64 ~riscv ~x86"
S="${WORKDIR}/${PN}-${KNEM_VER}"

LICENSE="GPL-2 LGPL-2"
SLOT="0"
IUSE="debug +modules"

DEPEND="
		sys-apps/hwloc
		virtual/linux-sources"
RDEPEND="
		sys-apps/hwloc
		sys-apps/kmod[tools]"

MODULE_NAMES="knem(misc:${S}/driver/linux)"
BUILD_TARGETS="all"
BUILD_PARAMS="KDIR=${KERNEL_DIR}"

pkg_setup() {
	CONFIG_CHECK="DMA_ENGINE"
	linux-info_pkg_setup
	linux-mod_pkg_setup
	export ARCH="$(tc-arch-kernel)"
	export ABI="${KERNEL_ABI}"
}

src_unpack() {
	default
	unpack "MLNX_OFED_SRC-${MLNX_OFED_VER}/SOURCES/${PN}_${KNEM_VER}.orig.tar.gz"
}

src_prepare() {
	default
	sed -ie "s|driver/linux||g" Makefile.am || die
	eautoreconf
}

src_configure() {
	econf \
		--enable-hwloc \
		--with-linux="${KERNEL_DIR}" \
		--with-linux-build="${KERNEL_DIR}" \
		--with-linux-release=${KV_FULL} \
		$(use_enable debug)
}

src_compile() {
	default
	if use modules; then
		linux-mod_src_compile
	fi
}

src_install() {
	default
	if use modules; then
		linux-mod_src_install
	fi

	# Drop funny unneded stuff
	rm "${ED}/usr/sbin/knem_local_install" || die
	rmdir "${ED}/usr/sbin" || die

	# install udev rules
	udev_dorules "${FILESDIR}/45-knem.rules"
	rm "${ED}/etc/10-knem.rules" || die
}

pkg_postinst() {
	udev_reload
}

pkg_postrm() {
	udev_reload
}
