#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"

DocumentUpOptions=(
    repo="netj/3x"
    google_analytics="UA-29293848-3"
)

git fetch origin
git checkout gh-pages

mirror-master() {
    local tree=$1
    (   cd "$tree"
        [ ! -e README.md  ] || mv -f README.md README.md~
    )
    case $tree in
        .)
            git checkout remotes/origin/master -- README.md
            ;;
        *)
            git rm -rf --cached -- "$tree" || true
            git read-tree --prefix="$tree" remotes/origin/master:"$tree"
            mkdir -p "$tree"
            git checkout -f -- "$tree"
    esac
    (   cd "$tree"
        [ ! -e README.md~ ] || mv -f README.md~ README.md
    )
}

compile-README() {
    local tree=$1; shift
    local rootRelPath= output= curlArgs=
    case $tree in
        .)
            rootRelPath=.
            output=preview.html
            ;;
        *)
            rootRelPath=$(perl -MFile::Spec -e 'print File::Spec->abs2rel(@ARGV)' . "$tree")
            output=index.html
    esac
    curlArgs=(--data-urlencode content@README.md)
    # default args
    set -- "${DocumentUpOptions[@]}" "$@"
    for nameValuePair; do curlArgs+=(--data "$nameValuePair"); done
    (  cd "$tree"
    # use DocumentUp to compile GitHub flavored Markdown into HTML
    curl -X POST "${curlArgs[@]}" http://documentup.com/compiled >"$output"
    {
        # polish DocumentUp style
        echo '/<\/head/i'
        echo '<link rel="stylesheet" href="'"$rootRelPath"'/3x.css">'
        echo '.'
        # and insert an extra link back to home
        case $tree in
            .)
                ;;
            *)
                echo '/<div id="content">/'
                echo '?</div>?i'
                echo '<div class="extra"><a href="http://netj.github.io/3x"><i class="icon-beaker"></i> 3X Home</a></div>'
                echo '.'
        esac
        echo 'wq'
    } | ed "$output" >/dev/null || true
    )
    case $tree in
        .)
            ;;
        *)
            git add "$tree"/"$output"
    esac
}

###############################################################################

# README preview
mirror-master .
compile-README . name="3X" #"3X for eXecutable eXploratory eXperiments"

# Tutorial
mirror-master docs/tutorial
compile-README docs/tutorial name="3X Tutorial"
# and examples
mirror-master docs/examples

# Installation
mirror-master docs/install
compile-README docs/install name="3X Installation"


###############################################################################
# confirm publishing
read -p "commit and push? "

git commit -m "Reflected master updates to gh-pages"
git push
