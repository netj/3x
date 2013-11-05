#!/usr/bin/env bash
set -eu

name=time
version=1.7
ext=.tar.gz

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
custom-install() { make install-exec; }
END
