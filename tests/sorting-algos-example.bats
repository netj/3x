#!/usr/bin/env bats

ORIGWD=$PWD
repo=sorting-algos

setup() {
    # remove any previous runs
    rm -rf $repo
    # create and setup a new experiment repository
    3x setup $repo \
     --program \
       'python measure.py $algo $dataSize $dataOrder' \
     --inputs \
       algo=bubbleSort,selectionSort,insertionSort,quickSort,mergeSort \
       dataSize=2000,4000,8000 \
       dataOrder=random,ordered,reversed \
     --outputs \
       --extract 'sorting time \(s\): {{sortingTime(s) =~ .+}}' \
       --extract 'number of compares: {{numCompare =~ .+}}' \
       --extract 'number of accesses: {{numAccess =~ .+}}' \
       --extract 'input sorted ratio: {{ratioSortedIn =~ .+}}' \
       --extract 'output sorted ratio: {{ratioSortedOut =~ .+}}' \
      # end of 3x setup
    # check if repository were created correctly
    test -d $repo
    test -d $repo/input
    test -d $repo/input/algo=
    test -d $repo/input/algo=/bubbleSort
    test -d $repo/input/algo=/selectionSort
    test -d $repo/input/algo=/insertionSort
    test -d $repo/input/algo=/quickSort
    test -d $repo/input/algo=/mergeSort
    test -d $repo/input/dataSize=/2000
    test -d $repo/input/dataSize=/4000
    test -d $repo/input/dataSize=/8000
    test -d $repo/input/dataOrder=/random
    test -d $repo/input/dataOrder=/ordered
    test -d $repo/input/dataOrder=/reversed
    test -d $repo/program
    # TODO outputs
    # copy programs
    cp -f "$SRCROOT"/docs/examples/sorting-algos/program/*.py $repo/program/
    cd $repo
}

@test "sorting-algos: a few runs of quickSort" {
    EDITOR=true \
    3x plan algo=quickSort
    3x start &
    # wait until all PLANNED runs finish
    while [[ $(3x status | grep -c 'PLANNED\|RUNNING') -gt 0 ]]; do
        sleep 1
    done
    3x stop
    # check 3x results
    [[ $(3x results algo=quickSort | wc -l) -eq 9 ]]
}

teardown() {
    3x stop
    cd "$ORIGWD"
    rm -rf $repo
}

# vim:ft=sh
