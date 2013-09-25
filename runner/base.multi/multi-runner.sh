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
    xargs <"$_3X_WORKER_DIR"/runSerials \
        bash -c 'IFS=,; queue '"$*"' "serial#=$*"' -
}

# 
prepare-remote-root() {
    local at=$1
    (
    cd "$at"
    mkdir -p "$REMOTE_ROOT"/.3x/bin
    ln  -fn "$_3X_ROOT"/.3x/assemble.sh    "$REMOTE_ROOT"/.3x/
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
