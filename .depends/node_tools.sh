#!/usr/bin/env bash
# install node modules
set -eu

self=$0
name=`basename "$0" .sh`

cp -f ../"$name".json package.json
rm -rf node_modules
date >README.md
npm install

mkdir -p "$DEPENDS_PREFIX"/bin
cp -al node_modules "$DEPENDS_PREFIX"/lib/
cd "$DEPENDS_PREFIX"
for x in lib/node_modules/.bin/*; do
    relsymlink "$x" bin/
done
