#!/usr/bin/env bash
# multi-runner.sh -- common vocabularies for (bash-based) 3X runners that extends base.multi runner
# Usage:
# > . multi-runner.sh
# 
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-09-23
. runner.sh

# keep a shorthand for running queue commands on the picked runs
for-picked-runs() {
    local serials=$(tr '\n' , <"$_3X_WORKER_DIR"/runSerials)
    serials=${serials%,}
    queue "$@" "serial#=$serials"
}

drop-finished-runs() {
    # exclude finished runs from the picked ones (i.e., DONE or FAILED runs)
    (
    cd "$_3X_WORKER_DIR"
    for-picked-runs list-only serial "state#"!=DONE,FAILED >runSerials.$$
    mv -f runSerials runSerials~
    mv -f runSerials.$$ runSerials
    )
}

REMOTE_ROOT_PREFIX=.3x-remote
prepare-remote-root() {
    local REMOTE_ROOT=$1
    local at=${2:-.}
    (
    cd "$at"
    mkdir -p "$REMOTE_ROOT"/.3x/bin
    ln  -fn "$_3X_ASSEMBLE"                "$REMOTE_ROOT"/.3x/
    ln -sfn "$_3X_ROOT"/input              "$REMOTE_ROOT"/
    ln -sfn "$_3X_ROOT"/program            "$REMOTE_ROOT"/
    ln -sfn "$_3X_ROOT"/output             "$REMOTE_ROOT"/
    # some essential commands (used in assemble.sh)
    for tool in \
        record-environ.sh import \
        error msg be-quiet usage \
        no-comments \
    ; do
        [ -x "$TOOLSDIR"/$tool ]
        cp -p "$TOOLSDIR"/$tool "$REMOTE_ROOT"/.3x/bin/
    done
    )
}
