# Copyright 2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit linux-mod

DESCRIPTION="KSMBD is an opensource In-kernel CIFS/SMB3 server"
HOMEPAGE="https://github.com/cifsd-team/ksmbd"
SRC_URI="https://github.com/cifsd-team/ksmbd/releases/download/${PV}/${P}.tgz"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"
IUSE="infiniband kerberos"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

MODULE_NAMES="ksmbd(kernel/fs/ksmbd)"
BUILD_TARGETS="all"
CONFIG_CHECK="
	INET
	MULTIUSER
	FILE_LOCKING
	NLS
	NLS_UTF8
	CRYPTO
	CRYPTO_MD4
	CRYPTO_MD5
	CRYPTO_HMAC
	CRYPTO_ECB
	CRYPTO_LIB_DES
	CRYPTO_SHA256
	CRYPTO_CMAC
	CRYPTO_SHA512
	CRYPTO_AEAD2
	CRYPTO_CCM
	CRYPTO_GCM
	ASN1
	OID_REGISTRY
	FS_POSIX_ACL"

S="${WORKDIR}/${PN}"

pkg_setup() {
	kernel_is -ge 5 4 || die "Linux 5.4 or greater is required for ksmbd"
	use infiniband && CONFIG_CHECK+=" INFINIBAND INFINIBAND_ADDR_TRANS"
	linux-mod_pkg_setup
}

src_compile() {
	BUILD_PARAMS="CONFIG_SMB_SERVER_CHECK_CAP_NET_ADMIN=y"
	KCPPFLAGS="-DCONFIG_SMB_SERVER_CHECK_CAP_NET_ADMIN=y"

	if use infiniband; then
		BUILD_PARAMS+=" CONFIG_SMB_SERVER_SMBDIRECT=y"
		KCPPFLAGS+=" -DCONFIG_SMB_SERVER_SMBDIRECT=y"
	fi

	if use kerberos; then
		BUILD_PARAMS+=" CONFIG_SMB_SERVER_KERBEROS5=y"
		KCPPFLAGS+=" -DCONFIG_SMB_SERVER_KERBEROS5=y"
	fi

	BUILD_PARAMS+=" KCPPFLAGS='${KCPPFLAGS}' KDIR='${KERNEL_DIR}' V=1"

	linux-mod_src_compile
}
