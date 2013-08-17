#!/usr/bin/env bash
# install node and npm
set -eu

version=v0.10.16

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
set -x

# fetch nodejs source
curl -C- -RLO "http://nodejs.org/dist/${version}/node-${version}.tar.gz"
tar xfz "node-${version}.tar.gz"
cd ./"node-${version}"

# configure and build
$python ./configure --prefix="$PWD/../../$prefix"
make -j install PORTABLE=1

cd ../..
}

# place symlinks to $DEPENDSDIR/bin/
mkdir -p bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    ln -sfn ../"$x" bin/
done
