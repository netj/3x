#!/usr/bin/env bash
set -eu

name=sqlite-amalgamation
version=3080002
ext=.zip

# fetch source if necessary and prepare for build
fetch-configure-build-install $name-$version <<END
url=http://www.sqlite.org/2013/$name-$version$ext
sha1sum=99055b894259dc85cfb2da92971904f74ec3aa3e
md5sum=af1ed6543929376ba13f0788e18ef30f

custom-configure() { :; }

custom-build() {
    # See: http://www.sqlite.org/howtocompile.html
    gcc -o sqlite3 \
        -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION \
        shell.c sqlite3.c
}

custom-install() {
    mkdir -p "\$2"/bin
    install sqlite3 "\$2"/bin/
}
END
