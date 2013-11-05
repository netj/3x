#!/usr/bin/env bash
set -eu

name=coreutils
version=8.21
ext=.tar.xz

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
custom-install() { make install-exec; }
END
