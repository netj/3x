#!/bin/sh
# use latest python available
set -eu

mkdir -p "$DEPENDS_PREFIX"/bin
for python in python2.7 python2.6; do
    pythonpath=`type -p $python 2>/dev/null` || continue
    ln -sfn "$pythonpath" "$DEPENDS_PREFIX"/bin/python
    exit 0
done

echo >&2 "No Python >= 2.6 found"
false
