# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit git-r3 flag-o-matic toolchain-funcs systemd java-pkg-opt-2 bash-completion-r1

DESCRIPTION="The Parallel Cluster File System"
HOMEPAGE="https://www.beegfs.io"

EGIT_REPO_URI="https://git.beegfs.io/pub/v7.git"
EGIT_COMMIT="${PV}"

LICENSE="BeeGFS-EULA"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+client +utils ib upgraders helperd meta storage mgmtd mon admon admon-gui java bash-completion"
REQUIRED_USE="admon-gui? ( java )"

DEPEND="
	sys-apps/attr
	dev-libs/openssl:0=
	sys-libs/zlib:=
	dev-db/sqlite:3
	net-misc/curl[curl_ssl_openssl]
	storage?
	(
		sys-fs/xfsprogs
	)
	ib?
	(
		sys-fabric/librdmacm
		sys-fabric/libibverbs
	)
	java?
	(
		>=virtual/jdk-1.6:*
	)
	admon-gui?
	(
		dev-java/ant
	)"
RDEPEND="${DEPEND}
	client? ( =sys-cluster/beegfs-kmod-${PV}*[ib=] )"
BDEPEND=""

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
	# This produces a ton of very verbose warnings.
	# Disabling the warning to keep build log readable.
	append-cxxflags -Wno-class-memaccess

	einfo "Building thirdparty dependencies..."
	beegfs_emake thirdparty

	einfo "Building common code..."
	beegfs_emake -C common/build libbeegfs-common.a

	if use ib; then
		einfo "Building InfiniBand plugin..."
		beegfs_emake -C common/build libbeegfs_ib.so
	fi

	if use utils; then
		einfo "Building utils..."
		beegfs_emake utils
	fi

	for comp in helperd meta storage mgmtd mon; do
		use "${comp}" || continue
		einfo "Building ${comp}..."
		beegfs_emake "${comp}-all"
	done

	if use upgraders; then
		einfo "Building upgraders..."
		beegfs_emake -C upgrade/beegfs_mirror_md/build all
	fi

	if use admon; then
		einfo "Building admon..."
		beegfs_emake -C admon/build all
	fi

	if use java; then
		einfo "Building Java bindings..."
		beegfs_emake -C java_lib/build
	fi

	if use admon-gui; then
		einfo "Building admon-gui..."
		beegfs_emake -C admon/build admon_gui
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

	if use ib; then
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
			test -f "${uf}" || continue
			systemd_dounit "${uf}"
		done
	done

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

	if use admon; then
		einfo "Installing admon..."

		exeinto /opt/beegfs/sbin
		doexe admon/build/beegfs-admon
		doexe admon/build/dist/sbin/beegfs-setup-admon

		mkdir -p "${ED}"/opt/beegfs/setup/info || die
		touch "${ED}"/opt/beegfs/setup/info/{clients,ib_nodes,management,meta_server,meta_server} || die

		keepdir /opt/beegfs/setup/tmp

		insinto /opt/beegfs/setup
		doins -r admon/scripts/*

		insinto /etc/beegfs
		doins admon/build/dist/etc/beegfs-admon.conf

		keepdir /var/lib/beegfs/www

		systemd_dounit admon/build/dist/usr/lib/systemd/system/beegfs-admon.service
	fi

	if use admon-gui; then
		einfo "Installing admon-gui..."

		insinto /usr/bin
		doins admon/build/dist/usr/bin/beegfs-admon-gui

		insinto /opt/beegfs/beegfs-admon-gui
		doins admon_gui/dist/beegfs-admon-gui.jar
	fi

	if use bash-completion && use utils; then
		echo "Installing beegfs-ctl bash-completions..."
		newbashcomp utils/scripts/etc/bash_completion.d/beegfs-ctl beegfs-ctl
	fi
}
