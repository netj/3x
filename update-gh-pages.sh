#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"

git fetch origin
git checkout gh-pages

mirror-master() {
    local tree=$1
    git rm -rf --cached -- "$tree" || true
    git read-tree --prefix="$tree" remotes/origin/master:"$tree"
    mkdir -p "$tree"
    (
    cd "$tree"
    [ ! -e README.md  ] || mv -f README.md README.md~
    git checkout -f .
    [ ! -e README.md~ ] || mv -f README.md~ README.md
    )
}

compile-README() {
    local curlArgs= tree=$1; shift
    curlArgs=(--data-urlencode content@README.md)
    for nameValuePair; do curlArgs+=(--data "$nameValuePair"); done
    (
    cd "$tree"
    # use DocumentUp to compile GitHub flavored Markdown into HTML
    curl -X POST "${curlArgs[@]}" http://documentup.com/compiled >index.html
    {
        # polish DocumentUp style
        echo '/<\/head/i'
        echo '<link rel="stylesheet" href="../../3x.css">'
        echo '.'
        # and insert an extra link back to home
        echo '/<div id="content">/'
        echo '?</div>?i'
        echo '<div class="extra"><a href="http://netj.github.io/3x"><i class="icon-beaker"></i> 3X Home</a></div>'
        echo '.'
        echo 'wq'
    } | ed index.html || true
    git add index.html
    )
}

###############################################################################


# Tutorial
mirror-master docs/tutorial
compile-README docs/tutorial name="3X Tutorial"
# and examples
mirror-master docs/examples


###############################################################################
# confirm publishing
read -p "commit and push? "

git commit -m "Reflected master updates to gh-pages"
git push
