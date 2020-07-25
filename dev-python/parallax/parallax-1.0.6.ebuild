# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{6,7,8,9} )

inherit distutils-r1

DESCRIPTION="Provides an interface to executing commands on multiple nodes at once using SSH"
HOMEPAGE="https://github.com/krig/parallax/"
SRC_URI="mirror://pypi/${PN:0:1}/${PN}/${PF}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~hppa ~x86"
IUSE=""

DEPEND=""
RDEPEND=""
BDEPEND="dev-python/setuptools[${PYTHON_USEDEP}]"
