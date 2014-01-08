#!/usr/bin/env bash
# install node and npm
set -eu

version=v0.10.16
findHashSums() {
    local tarball=$1
    sha1sum=$(grep "$tarball" <<<'\
c76d0cac292784dcff16642e5b8e9b6e50bd2d1f  node-v0.10.16-darwin-x64.tar.gz
0405727606cc0bfd86fe16226235d6a17cf03524  node-v0.10.16-darwin-x86.tar.gz
784ac3b09eedc9ea2eda6d9bc8f7dd9760f40002  node-v0.10.16-linux-x64.tar.gz
8628a9679b0dd8b5521eb7009751f501b10db924  node-v0.10.16-linux-x86.tar.gz
49ebccdd4cf1b2433f64caf6430c0be050bf843c  node-v0.10.16-sunos-x64.tar.gz
caf9d90e133e02f041f50056fa2be6575c606923  node-v0.10.16-sunos-x86.tar.gz
' | { read sum f; echo $sum; })
    md5sum=$(grep "$tarball" <<<'\
d53b6340de354eb048cc7703a44e9b33  node-v0.10.16-darwin-x64.tar.gz
aa255ed756f24c7e2625ea9650699c14  node-v0.10.16-darwin-x86.tar.gz
3e7980d5d2fe25323b81bf741d41487f  node-v0.10.16-linux-x64.tar.gz
0ee8d337c093552a267e4b412ef1da04  node-v0.10.16-linux-x86.tar.gz
45512cd4f4b26a9a484565200e89ad4b  node-v0.10.16-sunos-x64.tar.gz
7c16c693fb4889c3e1514bb10c71fad5  node-v0.10.16-sunos-x86.tar.gz
' | { read sum f; echo $sum; })
}


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
        x86_64|amd64)
            arch=x64 ;;
        i386|i686|i86pc)
            arch=x86 ;;
        *)
            echo >&2 "$arch: Unsupported architecture"
            os= arch=
    esac
fi

if [ -n "$os" -a -n "$arch" ]; then
    # download binary distribution
    tarball="node-${version}-${os}-${arch}.tar.gz"
    findHashSums "$tarball"
    name=${tarball%.tar*}
    fetch-verify "http://nodejs.org/dist/${version}/$tarball" "$tarball" \
        ${sha1sum:+sha1sum=$sha1sum} ${md5sum:+md5sum=$md5sum}
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
    findHashSums "$tarball"
    fetch-configure-build-install ${tarball%$ext} <<-END
	url=http://nodejs.org/dist/${version}/$tarball
	${sha1sum:+sha1sum=$sha1sum}
	${md5sum:+md5sum=$md5sum}
	custom-configure() { $python ./configure "\$@"; }
	custom-build() { :; }
	custom-install() { default-install PORTABLE=1; }
	END
fi
