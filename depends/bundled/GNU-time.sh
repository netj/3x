#!/usr/bin/env bash
# install Bash
set -eu
version=1.7

self=$0
name=`basename "$0" .sh`

prefix="$(pwd -P)"/prefix

# fetch source if necessary and prepare for build
tarball=time-${version}.tar.gz
[ -s "$tarball" ] ||
    curl -C- -RLO "http://ftpmirror.gnu.org/time/$tarball"
tar xf "$tarball"
cd ./"${tarball%.tar*}"


# configure and build
./configure --prefix="$prefix"
make -j $(nproc 2>/dev/null) install


# place symlinks for commands to $DEPENDS_PREFIX/bin/
mkdir -p "$DEPENDS_PREFIX"/bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    relsymlink "$x" "$DEPENDS_PREFIX"/bin/
done
