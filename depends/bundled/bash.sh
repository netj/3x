#!/usr/bin/env bash
# install Bash
set -eu

name=bash
version=4.2
sha1sum=487840ab7134eb7901fbb2e49b0ee3d22de15cb8
md5sum=3fb927c7c33022f1c327f14a81c0d4b0
ext=.tar.gz

patchesURL=https://gist.github.com/jacknagel/4008180/raw/1509a257060aa94e5349250306cce9eb884c837d/bash-4.2-001-045.patch
patches_sha1sum=f10d42cf4a7bc6d5599d705d270a602e02dfd517
patches_md5sum=e5af015e91dd5aaf07a5208623f5649a

fetch-configure-build-install $name-$version <<END
url=http://ftpmirror.gnu.org/$name/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
custom-fetch() {
    default-fetch
    # patch after fetching source tree
    patchesName=${patchesURL##*/}
    fetch-verify "$patchesURL" "\$patchesName" \
        sha1sum=$patches_sha1sum md5sum=$patches_md5sum
    cd "$name-$version"
    patch -p0 <../"\$patchesName"
}
custom-install() { make install-strip; }
END
