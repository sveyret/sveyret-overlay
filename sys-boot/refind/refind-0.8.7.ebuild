# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

DESCRIPTION="rEFInd is an UEFI boot manager"
HOMEPAGE="http://www.rodsbooks.com/refind/"
SRC_URI="mirror://sourceforge/project/${PN}/${PV}/${PN}-src-${PV}.zip"
RESTRICT="primaryuri"

LICENSE="BSD GPL-2 GPL-3 FDL-1.3"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="-gnuefi +install"

DEPEND="gnuefi? ( >=sys-boot/gnu-efi-3.0.2 )"
DEPEND="${DEPEND} !gnuefi? ( >=sys-boot/edk2-2014.1.1 )"

pkg_setup() {
	export EDK2_VERS="2014.1.1"
	export ARCH="x86_64"
	export ARCH_SIZE="64"
	export EFILIB_DIR="/usr/lib${ARCH_SIZE}/edk2-${EDK2_VERS}"
}

src_configure() {
	for f in "${S}/Make.tiano" "${S}"/*/Make.tiano; do
		sed -i -e 's/^\(EDK2BASE\s*=.*\)$/#\1/' \
			-e '/^\s*-I \$(EDK2BASE).*$/d' \
			-e 's/^\(include .*target.txt.*\)$/#\1/' \
			-e 's@^\(INCLUDE_DIRS\s*=\s*-I\s*\).*$@\1/usr/include/edk2 \\@' \
			-e 's/^\(GENFW\s*=\s*\).*$/\1\$(prefix)GenFw/' \
			-e 's@\$(EDK2BASE)/BaseTools/Scripts@'${EFILIB_DIR}'@' \
			-e 's@^\(EFILIB\s*=\s*\).*$@\1'${EFILIB_DIR}'@' \
			-e 's@\$(EFILIB).*/\([^/]*\).lib@-l\1@' \
			-e 's/\(--start-group\s*\$(ALL_EFILIBS)\)/-L \$(EFILIB) \1/' \
			"${f}" || die "Failed to patch Tianocore make file in" \
			$(basename $(dirname ${f}))
	done
	sed -i -e 's@^\(ThisDir\s*=\s*\).*$@\1/usr/lib/'${P}'@' \
		-e 's@^\(ThisScript\s*=\s*"?\)[^/]*@\1/usr/sbin@' \
		"${S}/install.sh" || die "Failed to patch installation script"
}

src_compile() {
	# Make main EFI
	if use gnuefi; then
		all_target=gnuefi
	else
		all_target=all
	fi
	emake ${all_target}

	# Make filesystem drivers
	use gnuefi && export gnuefi_target="_gnuefi"
	for d in ext2 ext4 reiserfs iso9660 hfs ntfs; do
		emake -C "${S}/filesystems" "${d}${gnuefi_target}"
	done
}

src_install() {
	newsbin "${S}/install.sh" refind-install
	insinto "/usr/lib/${P}"
	doins "${S}/refind"/*.efi
	doins -r "${S}"/drivers_*
	doins -r "${S}"/icons
	doins -r "${S}"/keys
	doins "${S}"/refind.conf-sample
}

pkg_postinst() {
	if use install ; then
		if /usr/sbin/refind-install; then
			elog "rEFInd has been installed in your system. It will be active"
			elog "at next reboot."
		else
			eerror "rEFInd could not be properly installed in your system."
		fi
	fi
	elog "You can use the command refind-install in order to install"
	elog "rEFInd to a given partition."
}

