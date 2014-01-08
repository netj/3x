#!/usr/bin/env bash
set -eu

name=netcat
version=0.7.1
sha1sum=b5cbc52a7ceed2fd5c4f5081f5747130b2d0fe01
md5sum=088def25efe04dcdd1f8369d8926ab34
ext=.tar.gz

fetch-configure-build-install $name-$version <<END
url=http://downloads.sourceforge.net/project/$name/$name/$version/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
custom-install() { make install-exec; }
END
