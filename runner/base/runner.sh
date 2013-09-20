#!/usr/bin/env bash
# runner.sh -- common vocabularies for all (bash-based) 3X runners
# Usage:
# > . runner.sh
# 
# See runner/README.md for information about creating new 3X Runners by
# extending the base implementation.
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-25
set -eu

# make sure runner handler is invoked after . find-runner.sh
: $_3X_RUNNER $_3X_QUEUE_ID $_3X_QUEUE_DIR $_3X_QUEUE $_3X_ROOT

# all file paths are $_3X_QUEUE_DIR-relative
ACTIVE_FLAG=.is-active.$_3X_RUNNER
RUNDIR_PREFIX=running.$_3X_RUNNER.
WORKER_LOCK_PREFIX=.worker.$_3X_RUNNER.
WORKER_DIR_PREFIX=.worker.$_3X_RUNNER.
WORKER_WAITING_SUFFIX=.waiting
WORKER_WAITING_SIGNAL=USR1
WORKER_WAITING_TIMEOUT=600 #secs

export WORKER_DIR=${WORKER_DIR:-}
export _3X_WORKER_ID=${_3X_WORKER_ID:-}
runner-msg()   {
    local level=; case "${1:-}" in [-+][0-9]*) level=$1; shift ;; esac
    msg $level "$_3X_QUEUE_ID $_3X_TARGET${_3X_WORKER_ID:+[$_3X_WORKER_ID]}: $*"
}
runner-error() { error "$_3X_QUEUE_ID $_3X_TARGET${_3X_WORKER_ID:+[$_3X_WORKER_ID]}: $*"; }

synchronized() {
    local Lock=$1; shift
    until lockproc $Lock grab; do sleep 1; done
    "$@"
    lockproc $Lock release
}

# source the parent script overriden by the current one
# Example usage: super "$BASH_SOURCE" "$@"
super() {
    local this=$1; shift
    case $this in
        *.sh)
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
                        break
                    fi
                done
            )
            if [ -e "$super" ]; then
                set -- "$super" "$@"; unset this super
                . "$@"
            else
                error "$this: No overriden script found"
            fi
            ;;
        *)
            command super "$this" "$@"
            ;;
    esac
}

findOneInTargetOrRunners() {
    local f
    for f; do
        if [ -e "$_3X_TARGET_DIR/$f" ]; then
            echo "$_3X_TARGET_DIR/$f"
        else
            ls-super "$_3X_RUNNER_HOME" "$_3X_RUNNER" "$f"
        fi
    done
}
runner-msg-withTargetOrRunnerPaths() {
    local level=; case "${1:-}" in [-+][0-9]*) level=$1; shift ;; esac
    be-quiet $level || {
        local msg=$1; shift
        for path; do
            # abbreviate some known paths
            case $path in
                "$_3X_HOME"/*)
                    path=${path#$_3X_HOME/}
                    ;;
                "$_3X_RUNNER_HOME"/*)
                    path=${path#$_3X_RUNNER_HOME/}
                    path=${path/\//"'s default "}
                    ;;
            esac
            msg+=" $path"
        done
        msg $level "$msg"
    }
}

# allow actual runner to override/extend
! type runner-config.sh &>/dev/null ||
. runner-config.sh
# TODO source all from base to parents, then self
