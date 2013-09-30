#!/usr/bin/env bash
# install SQLite
set -eu
version=3080002
sha1sum=99055b894259dc85cfb2da92971904f74ec3aa3e
md5sum=af1ed6543929376ba13f0788e18ef30f

self=$0
name=`basename "$0" .sh`

prefix="$(pwd -P)"/prefix

# fetch source if necessary and prepare for build
zip=sqlite-amalgamation-${version}.zip
[ x"$(sha1sum <"$zip" 2>/dev/null)" = x"$sha1sum  -" ] ||
[ x"$(md5 <"$zip" 2>/dev/null)" = x"$md5sum" ] ||
    curl -C- -RLO "http://www.sqlite.org/2013/$zip"

unzip -o "$zip"
cd ./"${zip%.zip}"

# See: http://www.sqlite.org/howtocompile.html
mkdir -p "$prefix"/bin
gcc -o "$prefix"/bin/sqlite3 \
    -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION \
    shell.c sqlite3.c

# place symlinks for commands to $DEPENDS_PREFIX/bin/
mkdir -p "$DEPENDS_PREFIX"/bin
for x in "$prefix"/bin/*; do
    [ -x "$x" ] || continue
    relsymlink "$x" "$DEPENDS_PREFIX"/bin/
done
