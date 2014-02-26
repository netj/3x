#!/usr/bin/env bash
# find-queue.sh -- Find current queue based on $_3X_QUEUE
# 
# > . find-queue.sh
# > echo "$_3X_QUEUE_ID"
# > cd "$_3X_QUEUE_DIR"
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-24

. find-run-archive.sh
shopt -s extglob

# some predefined paths
export _3X_RUNNER_HOME="$TOOLSDIR"/runner

# determine the current queue
: ${_3X_QUEUE:=$(readlink "$_3X_ROOT"/.3x/Q || echo main)}
case $_3X_QUEUE in
    ../run/queue/*)
        # short circuit for symlink
        _3X_QUEUE=${_3X_QUEUE#../run/queue/}
        ;;
    */*)
        # extract queue name if it looks like a path
        _3X_QUEUE=$(readlink -f "$_3X_QUEUE")
        _3X_QUEUE=${_3X_QUEUE#$_3X_ROOT/}
        case $_3X_QUEUE in
            run/queue/*)
                _3X_QUEUE=${_3X_QUEUE#run/queue/}
                ;;
            *)
                error "$_3X_QUEUE: Invalid queue name"
                ;;
        esac
        ;;
esac
export _3X_QUEUE
export _3X_QUEUE_ID="run/queue/$_3X_QUEUE"
export _3X_QUEUE_DIR="$_3X_ROOT/$_3X_QUEUE_ID"
export _3X_TARGET_DIR=$(readlink -f "$_3X_QUEUE_DIR"/target) || true
export _3X_TARGET=${_3X_TARGET_DIR##*/}

queue-is-active() {
    set -- "$_3X_QUEUE_DIR"/.is-active.*
    [ -e "$1" ]
}

for-each-active-runner() {
    local runners=; runners=()
    local f=
    for f in "$_3X_QUEUE_DIR"/.is-active.*; do
        [[ -e "$f" ]] || continue
        runners+=(${f##*/.is-active.})
    done
    for f in "$_3X_QUEUE_DIR"/.worker.*; do
        [[ -d "$f" ]] || continue
        f=${f##*/.worker.}
        f=${f%%.*}
        [[ -e "$_3X_QUEUE_DIR"/.is-active.$f ]] ||
            runners+=("$f")
    done
    if [[ ${#runners[@]} -gt 0 ]]; then
        local runner=
        for runner in "${runners[@]}"; do
            (
            . find-runner.sh "$runner"
            setsid "$@"
            )
        done
    fi
}

for-every-runner() {
    for runnerDir in "$_3X_RUNNER_HOME"/!(base.*)/; do
        runner=${runnerDir#$_3X_RUNNER_HOME/}
        runner=${runner%/}
        (
        . find-runner.sh "$runner"
        setsid "$@"
        )
    done
}
