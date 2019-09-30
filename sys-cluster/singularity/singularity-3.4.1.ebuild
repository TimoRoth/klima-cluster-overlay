# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Application containers for Linux"
HOMEPAGE="https://www.sylabs.io/singularity/"
SRC_URI="https://github.com/sylabs/${PN}/releases/download/v${PV}/${P}.tar.gz"

LICENSE="cctbx-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~amd64-linux ~x86-linux"
IUSE="examples +suid"

DEPEND=">=dev-lang/go-1.10
	sys-libs/libseccomp
	dev-libs/openssl:0
	sys-fs/cryptsetup
	app-crypt/gpgme"
RDEPEND="sys-fs/squashfs-tools:0"

S="${WORKDIR}/src/github.com/sylabs/singularity"

src_unpack()
{
	default
	mkdir -p src/github.com/sylabs || die
	mv singularity src/github.com/sylabs/singularity || die
}

src_prepare() {
	sed -i -e 's/-Werror//' -e 's/-Wno-unknown-warning-option//' mlocal/frags/common_opts.mk || die
	default
}

src_configure() {
	./mconfig -v \
		--prefix="${EPREFIX}"/usr \
		--sysconfdir="${EPREFIX}"/etc \
		--localstatedir="${EPREFIX}"/var || die
}

src_compile() {
	GOPATH="$WORKDIR" emake -C builddir all
}

src_install() {
	emake -j1 -C builddir DESTDIR="${D}" install

	use suid || rm "${ED}/usr/libexec/singularity/bin/starter-suid" || die
	keepdir /var/singularity/mnt/session

	dodoc README.md CONTRIBUTORS.md CONTRIBUTING.md CHANGELOG.md
	use examples && dodoc -r examples
}
