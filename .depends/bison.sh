#!/usr/bin/env bash
set -eu

name=bison
version=3.0
ext=.tar.gz

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
END
