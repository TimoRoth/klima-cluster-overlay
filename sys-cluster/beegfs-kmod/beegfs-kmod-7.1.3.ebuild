# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit git-r3 linux-mod

DESCRIPTION="The Parallel Cluster File System"
HOMEPAGE="https://www.beegfs.io"

EGIT_REPO_URI="https://git.beegfs.io/pub/v7.git"
EGIT_COMMIT="${PV}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="ib ofed"
REQUIRED_USE="ofed? ( ib )"

DEPEND="ofed? ( >=sys-fabric/ofed-4.17 )"
RDEPEND="${DEPEND}"
BDEPEND=""

MODULE_NAMES="beegfs(beegfs:client_module/build:client_module/build)"
MODULESD_BEEGFS_ALIASES=("fs-beegfs beegfs")
BUILD_PARAMS="BEEGFS_VERSION='${PV}'"

src_compile() {
	use ib && BUILD_PARAMS+=" BEEGFS_OPENTK_IBVERBS=1"
	use ofed && BUILD_PARAMS+=" OFED_INCLUDE_PATH=/usr/include/infiniband'"

	linux-mod_src_compile
}