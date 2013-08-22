#!/bin/sh
# install node modules
set -eu

self=$0
name=`basename "$0" .sh`

cd "$DEPENDSDIR"

mkdir -p "$name"
cd ./"$name"
cp -f ../"$name".json package.json
rm -rf node_modules
date >README.md
npm install
cd - >/dev/null

mkdir -p .all/bin
for x in "$name"/node_modules/.bin/*; do
    ln -sfn ../../"$x" .all/bin/
done
