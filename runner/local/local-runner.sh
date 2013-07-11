#!/usr/bin/env bash
# local-runner.sh -- vocabularies for local runner
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-25

ACTIVE_FLAG=is-active.local
RUNDIR_PREFIX=running.local.
WORKER_LOCK_PREFIX=running.local.worker.
WORKER_WAITING_SUFFIX=.waiting
WORKER_WAITING_SIGNAL=USR1

synchronized() {
    local Lock=$1; shift
    until lockproc $Lock grab; do sleep 1; done
    "$@"
    lockproc $Lock release
}

# source the parent script overriden by the current one
# Example usage: super "$0" "$@"
super() {
    local this=$1; shift
    local super=$(
        cmd=${this##*/} lastWasThis=false
        IFS=:
        for dir in $PATH; do
            s="$dir/$cmd"
            [ -e "$s" ] || continue
            if [ x"$s" = x"$this" ]; then
                lastWasThis=true
            elif $lastWasThis; then
                echo "$s"
                exit 0
            fi
        done
        error "$this: No overriden script found"
    )
    set -- "$super" "$@"; unset this super
    . "$@"
}

# put self at the beginning of PATH
[ x"$queueRunner/local" = x"${PATH%%:*}" ] ||
    PATH="$queueRunner/local:$PATH"
