#!/usr/bin/env bats

ORIGWD=$PWD
repo=whitespace-in-output

setup() {
    # remove any previous runs
    rm -rf $repo
    # create and setup a new experiment repository
    3x setup $repo \
     --program \
       'echo "output: a b c $x"' \
     --inputs \
       x=d,e,f \
     --outputs \
       --extract 'output: {{string:nominal =~ .+}}' \
      # end of 3x setup
    # check if repository were created correctly
    test -d $repo
    test -d $repo/input
    test -d $repo/input/x=
    test -d $repo/input/x=/d
    test -d $repo/program
    # TODO outputs
    cd $repo
}

@test "whitespace in output" {
    EDITOR=true \
    3x plan x=d
    3x start &
    # wait until all PLANNED runs finish
    while [[ $(3x status | grep -c 'PLANNED\|RUNNING') -gt 0 ]]; do
        sleep 1
    done
    3x stop
    # check 3x results
    [[ $(3x results x=d) = *"string=a b c d	x=d" ]]
}

teardown() {
    3x stop
    cd "$ORIGWD"
    rm -rf $repo
}

# vim:ft=sh
