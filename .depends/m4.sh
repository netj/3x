#!/usr/bin/env bash
# install GNU coreutils
set -eu
version=1.4.17

self=$0
name=`basename "$0" .sh`

prefix="$(pwd -P)"/prefix

# fetch source if necessary and prepare for build
tarball=m4-${version}.tar.xz
[ -s "$tarball" ] ||
    curl -C- -RLO "http://ftpmirror.gnu.org/${tarball%%-*}/$tarball"
xz -d <"$tarball" | tar xf -
cd ./"${tarball%.tar*}"

# configure and build
./configure --prefix="$prefix"
nproc=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu || echo 1)
make -j $nproc all
make -j $nproc install


# place symlinks for commands to $DEPENDS_PREFIX/bin/
mkdir -p "$DEPENDS_PREFIX"/bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    relsymlink "$x" "$DEPENDS_PREFIX"/bin/
done
