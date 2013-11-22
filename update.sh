#!/usr/bin/env bash
set -eu

GHPagesLang=en
DocumentUpOptions+=(
    google_analytics="UA-29293848-3"
)

#insert-footer() { echo '<address>&copy; 2013 <a href="http://infolab.stanford.edu">InfoLab, Stanford University</a>.</address>'; }


common-links() {
    echo '<div class="extra"><a href="https://github.com/'"$GitHubRepo"'"><i class="fa fa-github-alt"></i> Source Code</a></div>'
    echo '<div class="extra"><a href="https://github.com/'"$GitHubRepo"'/issues"><i class="fa fa-bug"></i> Issues</a></div>'
}
link() {
    local title=$1 path=$2
    echo '<div class="extra"><a href="http://'"${GitHubRepo%/*}"'.github.io/'"${GitHubRepo#*/}"'/'"$path"'"><i class="fa fa-flask"></i> '"$title"'</a></div>'
}

insert-nav-extras() {
    local self=$1
    link-no-self() { [[ $2 = $self ]] || link "$@"; }
    link-no-self "3X"           "."
    link-no-self "Features"     "docs/features"
    link-no-self "Installation" "docs/install"
    link-no-self "Tutorial"     "docs/tutorial"
    common-links
}


# README preview
mirror-master .
compile-markdown . name="3X" #"3X for eXecuting eXploratory eXperiments"

# Features
mirror-master docs/features
compile-markdown docs/features name="3X Features"

# Installation
mirror-master docs/install
compile-markdown docs/install name="3X Installation"

# Tutorial
mirror-master docs/tutorial
compile-markdown docs/tutorial name="3X Tutorial"
# and examples
mirror-master docs/examples
