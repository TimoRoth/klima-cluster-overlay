# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MODULES_INITRAMFS_IUSE=+initramfs
inherit linux-info linux-mod-r1

MLNX_OFED_VER="$(ver_cut 1-2)-$(ver_cut 3-6)"
MLNX_OFED_KERNEL_VER="$(ver_cut 7-8).OFED.$(ver_cut 7-)"

DESCRIPTION="Mellanox Ofed Kernel Modules"
HOMEPAGE="https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/"
SRC_URI="https://content.mellanox.com/ofed/MLNX_OFED-${MLNX_OFED_VER}/MLNX_OFED_SRC-debian-${MLNX_OFED_VER}.tgz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="gds +mlx5 nfs nvme"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

S="${WORKDIR}/mlnx-ofed-kernel-${MLNX_OFED_KERNEL_VER}"

QA_CONFIG_IMPL_DECL_SKIP=( "*" )

pkg_setup() {
	if ! linux_config_exists; then
		eerror "Unable to check your kernel"
		return
	fi

	# If one of these two is enabled, mlnx_ofed builds a dummy
	# and kills smb/9p support entirely.
	CONFIG_CHECK="
		~!CIFS_SMB_DIRECT
		~!NET_9P_RDMA"

	# rnbd needs rtrs symbols mlnx_ofed does not provide
	CONFIG_CHECK+=" ~!BLK_DEV_RNBD"

	# The nvme fabric driver hard-depends on it
	use nvme && CONFIG_CHECK+=" CONFIGFS_FS"

	check_extra_config

	REQ_MODULES="INFINIBAND"
	use nvme && REQ_MODULES+=" NVME_TARGET NVME_CORE"
	use mlx5 && REQ_MODULES+=" MLX5_CORE MLX5_INFINIBAND MLXFW"
	use nfs && REQ_MODULES+=" SUNRPC_XPRT_RDMA"
	for module in ${REQ_MODULES}; do
		einfo "Checking whether ${module} is a module..."
		linux_chkconfig_module ${module} || ewarn "${module} has to be a module (not built-in or disabled)!"
	done

	linux-mod-r1_pkg_setup
}

src_unpack() {
	default
	unpack "MLNX_OFED_SRC-${MLNX_OFED_VER}/SOURCES/mlnx-ofed-kernel_${MLNX_OFED_KERNEL_VER}.orig.tar.gz"
}

src_configure() {
	local myconf=(
		--with-njobs=64
		--prefix="${EPREFIX}"/usr
		--kernel-version="${KV_FULL}"
		--kernel-sources="${KERNEL_DIR}"
		--with-linux="${KERNEL_DIR}"
		--with-linux-obj="${KERNEL_DIR}"
		--with-core-mod
		--with-user_mad-mod
		--with-user_access-mod
		--with-addr_trans-mod
		--with-ipoib-mod
	)

	use mlx5 && myconf+=(
		--with-mlx5-mod
		--with-mlxfw-mod
		--with-mlxdevm-mod
	)

	use nfs && myconf+=(
		--with-nfsrdma-mod
	)

	use nvme && myconf+=(
		--with-nvmf_host-mod
		--with-nvmf_target-mod
	)

	use gds && myconf+=(
		--with-gds
	)

	env -u ARCH -u CFLAGS -u CXXFLAGS -u COMMON_FLAGS \
		CC="${KERNEL_CC}" ./configure "${myconf[@]}" || die
}

src_compile() {
	emake "${MODULES_MAKEARGS[@]}"
}

src_install() {
	emake "${MODULES_MAKEARGS[@]}" install_modules INSTALL_MOD_PATH="${ED}" INSTALL_MOD_DIR="updates" KERNELRELEASE="${KV_FULL}"
	find "${ED}" \( -type f -a -name "modules.*" \) -delete || die

	insinto /usr/src/ofa_kernel/"$(uname -m)"/"${KV_FULL}"
	doins -r include ofed_scripts compat?*
	doins config* Module*.symvers

	ln -s "$(uname -m)/${KV_FULL}" "${ED}"/usr/src/ofa_kernel/default || die

	modules_post_process
}
