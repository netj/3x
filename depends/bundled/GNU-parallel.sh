#!/usr/bin/env bash
# install GNU parallel
set -eu

name=parallel
version=20130922
sha1sum=be84aae96ee8c0a6651a3b5ca232fcb35066b3f3
md5sum=7b522b7c51ef2a1f5c02b58d9fa50afb
ext=.tar.bz2

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
custom-install() { make install-exec; }
END
