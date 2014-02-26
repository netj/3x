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
: $_3X_RUNNER $_3X_QUEUE_ID $_3X_QUEUE_DIR $_3X_QUEUE $_3X_ROOT $_3X_ARCHIVE $_3X_ASSEMBLE

# all file paths are $_3X_QUEUE_DIR-relative
ACTIVE_FLAG=.is-active.$_3X_RUNNER
RUNDIR_PREFIX=running.$_3X_RUNNER.
WORKER_LOCK_PREFIX=.worker.$_3X_RUNNER.
WORKER_DIR_PREFIX=.worker.$_3X_RUNNER.
WORKER_WAITING_SUFFIX=.waiting
WORKER_WAITING_SIGNAL=USR1
WORKER_WAITING_TIMEOUT=600 #secs

runner-msg()   {
    local level=; case "${1:-}" in [-+][0-9]*) level=$1; shift ;; esac
    msg $level "$_3X_QUEUE_ID ${_3X_TARGET:-}${_3X_WORKER_ID:+[$_3X_WORKER_ID]}: $*"
}
runner-error() { error "$_3X_QUEUE_ID ${_3X_TARGET:-}${_3X_WORKER_ID:+[$_3X_WORKER_ID]}: $*"; }

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
        if [ -n "${_3X_WORKER_DIR:-}" ] && \
                [ -e "$_3X_QUEUE_DIR/$_3X_WORKER_DIR/target/$f" ]; then
            echo "$_3X_QUEUE_DIR/$_3X_WORKER_DIR/target/$f"
        elif [ -n "${_3X_TARGET_DIR:-}" ] && [ -e "$_3X_TARGET_DIR/$f" ]; then
            echo "$_3X_TARGET_DIR/$f"
        else
            ls-super "$_3X_RUNNER_HOME" "$_3X_RUNNER" "$f"
        fi
    done
}
useTargetOrRunnerConfig() {
    local name=$1 msg=$2
    set -- $(findOneInTargetOrRunners "$name")
    if [[ $# -gt 0 ]]; then
        runner-msg-withTargetOrRunnerPaths "$msg" "$@"
        cat "$@"
    else
        runner-error "$name: Not found"
    fi
}
runner-msg-withTargetOrRunnerPaths() {
    local level=; case "${1:-}" in [-+][0-9]*) level=$1; shift ;; esac
    be-quiet $level || {
        local msg=$1; shift
        for path; do
            # abbreviate some known paths
            case $path in
                "$_3X_ROOT"/*)
                    path=${path#$_3X_ROOT/}
                    ;;
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
        runner-msg $level "$msg"
    }
}


# some vocabularies useful when defining targets
define-with-backup() {
    local name=$1; shift
    create-backup-candidate "$name"
    echo "$@" >"$name"
    keep-backup-if-changed "$name"
}
create-backup-candidate() {
    local f=$1
    # prepare a backup candidate, so we can keep only changed ones later
    ! [ -e "$f" ] || mv -f "$f" "$f"~.$$
}

keep-backup-if-changed() {
    local f=$1
    # decide if it's worth keeping the backup candidate
    if [ -e "$f"~.$$ ]; then
        if [ x"$(sha1sum <"$f")" = x"$(sha1sum <"$f"~.$$)" ]; then
            rm -f "$f"~.$$
        else
            mv -f "$f"~.$$ "$f"~
        fi
    fi
}


# a lightweight shell function for obtaining state of runs
judge-state-of-run() {
    local runId=${1:-$_3X_RUN}
    local state=DONE
    [[ ! -s "$_3X_ROOT/$runId"/outputs.failed && -s "$_3X_ROOT/$runId"/output ]] ||
        state=FAILED
    echo $state
}


# allow actual runner to override/extend
! type runner-config.sh &>/dev/null ||
. runner-config.sh
# TODO source all from base to parents, then self
