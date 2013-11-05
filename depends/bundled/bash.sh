#!/usr/bin/env bash
# install Bash
set -eu

name=bash
version=4.2
ext=.tar.gz

patchesURL=https://gist.github.com/jacknagel/4008180/raw/1509a257060aa94e5349250306cce9eb884c837d/bash-4.2-001-045.patch

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
custom-fetch() {
    default-fetch
    # patch after fetching source tree
    patchesName=${patchesURL##*/}
    fetch-verify "$patchesURL" "\$patchesName" sha1sum=...
    cd "$name-$version"
    patch -p0 <../"\$patchesName"
}
custom-install() { make install-strip; }
END
