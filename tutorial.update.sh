#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"

git fetch origin
if [[ $(git status --porcelain docs/tutorial/README.md | wc -l) -eq 0 ]]; then
git rm -rf --cached -- docs/tutorial || true
git read-tree --prefix=docs/tutorial remotes/origin/master:docs/tutorial
fi
mkdir -p docs/tutorial
(
cd docs/tutorial
mv -f README.md README.md~
git checkout -f .
mv -f README.md~ README.md
curl -X POST \
    --data name="3X Tutorial" \
    --data-urlencode content@README.md \
    http://documentup.com/compiled \
    >index.html
    # polish DocumentUp's style
    {
        echo '/<\/head/i'
        echo '<link rel="stylesheet" href="../../3x.css">'
        echo '.'
        echo 'wq'
    } | ed index.html
git add index.html
)

git rm -rf --cached -- docs/examples || true
git read-tree --prefix=docs/examples remotes/origin/master:docs/examples
git checkout -f docs/examples

# confirm publishing
read -p "commit and push? "

git commit -m "tutorial update"
git push
