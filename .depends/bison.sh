#!/usr/bin/env bash
set -eu

name=bison
version=3.0
sha1sum=e2da7ecd4ab65a12effe63ffa3ff5e7da34d9a72
md5sum=977106b703c7daa39c40b1ffb9347f58
ext=.tar.gz

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
END
