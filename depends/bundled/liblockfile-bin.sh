#!/usr/bin/env bash
set -eu

name=liblockfile
version=1.09
sha1sum=6f3f170bc4c303435ab5b46a6aa49669e16a5a7d
md5sum=2aa269e4405ee8235ff17d1b357c6ae8
ext=.tar.gz

fetch-configure-build-install $name-$version <<END
url=http://ftp.de.debian.org/debian/pool/main/${name:0:4}/${name}/${name}_${version}.orig${ext}
sha1sum=$sha1sum
md5sum=$md5sum
custom-install() {
    local prefix=\$2
    mkdir -p "\$prefix"/{bin,lib,include,man/man{1,3}}
    make install MAILGROUP=$(set -- $(groups); echo $1)
}
END
