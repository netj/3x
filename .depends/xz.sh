#!/usr/bin/env bash
set -eu

name=xz
version=5.0.5
sha1sum=26fec2c1e409f736e77a85e4ab314dc74987def0
md5sum=19d924e066b6fff0bc9d1981b4e53196
ext=.tar.gz

fetch-configure-build-install $name-$version <<END
url=http://tukaani.org/$name/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
END
