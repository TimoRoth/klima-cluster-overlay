# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 flag-o-matic toolchain-funcs systemd java-pkg-opt-2 bash-completion-r1

DESCRIPTION="The Parallel Cluster File System"
HOMEPAGE="https://www.beegfs.io"

EGIT_REPO_URI="https://github.com/ThinkParQ/beegfs.git"
EGIT_COMMIT="${PV}"

LICENSE="BeeGFS-EULA"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+client +utils infiniband upgraders helperd meta storage mgmtd mon java beeond bash-completion grafana"
REQUIRED_USE="
	beeond? ( utils mgmtd meta storage client helperd )"

DEPEND="
	sys-apps/attr
	dev-libs/openssl:0=
	sys-libs/zlib:=
	dev-db/sqlite:3
	net-misc/curl[curl_ssl_openssl]
	storage? ( sys-fs/xfsprogs )
	infiniband?	( sys-cluster/rdma-core:=[neigh] )
	java? ( >=virtual/jdk-1.6:* )"
RDEPEND="${DEPEND}
	client? ( =sys-cluster/beegfs-kmod-${PV}*[infiniband=] )"

src_prepare()
{
	java-pkg-opt-2_src_prepare
}

beegfs_emake() {
	# - A lot of code and guides for beegfs assume binaries and scripts to reside in /opt/beegfs.
	#   So for compatiblity, we do so as well. The official deb/rpm packages do the same.
	# - ARCH is randomly put into CFLAGS in some Makefiles, so it has to be emptied.
	# - Setting C{,PP,XX}FLAGS breaks the build, since it overwrites the projects own flags.
	env -u ARCH -u CPPFLAGS -u CFLAGS -u CXXFLAGS emake \
		BEEGFS_VERSION="${PV}" \
		PREFIX="${EPREFIX}/opt/beegfs" \
		CC="$(tc-getCC) ${CPPFLAGS} ${CFLAGS}" \
		CXX="$(tc-getCXX) ${CPPFLAGS} ${CXXFLAGS}" \
		AR="$(tc-getAR)" \
		STRIP="$(tc-getSTRIP)" \
		V=1 verbose=1 \
		"$@"
}

src_compile() {
	einfo "Building thirdparty dependencies..."
	beegfs_emake thirdparty

	einfo "Building common code..."
	beegfs_emake -C common/build libbeegfs-common.a

	if use infiniband; then
		einfo "Building InfiniBand plugin..."
		beegfs_emake -C common/build libbeegfs_ib.so
	fi

	main_targets=( $(usex utils "utils " "") )
	for comp in helperd meta storage mgmtd mon; do
		main_targets+=( $(usex "${comp}" "${comp}-all " "") )
	done

	if [[ ${#main_targets[@]} != 0 ]]; then
		einfo "Building tools and services..."
		beegfs_emake "${main_targets[@]}"
	fi

	if use upgraders; then
		einfo "Building upgraders..."
		beegfs_emake -C upgrade/beegfs_mirror_md/build all
	fi

	if use java; then
		einfo "Building Java bindings..."
		beegfs_emake -C java_lib/build
	fi

	if use beeond; then
		einfo "Building beeond..."
		beegfs_emake -C beeond_thirdparty_gpl/build
	fi
}

src_install() {
	if use client; then
		einfo "Installing client tools..."

		insinto /usr/include
		doins -r client_devel/include/beegfs/*

		insinto /etc/beegfs
		doins client_module/build/dist/etc/{beegfs-client.conf,beegfs-mounts.conf,beegfs-client-mount-hook.example}

		exeinto /opt/beegfs/sbin
		doexe client_module/build/dist/sbin/beegfs-setup-client

		exeinto /opt/beegfs/lib
		doexe "${FILESDIR}"/beegfs-mount-helper
		systemd_newunit "${FILESDIR}"/client.service beegfs-client.service
	fi

	if use infiniband; then
		einfo "Installing InfiniBand plugin..."

		insinto /opt/beegfs/lib
		doins common/build/libbeegfs_ib.so
	fi

	if use utils; then
		einfo "Installing utils..."

		beegfs_emake DESTDIR="${ED}" utils-install

		insinto /usr/include
		doins -r event_listener/include/*

		exeinto /usr/bin
		doexe utils/scripts/beegfs-*

		exeinto /sbin
		doexe utils/scripts/fsck.beegfs

		mkdir -p "${ED}"/usr/sbin || die
		ln -s "${EPREFIX}"/opt/beegfs/sbin/beegfs-ctl "${ED}"/usr/sbin/beegfs-ctl || die
		ln -s "${EPREFIX}"/opt/beegfs/sbin/beegfs-fsck "${ED}"/usr/sbin/beegfs-fsck || die
	fi

	for comp in helperd meta storage mgmtd mon; do
		use "${comp}" || continue
		einfo "Installing ${comp}..."

		beegfs_emake DESTDIR="${ED}" "${comp}-install"

		insinto /etc/beegfs
		doins "${comp}"/build/dist/etc/beegfs-"${comp}".conf

		for uf in "${comp}"/build/dist/usr/lib/systemd/system/beegfs-"${comp}"{,@}.service; do
			[[ -f "${uf}" ]] && systemd_dounit "${uf}"
		done

		exeinto /opt/beegfs/sbin
		setup_script="${comp}/build/dist/sbin/beegfs-setup-${comp}"
		[[ -f "${setup_script}" ]] && doexe "${setup_script}"
	done

	if use grafana; then
		einfo "Installing grafana dashboards..."

		insinto /opt/beegfs/lib/grafana
		doins mon/scripts/grafana/*
	fi

	if use upgraders; then
		einfo "Installing upgraders..."

		exeinto /opt/beegfs/sbin
		doexe upgrade/beegfs_mirror_md/build/beegfs-mirror-md
	fi

	if use java; then
		einfo "Installing Java bindings..."

		insinto /opt/beegfs/lib
		doins \
			java_lib/build/libjbeegfs.so \
			java_lib/build/jbeegfs.jar
	fi

	if use beeond; then
		einfo "Installing beeond..."

		exeinto /opt/beegfs/thirdparty
		doexe beeond_thirdparty_gpl/build/parallel

		exeinto /opt/beegfs/sbin
		doexe beeond/source/beeond{,-cp}

		insinto /opt/beegfs/lib
		doins -r beeond/scripts/lib/*

		mkdir -p "${ED}"/usr/bin || die
		ln -s "${EPREFIX}"/opt/beegfs/sbin/beeond "${ED}"/usr/bin/beeond || die
		ln -s "${EPREFIX}"/opt/beegfs/sbin/beeond-cp "${ED}"/usr/bin/beeond-cp || die
	fi

	if use bash-completion && use utils; then
		echo "Installing beegfs-ctl bash-completions..."

		newbashcomp utils/scripts/etc/bash_completion.d/beegfs-ctl beegfs-ctl
	fi
}
