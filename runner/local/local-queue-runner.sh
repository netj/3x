#!/usr/bin/env bash
# local-queue-runner.sh -- vocabularies for local queue runner
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-25

RUNDIR_PREFIX=running.local.
WORKER_LOCK_PREFIX=worker.local

synchronized() {
    local Lock=$1; shift
    until lockproc $Lock grab; do sleep 1; done
    "$@"
    lockproc $Lock release
}

