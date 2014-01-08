#!/usr/bin/env bash
set -eu

name=coreutils
version=8.21
sha1sum=3fba93c72fab62f3742fe50957d3a86d4cd08176
md5sum=065ba41828644eca5dd8163446de5d64
ext=.tar.xz

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
custom-install() { make install-exec; }
END
