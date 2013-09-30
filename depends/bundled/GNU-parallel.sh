#!/usr/bin/env bash
# install GNU parallel
set -eu
version=20130922
sha1sum=be84aae96ee8c0a6651a3b5ca232fcb35066b3f3
md5sum=7b522b7c51ef2a1f5c02b58d9fa50afb

self=$0
name=`basename "$0" .sh`

prefix="$(pwd -P)"/prefix

# fetch source if necessary and prepare for build
tarball=parallel-${version}.tar.bz2
checksum-is-correct() {
    [ x"$(sha1sum <"$tarball" 2>/dev/null)" = x"$sha1sum  -" ] ||
    [ x"$(md5 <"$tarball" 2>/dev/null)" = x"$md5sum" ]
}
checksum-is-correct ||
    curl -C- -RLO "http://ftpmirror.gnu.org/parallel/$tarball"
checksum-is-correct || {
    echo >&2 "$tarball: SHA1 or MD5 sum mismatch"
    false
}
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
