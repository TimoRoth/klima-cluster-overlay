# Copyright 1999-2019 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: rdma-core.eclass
# @SUPPORTED_EAPIS: 7
# @BLURB: Simplify working with rdma-core packages

case ${EAPI:-0} in
	7) ;;
	*) die "${ECLASS}: EAPI ${EAPI} not supported" ;;
esac

# @ECLASS-VARIABLE: RDMA_CORE_TARGETS
# @DESCRIPTION:
# Bash array of cmake targets to build.

# @ECLASS-VARIABLE: RDMA_CORE_INSTALL_TARGETS
# @DESCRIPTION:
# Bash array of cmake targets to install.

# @ECLASS-VARIABLE: RDMA_CORE_TARGETS_NATIVE
# @DESCRIPTION:
# Bash array of additional cmake targets to build only on native arch.

# @ECLASS-VARIABLE: RDMA_CORE_INSTALL_TARGETS_NATIVE
# @DESCRIPTION:
# Bash array of additional cmake targets to install only on native arch.

# @ECLASS-VARIABLE: RDMA_CORE_TARGETS_STATIC
# @DESCRIPTION:
# Bash array of additional cmake targets to build when building static-libs.
# Since the rdma-core buildsystem does not allow not building (and installing)
# individual static libraries, all of them will have to be built, always.
: ${RDMA_CORE_TARGETS_STATIC:=make_static}

# @ECLASS-VARIABLE: RDMA_CORE_INSTALL_TARGETS_STATIC
# @DESCRIPTION:
# Bash array of additional cmake targets to install when building static-libs.

# @ECLASS-VARIABLE: RDMA_CORE_MULTILIB
# @DESCRIPTION:
# Build a multilib library if set to anything but 0.
# Implicitly enabled if any of RDMA_CORE{,_INSTALL}_TARGETS_NATIVE are set.
: ${RDMA_CORE_MULTILIB:=0}

if [[ ${#RDMA_CORE_TARGETS_NATIVE[@]} != 0 || ${#RDMA_CORE_INSTALL_TARGETS_NATIVE[@]} != 0 ]]; then
	RDMA_CORE_MULTILIB=1
fi

PYTHON_COMPAT=( python3_{5,6,7} )

inherit eutils cmake-utils python-any-r1

if [[ "${RDMA_CORE_MULTILIB}" != "0" ]]; then
	inherit multilib-minimal cmake-multilib
fi

EXPORT_FUNCTIONS src_configure src_compile src_install

HOMEPAGE="https://github.com/linux-rdma/rdma-core"
LICENSE="|| ( GPL-2 BSD-2 )"
SRC_URI="https://github.com/linux-rdma/rdma-core/releases/download/v${PV}/rdma-core-${PV}.tar.gz"

IUSE="+neigh systemd valgrind"

DEPEND="
	virtual/libudev:=
	neigh? ( dev-libs/libnl:3 )
	systemd? ( sys-apps/systemd:= )
	valgrind? ( dev-util/valgrind )"
RDEPEND="${DEPEND}"
BDEPEND="${PYTHON_DEPS}"

S="${WORKDIR}/rdma-core-${PV}"

rdma-core_src_configure() {
	local mycmakeargs=(
		-DCMAKE_DISABLE_FIND_PACKAGE_pandoc=ON
		-DCMAKE_DISABLE_FIND_PACKAGE_Systemd="$(usex systemd OFF ON)"
		-DENABLE_VALGRIND="$(usex valgrind ON OFF)"
		-DENABLE_RESOLVE_NEIGH="$(usex neigh ON OFF)"
	)

	ver_test -ge 25 &&
		mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_rst2man=ON )

	has static-libs ${IUSE} &&
		mycmakeargs+=( -DENABLE_STATIC="$(usex static-libs ON OFF)" )

	if [[ "${RDMA_CORE_MULTILIB}" != "0" ]]; then
		cmake-multilib_src_configure
	else
		cmake-utils_src_configure
	fi
}

_rdma-core_do_compile() {
	local _targets=( "${RDMA_CORE_TARGETS[@]}" )

	has static-libs ${IUSE} && use static-libs &&
		local _targets+=( "${RDMA_CORE_TARGETS_STATIC[@]}" )

	[[ "${RDMA_CORE_MULTILIB}" != "0" ]] && multilib_is_native_abi &&
		local _targets+=( "${RDMA_CORE_TARGETS_NATIVE[@]}" )

	[[ ${#_targets[@]} == 0 ]] && die "${ECLASS}: compile targets not set"

	cmake-utils_src_compile "${_targets[@]}"
}

rdma-core_src_compile() {
	if [[ "${RDMA_CORE_MULTILIB}" == "0" ]]; then
		_rdma-core_do_compile
	else
		multilib-minimal_src_compile
	fi
}

rdma-core_multilib_src_compile() {
	_rdma-core_do_compile
}

multilib_src_compile() {
	rdma-core_multilib_src_compile
}

_rdma-core_do_install_targets() {
	local _install_targets=( "${RDMA_CORE_INSTALL_TARGETS[@]}" )

	has static-libs ${IUSE} && use static-libs &&
		local _install_targets+=( "${RDMA_CORE_INSTALL_TARGETS_STATIC[@]}" )

	[[ "${RDMA_CORE_MULTILIB}" != "0" ]] && multilib_is_native_abi &&
		local _install_targets+=( "${RDMA_CORE_INSTALL_TARGETS_NATIVE[@]}" )

	[[ ${#_install_targets[@]} == 0 ]] && die "${ECLASS}: install targets not set"

	DESTDIR="${ED}" cmake-utils_src_make "${_install_targets[@]}"
}

rdma-core_src_install() {
	if [[ "${RDMA_CORE_MULTILIB}" == "0" ]]; then
		_rdma-core_do_install_targets
	else
		multilib-minimal_src_install
	fi

	einstalldocs
}

rdma-core_multilib_src_install() {
	_rdma-core_do_install_targets
}

multilib_src_install() {
	rdma-core_multilib_src_install
}
