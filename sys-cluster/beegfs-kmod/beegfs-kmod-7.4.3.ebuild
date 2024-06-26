# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 linux-info linux-mod

DESCRIPTION="The Parallel Cluster File System"
HOMEPAGE="https://www.beegfs.io"

EGIT_REPO_URI="https://github.com/ThinkParQ/beegfs.git"
EGIT_COMMIT="${PV}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="infiniband"

MODULE_NAMES="beegfs(beegfs:client_module/build)"
MODULESD_BEEGFS_ALIASES=("fs-beegfs beegfs")
BUILD_PARAMS="BEEGFS_VERSION='${PV}'"

beegfs_version_check() {
	if ! kernel_is 6 1; then
		ewarn "BeeGFS only supports the latest LTS kernel at the time of each respective release."
		ewarn "(As well as the binary distro Kernels of their officialy supported distributions.)"
		ewarn ""
		ewarn "For ${P} that is linux-6.1."
		ewarn ""
		ewarn "Other kernels are not tested against and do not get any compatiblity fixes."
	fi

	if use infiniband; then
		local CONFIG_CHECK="INFINIBAND INFINIBAND_ADDR_TRANS INFINIBAND_USER_MAD INFINIBAND_USER_ACCESS"
		check_extra_config
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
	use infiniband && BUILD_PARAMS+=" BEEGFS_OPENTK_IBVERBS=1"

	BUILD_PARAMS+=" KDIR='${KERNEL_DIR}'"

	linux-mod_src_compile
}
