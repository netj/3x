#!/usr/bin/env bash
# update-gh-pages.sh -- a script to automate GitHub Pages updates
#                       by mirroring trees in master to gh-pages, and
#                          compiling Markdown documents using DocumentUp.
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-11-08
set -eu

: \
    ${ghPagesRepoPath:=gh-pages} \
    ${GitHubRemote:=origin} \
    ${MasterBranch:=master} \
    #

localRepo=$PWD

# setup gh-pages branch and clone this to work on gh-pages
git branch --track gh-pages remotes/"$GitHubRemote"/gh-pages || true
[ -e "$ghPagesRepoPath"/.git ] || git clone . --branch gh-pages "$ghPagesRepoPath"
# TODO make sure origin of $ghPagesRepoPath is this repo
cd "$ghPagesRepoPath"

# default options for DocumentUp
DocumentUpOptions=(
)

git fetch origin
git checkout gh-pages

mirror-master() {
    local tree=$1
    [[ $(git diff "$tree"/README.md | wc -l) -eq 0 ]] ||
        mv -f "$tree"/README.md "$tree"/README.md~
    case $tree in
        .)
            git checkout remotes/origin/"$MasterBranch" -- README.md
            git rm --cached README.md
            ;;
        *)
            git rm -rf --cached -- "$tree" || true
            git read-tree --prefix="$tree" remotes/origin/"$MasterBranch":"$tree"
            mkdir -p "$tree"
            git checkout -f -- "$tree"
    esac
    ! [[ -e "$tree"/README.md~ ]] ||
        mv -f "$tree"/README.md~ "$tree"/README.md
}

compile-markdown() {
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
        # English language (for auto-hyphenation, etc.)
        echo '/<body/s/<body/<body lang="en"/'
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
    case $tree in
        .)
            ;;
        *)
            git add README.md "$output"
    esac
    )
}

# make sure we do some stuff after compiling the site
onexit() {
    # confirm publishing
    read -p "commit and publish? "

    # first, commit updates to gh-pages repo first and the local repo
    git commit -m "Reflected $MasterBranch updates to gh-pages" || true
    git push

    # then, push to GitHub
    cd "$localRepo"
    [ $(git log "$GitHubRemote"/"$MasterBranch".."$MasterBranch" \
        README.md | wc -l) -eq 0 ] || git push "$GitHubRemote" "$MasterBranch"
    git push "$GitHubRemote" gh-pages
}
trap onexit EXIT


# finally, run the update script for this gh-pages site
if [ -e update.sh ]; then
    . update.sh
else
    # otherwise, simply create a preview for README
    mirror-master .
    compile-markdown .
fi
