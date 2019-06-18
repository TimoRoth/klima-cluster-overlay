# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit git-r3 toolchain-funcs

DESCRIPTION="The Parallel Cluster File System"
HOMEPAGE="https://www.beegfs.io"

EGIT_REPO_URI="https://git.beegfs.io/pub/v7.git"
EGIT_COMMIT="${PV}"

LICENSE="BeeGFS-EULA"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+client ib +utils helperd meta storage mgmtd mon admon"

DEPEND="
	sys-apps/attr
	dev-libs/openssl
	sys-libs/zlib
	dev-db/sqlite:3
	net-misc/curl[curl_ssl_openssl]
	sys-fs/xfsprogs
	ib?
	(
		sys-fabric/librdmacm
		sys-fabric/libibverbs
	)
	admon?
	(
		virtual/jdk
		dev-java/ant
	)"
RDEPEND="${DEPEND}
	client? ( =sys-cluster/beegfs-kmod-${PV}* )"
BDEPEND=""

beegfs_emake() {
	# ARCH is randomly put into CFLAGS in some Makefiles, has to be empty.
	emake \
		BEEGFS_VERSION="${PV}" \
		PREFIX="${EPREFIX}/usr" \
		ARCH="" \
		CC="$(tc-getCC)" \
		CXX="$(tc-getCXX)" \
		AR="$(tc-getAR)" \
		STRIP="$(tc-getSTRIP)" \
		V=1 verbose=1 \
		"$@"
}

beegfs_any_enabled() {
	use utils || use helperd || use meta || use storage || use mgmtd || use mon
}

src_compile() {
	beegfs_emake thirdparty
	beegfs_emake -C common/build libbeegfs-common.a

	use ib &&
		beegfs_emake -C common/build libbeegfs_ib.so

	beegfs_any_enabled &&
		beegfs_emake \
			$(usex utils utils "") \
			$(usex helperd helperd-all "") \
			$(usex meta meta-all "") \
			$(usex storage storage-all "") \
			$(usex mgmtd mgmtd-all "") \
			$(usex mon mon-all "")

	if use admon; then
		beegfs_emake -C java_lib/build
		beegfs_emake -C admon/build all admon_gui
	fi
}

src_install() {
	insinto /usr/$(get_libdir)
	use ib &&
		doins common/build/libbeegfs_ib.so

	beegfs_any_enabled &&
		beegfs_emake DESTDIR="${ED}" \
			$(usex utils utils-install "") \
			$(usex helperd helperd-install "") \
			$(usex meta meta-install "") \
			$(usex storage storage-install "") \
			$(usex mgmtd mgmtd-install "") \
			$(usex mon mon-install "")

	if use admon; then
		#TODO
	fi
}
