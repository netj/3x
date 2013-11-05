#!/usr/bin/env bash
# install node modules
set -eu

self=$0
name=`basename "$0" .sh`

cp -f ../"$name".json package.json
rm -rf node_modules
mkdir -p "$DEPENDS_PREFIX"/lib/node_modules
ln -sfn "$DEPENDS_PREFIX"/lib/node_modules .
date >README.md
npm install

cd "$DEPENDS_PREFIX"
place-depends-symlinks bin/ lib/node_modules/.bin/*
