# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit git-r3 linux-info linux-mod

DESCRIPTION="The Parallel Cluster File System"
HOMEPAGE="https://www.beegfs.io"

EGIT_REPO_URI="https://git.beegfs.io/pub/v7.git"
EGIT_COMMIT="${PV}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="ib"

MODULE_NAMES="beegfs(beegfs:client_module/build)"
MODULESD_BEEGFS_ALIASES=("fs-beegfs beegfs")
BUILD_PARAMS="BEEGFS_VERSION='${PV}'"

beegfs_version_check() {
	if ! kernel_is 4 19; then
		ewarn "BeeGFS only supports the latest LTS kernel at the time of each respective release."
		ewarn "(As well as the binary distro Kernels of their officialy supported distributions.)"
		ewarn ""
		ewarn "For ${P} that is linux-4.19."
		ewarn ""
		ewarn "Other kernels are not tested against and do not get any compatiblity fixes."
	fi
}

pkg_pretend() {
	beegfs_version_check
}

pkg_setup() {
	beegfs_version_check

	linux-mod_pkg_setup
}

src_compile() {
	use ib && BUILD_PARAMS+=" BEEGFS_OPENTK_IBVERBS=1"

	BUILD_PARAMS+=" KDIR='${KERNEL_DIR}'"

	linux-mod_src_compile
}
