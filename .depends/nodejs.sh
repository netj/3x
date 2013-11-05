#!/usr/bin/env bash
# install node and npm
set -eu

version=v0.10.16

prefix="$(pwd -P)"/prefix

# determine os and arch for downloading
os=$(uname -s)
case $os in
    Darwin) os=darwin ;;
    Linux)  os=linux  ;;
    SunOS)  os=sunos  ;;
    *)
        echo >&2 "$os: Unsupported operating system"
        os=
esac
if [ -z "$os" ]; then
    arch=
else
    arch=$(uname -m)
    case $arch in
        x86_64|amd64|i686)
            arch=x64 ;;
        i386|i86pc)
            arch=x86 ;;
        *)
            echo >&2 "$arch: Unsupported architecture"
            os= arch=
    esac
fi

if [ -n "$os" -a -n "$arch" ]; then
    # download binary distribution
    tarball="node-${version}-${os}-${arch}.tar.gz"
    name=${tarball%.tar*}
    fetch-verify "http://nodejs.org/dist/${version}/$tarball" "$tarball"
    mkdir -p "$prefix"
    tar xf "$tarball" -C "$prefix" --exclude=$name/share
    cd "$prefix/$name"
    place-depends-symlinks bin bin/*
else
    # download source and build
    # first, look for the latest version of python
    for python in python2.7 python2.6; do
        ! type $python &>/dev/null || break
        python=
    done
    if [ -z "$python" ]; then
        echo "Python >= 2.6 is required to build nodejs" >&2
        exit 2
    fi
    # download the source, configure and build
    ext=.tar.gz
    tarball="node-${version}$ext"
    fetch-configure-build-install ${tarball%$ext} <<-END
	url=http://nodejs.org/dist/${version}/$tarball
	custom-configure() { $python ./configure "\$@"; }
	custom-build() { :; }
	custom-install() { default-install PORTABLE=1; }
	END
fi
