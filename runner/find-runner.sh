#!/usr/bin/env bash
# find-runner.sh -- setup environment for the given runner, or
#                   the runner for the target of current queue
# 
# Usage: independent of current queue's target
# > . find-runner.sh RUNNER
# > echo "$_3X_RUNNER"
# > target-define
# > target-info
# > queue-stop
# > queue-refresh
# > queue-sync
# 
# Usage: that requires current queue's target:
# > . find-runner.sh -
# > queue-start
# > queue-changed
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-24

. find-queue.sh

if [ x"$1" = x"-" ]; then
    # find the runner for the target of current queue
    if [ -d "$_3X_TARGET_DIR" ]; then
        export _3X_RUNNER=$(cat "$_3X_TARGET_DIR"/type 2>/dev/null) ||
            error "$_3X_TARGET: No type defined for target execution environment"
    else
        error "$_3X_QUEUE_ID: No target execution environment assigned" || true
        msg "# Assign a target environment by running:"
        msg "3x target"
        false
    fi
else
    # or, just setup environment to use the given runner
    export _3X_RUNNER=$1
    # reset _3X_TARGET_DIR and _3X_TARGET to make sure subsequent runner
    # operations are target-independent
    unset _3X_TARGET_DIR _3X_TARGET
fi

# add all parent runners of $_3X_RUNNER and the base runner to PATH
setupRunnerPath() {
    # TODO remove all dirs under $_3X_RUNNER_HOME from PATH first?
    PATH="$(ls-super -a "$_3X_RUNNER_HOME" "$_3X_RUNNER" | tr '\n' :)$PATH"
}
setupRunnerPath

cd "$_3X_QUEUE_DIR"
