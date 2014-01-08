#!/usr/bin/env bash
set -eu

name=m4
version=1.4.17
sha1sum=74ad71fa100ec8c13bc715082757eb9ab1e4bbb0
md5sum=12a3c829301a4fd6586a57d3fcf196dc
ext=.tar.xz

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
END
