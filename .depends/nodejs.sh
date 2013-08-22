#!/usr/bin/env bash
# install node and npm
set -eu

version=v0.10.16
sha1sum=80c45c1850b1ecc6237b6b587f469da8ef743876
md5sum=b8d9ac16c4d6eea1329e018fbca63e50

self=$0
name=`basename "$0" .sh`

# look for the latest version of python
for python in python2.7 python2.6; do
    ! type $python &>/dev/null || break
    python=
done
if [ -z "$python" ]; then
    echo "Python >= 2.6 is required to build nodejs" >&2
    exit 2
fi

{
cd "$DEPENDSDIR"
prefix="$name"/prefix

mkdir -p "$name"
cd ./"$name"

# fetch nodejs source if necessary and prepare source tree
tarball="node-${version}.tar.gz"
[ x"$(sha1sum <"$tarball" 2>/dev/null)" = x"$sha1sum  -" ] ||
[ x"$(md5 <"$tarball" 2>/dev/null)" = x"$md5sum" ] ||
    curl -C- -RLO "http://nodejs.org/dist/${version}/$tarball"
tar xfz "$tarball"
cd ./"node-${version}"

# configure and build
$python ./configure --prefix="$PWD/../../$prefix"
make -j $(nproc 2>/dev/null) install PORTABLE=1

cd ../..
}

# place symlinks for commands to $DEPENDSDIR/.all/bin/
mkdir -p .all/bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    ln -sfn ../../"$x" .all/bin/
done
