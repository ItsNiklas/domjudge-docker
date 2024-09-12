#!/bin/sh

set -eu

# These packages will be installed in the root of the container (build-time dependencies).
DEB_PACKAGES="curl nano"
# These packages will be installed in the chroot (run-time dependencies).
CHROOT_PACKAGES="curl nano"
# Python packages
PY_PACKAGES="scipy"

install_c() {
	CHROOT_PACKAGES="gcc-12 $DEB_PACKAGES"
}

install_cpp() {
	CHROOT_PACKAGES="g++-12 $DEB_PACKAGES"
}

install_java() {
	CHROOT_PACKAGES="openjdk-21-jre-headless $CHROOT_PACKAGES"
}

install_pypy3() {
	# Python in root may be required for custom compare scripts.
	CHROOT_PACKAGES="python3.13-full pypy3 $CHROOT_PACKAGES"
	DEB_PACKAGES="python3.13-full pypy3 $DEB_PACKAGES"
}

install_csharp() {
	CHROOT_PACKAGES="mono-runtime $CHROOT_PACKAGES"
}

install_rust() {
	CHROOT_PACKAGES="rustc $CHROOT_PACKAGES"
}

install_js() {
	CHROOT_PACKAGES="nodejs $CHROOT_PACKAGES"
}

# Flag for Haskell installation
HS_INSTALLED=0
install_hs() {
	CHROOT_PACKAGES="haskell-platform ghc $CHROOT_PACKAGES"
	HS_INSTALLED=1
}


install_debs() {
	/opt/domjudge/judgehost/bin/dj_run_chroot "
	apt update && apt install -y software-properties-common curl &&
	add-apt-repository ppa:pypy/ppa -y &&
	add-apt-repository ppa:deadsnakes/ppa -y
	curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && # New node version
	"

	# execute commands in chroot
	/opt/domjudge/judgehost/bin/dj_run_chroot "export DEBIAN_FRONTEND=noninteractive &&
	apt update &&
	apt install -y --no-install-recommends --no-install-suggests ${CHROOT_PACKAGES} &&
	python3.13 -m ensurepip && python3.13 -m pip install --no-input ${PY_PACKAGES} &&
	apt autoremove -y &&
	apt clean &&
	rm -rf /var/lib/apt/lists/* &&
	rm -rf /tmp/*"

	# execute command on home root
	apt update && apt install -y software-properties-common curl &&
	apt-add-repository ppa:pypy/ppa -y &&
	add-apt-repository ppa:deadsnakes/ppa -y &&
	apt update &&
	apt install -y --no-install-recommends --no-install-suggests ${DEB_PACKAGES} &&
	python3.13 -m ensurepip && python3.13 -m pip install --no-input ${PY_PACKAGES} &&
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

install_debs

# Restore original state
mv ${CHROOT}/etc/resolv.conf.bak ${CHROOT}/etc/resolv.conf
