#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"

git rm -rf -- tutorial || true
git read-tree --prefix=docs/tutorial remotes/origin/master:docs/tutorial
mkdir -p docs/tutorial
(
cd docs/tutorial
git checkout README.md
curl -X POST \
    --data name="3X Tutorial" \
    --data-urlencode content@README.md \
    http://documentup.com/compiled \
    >index.html
git add index.html
)

git rm -rf -- docs/examples || true
git read-tree --prefix=docs/examples remotes/origin/master:docs/examples

git commit -m "tutorial update"
git push
