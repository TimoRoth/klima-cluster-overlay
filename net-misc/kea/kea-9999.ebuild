# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
inherit eapi9-ver flag-o-matic meson python-r1 systemd tmpfiles toolchain-funcs

DESCRIPTION="High-performance production grade DHCPv4 & DHCPv6 server"
HOMEPAGE="https://www.isc.org/kea/"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://gitlab.isc.org/isc-projects/kea.git"
else
	SRC_URI="https://downloads.isc.org/isc/kea/${PV}/${P}.tar.xz"
	KEYWORDS="~amd64 ~arm ~arm64 ~x86"
fi

LICENSE="MPL-2.0"
SLOT="0"
IUSE="debug doc kerberos mysql +openssl postgres shell test"

REQUIRED_USE="shell? ( ${PYTHON_REQUIRED_USE} )"
RESTRICT="!test? ( test )"

COMMON_DEPEND="
	>=dev-libs/boost-1.66:=
	dev-libs/log4cplus:=
	kerberos? (
		virtual/krb5
	)
	mysql? (
		app-arch/zstd:=
		dev-db/mysql-connector-c:=
		dev-libs/openssl:=
		sys-libs/zlib:=
	)
	!openssl? ( dev-libs/botan:2=[boost] )
	openssl? ( dev-libs/openssl:0= )
	postgres? ( dev-db/postgresql:* )
	shell? ( ${PYTHON_DEPS} )
"
DEPEND="${COMMON_DEPEND}
	test? ( dev-cpp/gtest )
"
RDEPEND="${COMMON_DEPEND}
	acct-group/dhcp
	acct-user/dhcp
