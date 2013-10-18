#!/usr/bin/env bash
# install Bash
set -eu
version=4.2
patchesURL=https://gist.github.com/jacknagel/4008180/raw/1509a257060aa94e5349250306cce9eb884c837d/bash-4.2-001-045.patch

self=$0
name=`basename "$0" .sh`

prefix="$(pwd -P)"/prefix

# fetch source if necessary and prepare for build
tarball=bash-${version}.tar.gz
[ -s "$tarball" ] ||
    curl -C- -RLO "http://ftpmirror.gnu.org/bash/$tarball"
patchesName=${patchesURL##*/}
[ -s "$patchesName" ] ||
    curl -C- -RLOk "$patchesURL"
tar xf "$tarball"
cd ./"${tarball%.tar*}"
patch -p0 <../"$patchesName"


# configure and build
./configure --prefix="$prefix"
nproc=$(nproc 2>/dev/null)
make -j $nproc install-strip


# place symlinks for commands to $DEPENDS_PREFIX/bin/
mkdir -p "$DEPENDS_PREFIX"/bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    relsymlink "$x" "$DEPENDS_PREFIX"/bin/
done
