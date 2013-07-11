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

# put self at the beginning of PATH
[ x"$queueRunner/local" = x"${PATH%%:*}" ] ||
    PATH="$queueRunner/local:$PATH"
