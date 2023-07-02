#!/bin/sh

set -eu

# These packages will be installed in the root of the container (build-time dependencies).
DEB_PACKAGES="curl nano"
# These packages will be installed in the chroot (run-time dependencies).
CHROOT_PACKAGES="curl nano"
# Python packages
PY_PACKAGES="scipy"

install_c() {
	DEB_PACKAGES="gcc-12 $DEB_PACKAGES"
	CHROOT_PACKAGES="gcc-12 $DEB_PACKAGES"
}

install_cpp() {
	DEB_PACKAGES="g++-12 $DEB_PACKAGES"
	CHROOT_PACKAGES="g++-12 $DEB_PACKAGES"
}

install_java() {
	DEB_PACKAGES="openjdk-19-jdk-headless $DEB_PACKAGES"
	CHROOT_PACKAGES="openjdk-19-jre-headless $CHROOT_PACKAGES"
}

install_pypy3() {
	DEB_PACKAGES="python3.11-full python3-pip pypy3 $DEB_PACKAGES"
	CHROOT_PACKAGES="python3.11-full python3-pip pypy3 $CHROOT_PACKAGES"
}

install_csharp() {
	DEB_PACKAGES="mono-devel $DEB_PACKAGES"
	CHROOT_PACKAGES="mono-runtime $CHROOT_PACKAGES"
}

install_rust() {
	DEB_PACKAGES="rustc $DEB_PACKAGES"
	CHROOT_PACKAGES="rustc $CHROOT_PACKAGES"
}

install_js() {
	DEB_PACKAGES="nodejs $DEB_PACKAGES"
	CHROOT_PACKAGES="nodejs $CHROOT_PACKAGES"
}

# Flag for Haskell installation
HS_INSTALLED=0
install_hs() {
	DEB_PACKAGES="haskell-platform ghc $DEB_PACKAGES"
	CHROOT_PACKAGES="haskell-platform ghc $CHROOT_PACKAGES"
	HS_INSTALLED=1
}


install_debs() {
	apt update && apt install -y software-properties-common gnupg &&
	apt-add-repository -y "deb https://ppa.launchpadcontent.net/pypy/ppa/ubuntu jammy main"
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 2862D0785AFACD8C65B23DB0251104D968854915

	/opt/domjudge/judgehost/bin/dj_run_chroot '
	apt update && apt install -y software-properties-common gnupg &&
	apt-add-repository -y "deb https://ppa.launchpadcontent.net/pypy/ppa/ubuntu jammy main"
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 2862D0785AFACD8C65B23DB0251104D968854915
	'

	# execute commands in chroot
	/opt/domjudge/judgehost/bin/dj_run_chroot "export DEBIAN_FRONTEND=noninteractive &&
	apt update &&
	apt install -y --no-install-recommends --no-install-suggests ${CHROOT_PACKAGES} &&
	curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && # New node version
	apt install nodejs # New node version
	python3.11 -m pip install --no-input ${PY_PACKAGES} &&
	apt autoremove -y &&
	apt clean &&
	rm -rf /var/lib/apt/lists/* &&
	rm -rf /tmp/*"

	#execute command on home root
	apt update &&
	apt install -y --no-install-recommends --no-install-suggests ${DEB_PACKAGES} &&
	curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && # New node version
        apt install nodejs # New node version
	python3.11 -m pip install --no-input ${PY_PACKAGES} &&
	apt autoremove -y &&
	apt clean &&
	rm -rf /var/lib/apt/lists/* &&
	rm -rf /tmp/*

	# Haskell's GHC compiler looks for packages in the /usr/lib/ghc/package.conf.d directory.
	# However, /usr/lib/ghc/package.conf.d is symlinked to /var/lib/ghc/package.conf.d, which is not mounted during compilation in the chroot.
	# This means that although the packages are correctly installed into /var/lib/ghc/package.conf.d, GHC cannot find them.
	# To resolve this issue, we manually move the installed packages from /var/lib/ghc/package.conf.d to /usr/lib/ghc/package.conf.d,
	# so that they are placed in a persistent and accessible location for GHC to find when compiling Haskell programs.
	if [ $HS_INSTALLED -eq 1 ]; then
        	# execute commands in chroot
            	/opt/domjudge/judgehost/bin/dj_run_chroot "
            	rm -r /usr/lib/ghc/package.conf.d && cp -R /var/lib/ghc/package.conf.d /usr/lib/ghc/package.conf.d" # FIX HASKELL

            	#execute command on home root
            	rm -r /usr/lib/ghc/package.conf.d && cp -R /var/lib/ghc/package.conf.d /usr/lib/ghc/package.conf.d # FIX HASKELL
        fi
}

install_c
install_cpp
install_java
install_pypy3
install_csharp
install_rust
install_js
install_hs

# Enable networking in chroot
mv ${CHROOT}/etc/resolv.conf ${CHROOT}/etc/resolv.conf.bak
cp /etc/resolv.conf ${CHROOT}/etc
cp /etc/apt/sources.list ${CHROOT}/etc/apt/sources.list

[ "$DEB_PACKAGES" != "" ] && install_debs

# Restore original state
mv ${CHROOT}/etc/resolv.conf.bak ${CHROOT}/etc/resolv.conf
