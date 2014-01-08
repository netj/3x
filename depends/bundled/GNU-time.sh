#!/usr/bin/env bash
set -eu

name=time
version=1.7
sha1sum=dde0c28c7426960736933f3e763320680356cc6a
md5sum=e38d2b8b34b1ca259cf7b053caac32b3
ext=.tar.gz

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
custom-install() { make install-exec; }
END