"
BDEPEND="
	>=dev-build/meson-1.8
	doc? (
		$(python_gen_any_dep '
			dev-python/sphinx[${PYTHON_USEDEP}]
			dev-python/sphinx-rtd-theme[${PYTHON_USEDEP}]
		')
	)
	virtual/pkgconfig
"

python_check_deps() {
	use doc || return 0;
	python_has_version "dev-python/sphinx[${PYTHON_USEDEP}]" \
		"dev-python/sphinx-rtd-theme[${PYTHON_USEDEP}]"
}

pkg_setup() {
	if use doc || use shell; then
		python_setup
	fi
}

src_prepare() {
	default

	# Remove documentation from build
	if use !doc; then
		sed -e "/^subdir('doc')$/d" \
		-i meson.build || die
	fi

	# Fix up doc path where examples go
	sed -e "s:DATADIR / 'doc/kea':DATADIR / 'doc/${P}':" \
		-i meson.build || die

	# set shebang before meson if we are installing the shell
	if use shell; then
		sed -e 's:^#!@PYTHON@:#!/usr/bin/env python3:' \
		-i src/bin/shell/kea-shell.in || die
	fi

	# Don't allow meson to install shell
	sed -e 's:install\: true:install\: false:' \
		-i src/bin/shell/meson.build || die

	# do not create /run
	sed -e '/^install_emptydir(RUNSTATEDIR)$/d' \
		-i meson.build || die
}

src_configure() {
	# https://bugs.gentoo.org/861617
	# https://gitlab.isc.org/isc-projects/kea/-/issues/3946
	#
	# Kea Devs say no to LTO
	filter-lto

	local emesonargs=(
		--localstatedir="${EPREFIX}/var"
		-Drunstatedir="${EPREFIX}/run"
		-Dnetconf=disabled
		-Dcrypto=$(usex openssl openssl botan)
		$(meson_feature kerberos krb5)
		$(meson_feature mysql)
		$(meson_feature postgres postgresql)
		$(meson_feature test tests)
	)
	if use debug; then
		emesonargs+=(
			--debug
		)
	fi
	meson_src_configure
}

src_test() {
	# Get list of all test suites into an associative array
	# the meson test --list returns either "kea / test_suite", "kea:shell-tests / test_suite" or "kea:python-tests / test_suite"
	# Discard the shell tests as we can't run shell tests in sandbox

	pushd "${BUILD_DIR}" || die
	local -A TEST_SUITES
	while IFS=" / " read -r subsystem test_suite ; do
		if [[ ${subsystem} != "kea:shell-tests" ]]; then
			TEST_SUITES["$test_suite"]=1
		fi
	done < <(meson test --list || die)
	popd

	# Some other tests will fail for interface access restrictions, we have to remove the test suites those tests
	# belong to
	local SKIP_TESTS=(
		dhcp-radius-tests
		kea-log-buffer_logger_test.sh
		kea-log-console_test.sh
		dhcp-lease-query-tests
		kea-dhcp6-tests
	)

	if [[ $(tc-get-ptr-size) -eq 4 ]]; then
		# see https://bugs.gentoo.org/958171 for reason for skipping these tests
		SKIP_TESTS+=(
			kea-util-tests
			kea-dhcp-tests
			kea-dhcp4-tests
			kea-dhcpsrv-tests
			dhcp-ha-lib-tests
			kea-d2-tests
		)
	fi

	for SKIP in ${SKIP_TESTS[@]}; do
		unset TEST_SUITES["${SKIP}"]
	done

	meson_src_test ${!TEST_SUITES[@]}
}

install_shell() {
	python_domodule "${ORIG_BUILD_DIR}"/src/bin/shell/*.py
	python_doscript "${ORIG_BUILD_DIR}"/src/bin/shell/kea-shell

	# fix path to import kea modules
	sed -e "/^sys.path.append/s|(.*)|('$(python_get_sitedir)/${PN}')|"	\
		-i "${ED}"/usr/lib/python-exec/${EPYTHON}/kea-shell || die
}

src_install() {
	meson_install

	# No easy way to control how meson_install sets permissions in meson < 1.9
	# So make sure permissions are same as in previous versions of kea
	# To avoid any differences between an update vers first time install
	fperms -R 0755 /usr/sbin
	fperms -R 0755 /usr/bin
	fperms -R 0755 /usr/$(get_libdir)

	if use shell; then
		python_moduleinto ${PN}
		ORIG_BUILD_DIR="${BUILD_DIR}" python_foreach_impl install_shell
	fi

	dodoc -r doc/examples

	diropts -m 0750 -o root -g dhcp
	dodir /etc/kea
	insopts -m 0640 -o root -g dhcp
	insinto /etc/kea
	newins doc/examples/agent/comments.json kea-ctrl-agent.conf.sample
	newins doc/examples/kea6/simple.json kea-dhcp6.conf.sample
	newins doc/examples/kea4/single-subnet.json kea-dhcp4.conf.sample
	newins doc/examples/ddns/comments.json kea-dhcp-ddns.conf.sample

	# set log to syslog by default
	sed -e 's/"output": "stdout"/"output": "syslog"/' \
		-i "${ED}"/etc/kea/*.conf.sample || die

	newconfd "${FILESDIR}"/${PN}-confd-r2 ${PN}
	newinitd "${FILESDIR}"/${PN}-initd-r2 ${PN}

	systemd_dounit "${FILESDIR}"/${PN}-ctrl-agent.service-r2
	systemd_dounit "${FILESDIR}"/${PN}-dhcp-ddns.service-r2
	systemd_dounit "${FILESDIR}"/${PN}-dhcp4.service-r2
	systemd_dounit "${FILESDIR}"/${PN}-dhcp6.service-r2

	newtmpfiles "${FILESDIR}"/${PN}.tmpfiles.conf ${PN}.conf

	keepdir /var/lib/${PN} /var/log/${PN}
	fowners -R dhcp:dhcp /var/lib/${PN} /var/log/${PN}
	fperms 750 /var/lib/${PN} /var/log/${PN}
}

pkg_postinst() {
	tmpfiles_process ${PN}.conf

	if ver_replacing -lt 2.6; then
		ewarn "Several changes have been made for daemons:"
		ewarn "  To comply with common practices for this package,"
		ewarn "  config paths by default has been changed as below:"
		ewarn "    /etc/kea/kea-dhcp4.conf"
		ewarn "    /etc/kea/kea-dhcp6.conf"
		ewarn "    /etc/kea/kea-dhcp-ddns.conf"
		ewarn "    /etc/kea/kea-ctrl-agent.conf"
		ewarn
		ewarn "  Daemons are launched by default with the unprivileged user 'dhcp'"
		ewarn
		ewarn "Please check your configuration!"
	fi

	if ! has_version net-misc/kea; then
		elog "See config files in:"
		elog "  ${EROOT}/etc/kea/*.sample"
		elog "  ${EROOT}/usr/share/doc/${PF}/examples"
	fi
}
