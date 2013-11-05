#!/usr/bin/env bash
set -eu

name=m4
version=1.4.17
ext=.tar.xz

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
END
