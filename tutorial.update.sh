#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
git rm -rf -- tutorial || true
git read-tree --prefix=tutorial remotes/origin/master:docs/tutorial
git checkout tutorial

cd tutorial
curl -X POST \
    --data name="3X Tutorial" \
    --data-urlencode content@README.md \
    http://documentup.com/compiled \
    >index.html
git add index.html

git commit -m "tutorial update"
git push
