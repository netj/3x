#!/usr/bin/env bash
# install GNU coreutils
set -eu
version=8.21
sha1sum=3fba93c72fab62f3742fe50957d3a86d4cd08176
md5sum=065ba41828644eca5dd8163446de5d64

self=$0
name=`basename "$0" .sh`

prefix="$(pwd -P)"/prefix

# fetch source if necessary and prepare for build
tarball=coreutils-${version}.tar.xz
[ x"$(sha1sum <"$tarball" 2>/dev/null)" = x"$sha1sum  -" ] ||
[ x"$(md5 <"$tarball" 2>/dev/null)" = x"$md5sum" ] ||
    curl -C- -RLO "http://ftp.gnu.org/gnu/coreutils/$tarball"
xz -d <"$tarball" | tar xf -
cd ./"coreutils-${version}"

# configure and build
./configure --prefix="$prefix"
make -j $(nproc 2>/dev/null) install


# place symlinks for commands to $DEPENDS_PREFIX/bin/
mkdir -p "$DEPENDS_PREFIX"/bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    relsymlink "$x" "$DEPENDS_PREFIX"/bin/
done
