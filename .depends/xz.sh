#!/usr/bin/env bash
# install XZ Utils
set -eu
version=5.0.5
sha1sum=26fec2c1e409f736e77a85e4ab314dc74987def0
md5sum=19d924e066b6fff0bc9d1981b4e53196

self=$0
name=`basename "$0" .sh`

prefix="$(pwd -P)"/prefix

# fetch source if necessary and prepare for build
tarball=xz-${version}.tar.gz
[ x"$(sha1sum <"$tarball" 2>/dev/null)" = x"$sha1sum  -" ] ||
[ x"$(md5 <"$tarball" 2>/dev/null)" = x"$md5sum" ] ||
    curl -C- -RLO "http://tukaani.org/xz/$tarball"
tar xfz "$tarball"
cd ./"${tarball%.tar.*}"

# configure and build
./configure --prefix="$prefix"
make -j $(nproc 2>/dev/null) install

# place symlinks to $DEPENDSDIR/bin/
mkdir -p "$DEPENDS_PREFIX"/bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    relsymlink "$x" "$DEPENDS_PREFIX"/bin/
done
