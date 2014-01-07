#!/usr/bin/env bash
set -eu

name=netcat
version=0.7.1
ext=.tar.gz

fetch-configure-build-install $name-$version <<END
url=http://downloads.sourceforge.net/project/$name/$name/$version/$name-$version$ext
custom-install() { make install-exec; }
END
