#!/usr/bin/env bash
# install GNU coreutils
set -eu
version=8.21

self=$0
name=`basename "$0" .sh`

prefix="$(pwd -P)"/prefix

# fetch source if necessary and prepare for build
tarball=coreutils-${version}.tar.xz
[ -s "$tarball" ] ||
    curl -C- -RLO "http://ftp.gnu.org/gnu/coreutils/$tarball"
xz -d <"$tarball" | tar xf -
cd ./"${tarball%.tar*}"

# configure and build
./configure --prefix="$prefix"
nproc=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu || echo 1)
make -j $nproc all
make -j $nproc install-exec


# place symlinks for commands to $DEPENDS_PREFIX/bin/
mkdir -p "$DEPENDS_PREFIX"/bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    relsymlink "$x" "$DEPENDS_PREFIX"/bin/
done
