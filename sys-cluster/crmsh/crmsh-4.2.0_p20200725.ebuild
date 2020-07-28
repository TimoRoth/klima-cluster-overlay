# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{6,7,8,9} )

inherit autotools python-single-r1

MY_SCM_COMMIT="a06e892f15360f50561cc855c1b175b8effa1bc3"

DESCRIPTION="Pacemaker command line interface for management and configuration"
HOMEPAGE="https://crmsh.github.io/"
SRC_URI="https://github.com/crmsh/crmsh/archive/${MY_SCM_COMMIT}.tar.gz -> ${P}.tar.gz"
KEYWORDS="~amd64 ~hppa ~x86"

LICENSE="GPL-2"
SLOT="0"
IUSE=""

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

DEPEND="${PYTHON_DEPS}
	>=sys-cluster/pacemaker-1.1.9"
RDEPEND="${DEPEND}
	>=sys-cluster/csync2-2.0-r2
	$(python_gen_cond_dep '
		dev-python/lxml[${PYTHON_USEDEP}]
		dev-python/python-dateutil[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/parallax[${PYTHON_USEDEP}]
	')"

S="${WORKDIR}/${PN}-${MY_SCM_COMMIT}"

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	local myconf=(
		--with-ocf-root=/usr/$(get_libdir)/ocf
	)
	econf "${myconf[@]}"
}

src_install() {
	emake DESTDIR="${D}" install
	python_optimize
	rm -r "${D}/var/lib/log" || die
	keepdir /var/lib/cache/crm
}